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
#   - this session edited files in THIS repository (marker from mark-session-write.sh)
#   - an executable verify.sh exists at the repo root
#   - the working tree has changes (staged, unstaged, or untracked)
#   - this exact tree state has not already passed (avoids re-running per Stop)
#
# Pass: exit 0 and stamp the tree state.
# Fail: exit 2 to block the turn, with the tail of verify.sh output on stderr.
# stop_hook_active=true (a turn resumed *by* this hook) passes, to avoid a loop.
# PROVE_IT_SKIP=1 bypasses the gate. Internal errors fall back to passing.
#
# Optional ledger (PROVE_IT_LEDGER=1): append one JSON line per caught
# false "done" to $PROVE_IT_LEDGER_DIR/ledger.jsonl. It holds conversation
# text, so it is created 0600 in a 0700 directory. Local only, never sent.

set -u

INPUT=$(cat)

[ "${PROVE_IT_SKIP:-}" = "1" ] && exit 0

PARSED=$(printf '%s' "$INPUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(1 if d.get('stop_hook_active') else 0)
print(d.get('session_id', 'unknown'))
print(d.get('transcript_path', ''))
" 2>/dev/null) || exit 0
STOP_ACTIVE=$(printf '%s\n' "$PARSED" | sed -n 1p)
SESSION_ID=$(printf '%s\n' "$PARSED" | sed -n 2p)
TRANSCRIPT=$(printf '%s\n' "$PARSED" | sed -n 3p)

[ "$STOP_ACTIVE" = "1" ] && exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
REPO_KEY=$(printf '%s' "$ROOT" | cksum | tr -s ' ' '-')

# Private state, never shared /tmp: these names are predictable, and a
# world-writable directory turns a predictable name into a symlink target.
STATE_DIR="${PROVE_IT_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/prove-it}"
(umask 077 && mkdir -p "$STATE_DIR") 2>/dev/null || exit 0

# A read-only session, or one that only edited some other repo, has nothing
# to prove here.
MARKER="$STATE_DIR/wrote-${SESSION_ID}-${REPO_KEY}"
[ -f "$MARKER" ] || exit 0

VERIFY="$ROOT/verify.sh"
[ -x "$VERIFY" ] || exit 0

DIRTY=$(git -C "$ROOT" status --porcelain 2>/dev/null | head -1)
[ -z "$DIRTY" ] && exit 0

# Tree state hash: HEAD + file list + diff + checksums of untracked files.
# Untracked files never appear in `git diff HEAD`, so hash their contents too.
STATE=$( { git -C "$ROOT" rev-parse HEAD 2>/dev/null
           git -C "$ROOT" status --porcelain 2>/dev/null
           git -C "$ROOT" diff HEAD 2>/dev/null
           git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null | head -500 \
               | while IFS= read -r f; do cksum "$ROOT/$f" 2>/dev/null; done; } | cksum | tr -s ' ' '-')

STAMP="$STATE_DIR/stamp-${REPO_KEY}"
if [ -f "$STAMP" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$STATE" ]; then
    exit 0
fi

OUT=$(cd "$ROOT" && bash "$VERIFY" 2>&1)
RC=$?
if [ "$RC" -eq 0 ]; then
    printf '%s' "$STATE" > "$STAMP" 2>/dev/null
    exit 0
fi

# The gate just caught a false "done". Record it, if the operator asked for that.
if [ "${PROVE_IT_LEDGER:-}" = "1" ]; then
    LEDGER_DIR="${PROVE_IT_LEDGER_DIR:-$HOME/.prove-it}"
    (umask 077 && mkdir -p "$LEDGER_DIR") 2>/dev/null && \
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    REPO="$ROOT" RC="$RC" TRANSCRIPT="$TRANSCRIPT" OUT="$OUT" python3 -c "
import json, os, sys

def last_claim(path):
    '''The agent's final message before it tried to stop: what it claimed.'''
    if not path or not os.path.exists(path):
        return None
    text = None
    try:
        with open(path, encoding='utf-8', errors='replace') as fh:
            for line in fh:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                if rec.get('type') != 'assistant':
                    continue
                content = rec.get('message', {}).get('content')
                if isinstance(content, list):
                    parts = [b.get('text', '') for b in content
                             if isinstance(b, dict) and b.get('type') == 'text']
                    joined = ' '.join(p.strip() for p in parts if p.strip())
                    if joined:
                        text = joined
    except OSError:
        return None
    if text and len(text) > 300:
        text = text[:300] + '...'
    return text

import re

FAILURE = re.compile(
    r'\b(fail|failed|failing|error|assert\w*|expected|actual|traceback|panic|'
    r'exception|not ok|refute|mismatch)\b', re.I)

def salient(output):
    '''The lines that say what went wrong.

    Keeping the tail is wrong. Test runners end with a summary line about how
    many milliseconds they took, while the assertion that explains the failure
    sits further up. Prefer lines that name a failure, and fall back to the
    tail only when none of them do.

    No double quote may appear anywhere in this block: the shell passes it to
    python with -c inside a double-quoted string, and one quote here ends that
    string and silently disables the ledger.
    '''
    lines = [l.rstrip() for l in output.strip().splitlines() if l.strip()]
    hits = [l for l in lines if FAILURE.search(l)]
    chosen = hits[:8] if hits else lines[-5:]
    return [l[:200] for l in chosen]

entry = {
    'ts': os.environ['TS'],
    'repo': os.environ['REPO'],
    'exit_code': int(os.environ['RC']),
    'claim': last_claim(os.environ.get('TRANSCRIPT', '')),
    'evidence_demanded': 'verify.sh exit 0',
    'actual': salient(os.environ['OUT']),
}

# This file holds conversation text. Create it 0600 rather than inheriting a
# umask that would leave it world-readable on a shared machine.
path = os.path.join(sys.argv[1], 'ledger.jsonl')
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
with os.fdopen(fd, 'a', encoding='utf-8') as fh:
    fh.write(json.dumps(entry, ensure_ascii=False) + '\n')
" "$LEDGER_DIR" 2>/dev/null || true
fi

{
    echo "prove-it: verification failed (verify.sh exit ${RC})."
    echo "Fix the cause, then end your turn again. Weakening verify.sh to get past this gate is a violation, not a fix."
    echo "If the failure cannot be fixed, report the cause to the user. (Deliberate bypass: PROVE_IT_SKIP=1)"
    printf '%s\n' "$OUT" | tail -20
} >&2
exit 2
