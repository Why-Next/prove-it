#!/bin/bash
# prove-it: an agent cannot end its turn until the repo proves itself.
#
# Reference implementation of the verify.sh convention (see SPEC.md).
# Wire this to a Claude Code `Stop` hook. It runs ./verify.sh at the repo
# root and blocks the turn (exit 2) when verification fails.
#
# Opt-in by design: no verify.sh means no gate. Delete the file to opt out.
#
# The gate runs only when all of these hold:
#   - this session changed THIS repository, measured by comparing the working
#     tree against the baseline that session-start.sh recorded. A commit counts.
#     An edit made with sed counts. Reading counts as nothing.
#   - an executable verify.sh exists at the repo root, or existed when the
#     session started
#   - this exact tree state has not already passed (avoids re-running per Stop)
#
# Pass: exit 0 and stamp the tree state.
# Fail: exit 2 to block the turn, with the tail of verify.sh output on stderr.
#
# The turn can be blocked up to PROVE_IT_MAX_BLOCKS times (default 3) before the
# gate gives up. Claude Code sets stop_hook_active on every stop after the first
# block, so a hook that reads that flag as "let it through" gets exactly one
# push-back and then stops being a gate. Yielding eventually is still necessary,
# because a hook that never yields hangs the session. Yielding silently is not:
# the last word is a warning the user cannot miss rather than the word "done".
#
# PROVE_IT_SKIP=1 bypasses the gate. Internal errors fall back to passing.
#
# Optional ledger (PROVE_IT_LEDGER=1): append one JSON line per caught
# false "done" to $PROVE_IT_LEDGER_DIR/ledger.jsonl. It holds conversation
# text, so it is created 0600 in a 0700 directory. Local only, never sent.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=hooks/lib.sh
. "$HERE/lib.sh"

INPUT=$(cat)

[ "${PROVE_IT_SKIP:-}" = "1" ] && exit 0

FIELDS=$(pi_stop_fields "$INPUT") || exit 0
STOP_ACTIVE=$(printf '%s\n' "$FIELDS" | sed -n 1p)
SESSION_ID=$(printf '%s\n' "$FIELDS" | sed -n 2p)
TRANSCRIPT=$(printf '%s\n' "$FIELDS" | sed -n 3p)
[ -n "$SESSION_ID" ] || SESSION_ID=unknown

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
REPO_KEY=$(pi_repo_key "$ROOT")

# Private state, never shared /tmp: these names are predictable, and a
# world-writable directory turns a predictable name into a symlink target.
STATE_DIR=$(pi_state_dir)
(umask 077 && mkdir -p "$STATE_DIR") 2>/dev/null || exit 0

BASELINE="$STATE_DIR/baseline-${SESSION_ID}-${REPO_KEY}"
GUARD="$STATE_DIR/guard-${SESSION_ID}-${REPO_KEY}"
MARKER="$STATE_DIR/wrote-${SESSION_ID}-${REPO_KEY}"
STAMP="$STATE_DIR/stamp-${REPO_KEY}"
ATTEMPTS="$STATE_DIR/attempts-${SESSION_ID}-${REPO_KEY}"
GATEHASH="$STATE_DIR/gatehash-${SESSION_ID}-${REPO_KEY}"

# Is there a gate here at all? This is asked first because it is the cheapest
# question and, in most repositories, the answer is no. Hashing the tree of a
# repository that never opted in would be work done on every single stop for
# nothing.
#
# An agent that cannot make verify.sh pass can make it stop existing. Deleting
# the gate between sessions is an opt-out, and the spec says so. Disarming it
# inside the session it was about to block is the failure mode the spec calls a
# violation, and it is the one thing here worth refusing on sight.
VERIFY="$ROOT/verify.sh"
DISARMED=0
if [ ! -x "$VERIFY" ]; then
    if [ "$(cat "$GUARD" 2>/dev/null)" = "armed" ]; then
        DISARMED=1
    else
        exit 0
    fi
fi

STATE=$(pi_tree_state "$ROOT")

# Did this session change this repository? The tree answers, not the tool log.
if [ -f "$BASELINE" ]; then
    [ "$(cat "$BASELINE" 2>/dev/null)" = "$STATE" ] && exit 0
else
    # No baseline, so the session began outside this repository and nothing
    # recorded what it looked like beforehand. Fall back to the write marker and
    # a dirty tree. That is the weaker test: it cannot see a change that was
    # committed, because a committed tree is clean.
    [ -f "$MARKER" ] || exit 0
    [ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null | head -1)" ] || exit 0
fi

if [ "$DISARMED" -eq 0 ] && [ -f "$STAMP" ] \
    && [ "$(cat "$STAMP" 2>/dev/null)" = "$STATE" ]; then
    exit 0
fi

if [ "$DISARMED" -eq 1 ]; then
    RC=126
    OUT="verify.sh was executable when this session started, and is not now.
Restore it with: chmod +x verify.sh
Removing the gate is not a way of passing it. To opt out of verification for
this repository, delete verify.sh outside of an agent session. To bypass it for
this one, set PROVE_IT_SKIP=1."
else
    OUT=$(cd "$ROOT" && bash "$VERIFY" 2>&1)
    RC=$?
    if [ "$RC" -eq 0 ]; then
        printf '%s' "$STATE" > "$STAMP" 2>/dev/null
        rm -f "$ATTEMPTS" 2>/dev/null
        # A pass through a gate rewritten mid-session is a pass through the new
        # gate, not the one the session started with. Editing verify.sh is often
        # the requested work, so this is not a block. But whether the edit
        # weakened the gate is the user's call, and they can only make it about
        # an edit they were told happened.
        if [ -f "$GATEHASH" ] \
            && [ "$(cat "$GATEHASH" 2>/dev/null)" != "$(pi_gate_hash "$ROOT")" ]; then
            python3 2>/dev/null <<'PY' || true
import json

print(json.dumps({
    "systemMessage": (
        "prove-it: verify.sh passed, but verify.sh itself was modified during "
        "this session. Review the diff to verify.sh before trusting the pass."
    )
}))
PY
        fi
        exit 0
    fi
fi

# How many times has the gate already pushed back on this stretch of work?
# stop_hook_active is false on the first stop of a stretch, so it doubles as the
# signal to start counting again.
if [ "$STOP_ACTIVE" = "1" ]; then
    ATTEMPT=$(cat "$ATTEMPTS" 2>/dev/null || printf 0)
    case $ATTEMPT in
        '' | *[!0-9]*) ATTEMPT=0 ;;
    esac
else
    ATTEMPT=0
fi
ATTEMPT=$((ATTEMPT + 1))
printf '%s' "$ATTEMPT" > "$ATTEMPTS" 2>/dev/null

MAX=$(pi_max_blocks)

# The gate just caught a false "done". Record it once per stretch of work, on
# the first block, if the operator asked for that.
if [ "$ATTEMPT" -eq 1 ] && [ "${PROVE_IT_LEDGER:-}" = "1" ]; then
    LEDGER_DIR="${PROVE_IT_LEDGER_DIR:-$HOME/.prove-it}"
    (umask 077 && mkdir -p "$LEDGER_DIR") 2>/dev/null &&
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    REPO="$ROOT" RC="$RC" TRANSCRIPT="$TRANSCRIPT" OUT="$OUT" DIR="$LEDGER_DIR" \
    python3 2>/dev/null <<'PY' || true
import json, os, re


def last_claim(path):
    """The agent's final message before it tried to stop: what it claimed."""
    if not path or not os.path.exists(path):
        return None
    text = None
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                if rec.get("type") != "assistant":
                    continue
                content = rec.get("message", {}).get("content")
                if isinstance(content, list):
                    parts = [b.get("text", "") for b in content
                             if isinstance(b, dict) and b.get("type") == "text"]
                    joined = " ".join(p.strip() for p in parts if p.strip())
                    if joined:
                        text = joined
    except OSError:
        return None
    if text and len(text) > 300:
        text = text[:300] + "..."
    return text


FAILURE = re.compile(
    r"\b(fail|failed|failing|error|assert\w*|expected|actual|traceback|panic|"
    r"exception|not ok|refute|mismatch)\b", re.I)


def salient(output):
    """The lines that say what went wrong.

    Keeping the tail is wrong. Test runners end with a summary line about how
    many milliseconds they took, while the assertion that explains the failure
    sits further up. Prefer lines that name a failure, and fall back to the
    tail only when none of them do.
    """
    lines = [l.rstrip() for l in output.strip().splitlines() if l.strip()]
    hits = [l for l in lines if FAILURE.search(l)]
    chosen = hits[:8] if hits else lines[-5:]
    return [l[:200] for l in chosen]


entry = {
    "ts": os.environ["TS"],
    "repo": os.environ["REPO"],
    "exit_code": int(os.environ["RC"]),
    "claim": last_claim(os.environ.get("TRANSCRIPT", "")),
    "evidence_demanded": "verify.sh exit 0",
    "actual": salient(os.environ["OUT"]),
}

# This file holds conversation text. Create it 0600 rather than inheriting a
# umask that would leave it world-readable on a shared machine.
path = os.path.join(os.environ["DIR"], "ledger.jsonl")
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
with os.fdopen(fd, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
PY
fi

if [ "$ATTEMPT" -le "$MAX" ]; then
    {
        echo "prove-it: verification failed (verify.sh exit ${RC}). Attempt ${ATTEMPT} of ${MAX}."
        echo "Fix the cause, then end your turn again. Weakening verify.sh to get past this gate is a violation, not a fix."
        echo "If the failure cannot be fixed, report the cause to the user. (Deliberate bypass: PROVE_IT_SKIP=1)"
        printf '%s\n' "$OUT" | tail -20
    } >&2
    exit 2
fi

# The budget is spent. A hook that never yields hangs the session, so this one
# yields. It does not pretend the checks passed: the user gets a message they
# did not have to go looking for, and the ledger already holds the entry.
{
    echo "prove-it: giving up after ${MAX} blocked attempt(s). verify.sh still exits ${RC}."
    echo "The turn is allowed to end. It is not verified."
    printf '%s\n' "$OUT" | tail -20
} >&2

RC="$RC" MAX="$MAX" python3 2>/dev/null <<'PY' || true
import json, os

print(json.dumps({
    "systemMessage": (
        "prove-it: verify.sh still exits {rc} after {max} blocked attempt(s). "
        "This turn ended without passing verification."
    ).format(rc=os.environ["RC"], max=os.environ["MAX"])
}))
PY
exit 0
