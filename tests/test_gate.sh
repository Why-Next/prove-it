#!/bin/bash
# Exercises hooks/prove-it.sh against real git repos in a sandbox.
# Each case builds a repo, feeds the hook a Stop-hook JSON payload on stdin,
# and asserts the exit code. 0 = let the turn end, 2 = block it.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
GATE="$HERE/../hooks/prove-it.sh"
MARKER_HOOK="$HERE/../hooks/mark-session-write.sh"
SESSION_HOOK="$HERE/../hooks/session-start.sh"

SANDBOX=$(mktemp -d)
# Isolate markers and stamps from the developer's real state directory.
export PROVE_IT_STATE_DIR="$SANDBOX/state"
trap 'rm -rf "$SANDBOX"' EXIT

PASS=0
FAIL=0

# Taken before any hook runs. An older version of this tool kept its state in
# shared /tmp, so those files are still on developer machines, and asserting
# that none exist would fail on debris rather than on this run's behaviour.
SHARED_TMP="${TMPDIR:-/tmp}"
tmp_state() {
    find "$SHARED_TMP" -maxdepth 1 \
        \( -name 'prove-it*' -o -name 'stamp-*' -o -name 'wrote-*' \
           -o -name 'baseline-*' -o -name 'guard-*' -o -name 'attempts-*' \) \
        2>/dev/null | sort
}
tmp_state > "$SANDBOX/tmp-before"

ok()   { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL  %s (expected exit %s, got %s)\n' "$1" "$2" "$3"; }

# A fresh git repo with one commit and a clean working tree.
new_repo() {
    local dir="$SANDBOX/$1"
    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" config user.email "test@example.com"
    git -C "$dir" config user.name "test"
    echo "base" > "$dir/file.txt"
    git -C "$dir" add -A
    git -C "$dir" -c commit.gpgsign=false commit -qm init
    printf '%s' "$dir"
}

new_unborn_repo() {
    local dir="$SANDBOX/$1"
    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" config user.email "test@example.com"
    git -C "$dir" config user.name "test"
    printf '%s' "$dir"
}

write_verify() {  # dir, exit code
    printf '#!/bin/bash\necho "checking %s"\nexit %s\n' "$1" "$2" > "$1/verify.sh"
    chmod +x "$1/verify.sh"
}

commit_all() {  # dir
    git -C "$1" add -A
    git -C "$1" -c commit.gpgsign=false commit -qm work
}

dirty() { echo "dirty" >> "$1/file.txt"; }

payload() {  # session_id, stop_hook_active, transcript_path
    printf '{"session_id":"%s","stop_hook_active":%s,"transcript_path":"%s"}' \
        "$1" "$2" "${3:-}"
}

# The session hook records what the repo looked like before the session touched
# it. It keys on the repo it runs inside, so cd there first. Call it BEFORE the
# repo is changed, exactly as Claude Code does.
start_session() {  # session_id, repo dir
    ( cd "$2" && printf '{"session_id":"%s"}' "$1" \
        | PROVE_IT_QUIET=1 bash "$SESSION_HOOK" >/dev/null )
}

mark_wrote() {  # session_id, repo dir
    ( cd "$2" && printf '{"session_id":"%s"}' "$1" | bash "$MARKER_HOOK" )
}

run_gate() {  # dir, payload -> exit code
    ( cd "$1" && printf '%s' "$2" | bash "$GATE" >/dev/null 2>&1 )
    echo $?
}

expect() {  # name, expected, actual
    [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"
}

echo "prove-it gate"

# --- failing verify.sh blocks the turn ---------------------------------------
D=$(new_repo failing); write_verify "$D" 1; commit_all "$D"
start_session s1 "$D"; dirty "$D"
expect "failing verify.sh blocks the turn" 2 "$(run_gate "$D" "$(payload s1 false)")"

# --- passing verify.sh lets it end -------------------------------------------
D=$(new_repo passing); write_verify "$D" 0; commit_all "$D"
start_session s2 "$D"; dirty "$D"
expect "passing verify.sh allows the turn" 0 "$(run_gate "$D" "$(payload s2 false)")"

# --- no verify.sh means no gate (opt-in) -------------------------------------
D=$(new_repo bare); start_session s3 "$D"; dirty "$D"
expect "absent verify.sh is not a failure" 0 "$(run_gate "$D" "$(payload s3 false)")"

# --- non-executable verify.sh is treated as absent ---------------------------
D=$(new_repo nonexec); write_verify "$D" 1; chmod -x "$D/verify.sh"; commit_all "$D"
start_session s4 "$D"; dirty "$D"
expect "non-executable verify.sh is skipped" 0 "$(run_gate "$D" "$(payload s4 false)")"

# --- a read-only session has nothing to prove --------------------------------
# The tree is already dirty when the session begins, and the session changes
# nothing. The gate compares against the baseline, so it stays out of the way.
D=$(new_repo readonly); write_verify "$D" 1; commit_all "$D"; dirty "$D"
start_session s5 "$D"
expect "read-only session is not gated" 0 "$(run_gate "$D" "$(payload s5 false)")"

# --- committing the work does not bypass the gate ----------------------------
# The old gate skipped a clean working tree, so an agent that committed before
# it stopped was never verified, and committing is the most ordinary thing an
# agent does. The tree state includes HEAD, so the commit is itself the change.
D=$(new_repo committed); write_verify "$D" 1; commit_all "$D"
start_session s6 "$D"
dirty "$D"; commit_all "$D"
expect "a commit does not bypass the gate" 2 "$(run_gate "$D" "$(payload s6 false)")"

# --- an edit made outside the Edit tool is still an edit ----------------------
# Nothing calls the PostToolUse marker here. This is what `sed -i`, `git apply`,
# and every code generator look like from the hook's side.
D=$(new_repo bashedit); write_verify "$D" 1; commit_all "$D"
start_session s7 "$D"
printf 'written by a shell command\n' >> "$D/file.txt"
expect "an edit with no write marker is gated" 2 "$(run_gate "$D" "$(payload s7 false)")"

# --- disarming the gate mid-session is a violation, not an opt-out -----------
D=$(new_repo disarm); write_verify "$D" 1; commit_all "$D"
start_session s8 "$D"; dirty "$D"
chmod -x "$D/verify.sh"
expect "chmod -x during the session blocks" 2 "$(run_gate "$D" "$(payload s8 false)")"

D=$(new_repo delete); write_verify "$D" 1; commit_all "$D"
start_session s9 "$D"; dirty "$D"
rm -f "$D/verify.sh"
expect "deleting verify.sh during the session blocks" 2 "$(run_gate "$D" "$(payload s9 false)")"

# --- the gate blocks more than once, then yields with a warning ---------------
# Claude Code sets stop_hook_active on every stop after the first block. A hook
# that reads that as "let it through" pushes back exactly once and is not a gate.
D=$(new_repo budget); write_verify "$D" 1; commit_all "$D"
start_session s10 "$D"; dirty "$D"
export PROVE_IT_MAX_BLOCKS=2
expect "first stop blocks" 2 "$(run_gate "$D" "$(payload s10 false)")"
expect "second stop blocks despite stop_hook_active" 2 "$(run_gate "$D" "$(payload s10 true)")"
expect "the gate yields once the budget is spent" 0 "$(run_gate "$D" "$(payload s10 true)")"

# Yielding is not the same as passing, and the user has to be told which it was.
GIVEUP=$( cd "$D" && payload s10 true | bash "$GATE" 2>/dev/null )
case "$GIVEUP" in
    *systemMessage*"without passing verification"*) ok "yielding warns the user" ;;
    *) bad "yielding warns the user" "a systemMessage" "${GIVEUP:-nothing}" ;;
esac

# A new stretch of work resets the budget: stop_hook_active is false again.
expect "a new stretch of work blocks again" 2 "$(run_gate "$D" "$(payload s10 false)")"
unset PROVE_IT_MAX_BLOCKS

# --- explicit bypass ---------------------------------------------------------
D=$(new_repo bypass); write_verify "$D" 1; commit_all "$D"
start_session s11 "$D"; dirty "$D"
export PROVE_IT_SKIP=1
expect "PROVE_IT_SKIP=1 bypasses the gate" 0 "$(run_gate "$D" "$(payload s11 false)")"
unset PROVE_IT_SKIP

# --- a passing tree is verified once, not on every stop ----------------------
D=$(new_repo stamp); write_verify "$D" 0; commit_all "$D"
start_session s12 "$D"; dirty "$D"
_=$(run_gate "$D" "$(payload s12 false)")          # first stop: runs, stamps
write_verify "$D" 1                               # would now fail...
# ...but writing verify.sh changed the tree, so the stamp must be invalidated.
expect "changing the tree re-runs verification" 2 "$(run_gate "$D" "$(payload s12 false)")"

# --- the stamp sees every untracked file, not the first few -------------------
# The tree state used to hash only the first 500 untracked files. Past that, a
# content change left the hash identical and the gate skipped the run.
D=$(new_repo manyuntracked)
cat > "$D/verify.sh" <<'EOF'
#!/bin/bash
grep -q v1 zzz_last.txt
EOF
chmod +x "$D/verify.sh"; commit_all "$D"
start_session s13 "$D"
i=1; while [ "$i" -le 520 ]; do echo pad > "$D/pad_$i.txt"; i=$((i + 1)); done
echo v1 > "$D/zzz_last.txt"
expect "the passing tree is allowed" 0 "$(run_gate "$D" "$(payload s13 false)")"
echo v2 > "$D/zzz_last.txt"   # contents change, the file list does not
expect "an untracked file past the 500th invalidates the stamp" \
    2 "$(run_gate "$D" "$(payload s13 false)")"

# --- mode-only changes to untracked files also invalidate the stamp -----------
# `git diff HEAD` never sees untracked files, and `git status --porcelain` only
# says the path is untracked. If the tree hash ignores the mode bit, a verify.sh
# that cares whether an untracked helper is executable can be skipped after it
# should have started failing.
D=$(new_repo untrackedmode)
cat > "$D/verify.sh" <<'EOF'
#!/bin/bash
test -x tool.sh
EOF
chmod +x "$D/verify.sh"; commit_all "$D"
start_session s13mode "$D"
printf '#!/bin/bash\necho tool\n' > "$D/tool.sh"
chmod +x "$D/tool.sh"
expect "an untracked executable helper is allowed" \
    0 "$(run_gate "$D" "$(payload s13mode false)")"
chmod -x "$D/tool.sh"
expect "an untracked mode-only change invalidates the stamp" \
    2 "$(run_gate "$D" "$(payload s13mode false)")"

# --- symlink-only changes to untracked files invalidate the stamp -------------
D=$(new_repo untrackedsymlink)
cat > "$D/verify.sh" <<'EOF'
#!/bin/bash
test "$(readlink current)" = target-a
EOF
chmod +x "$D/verify.sh"; commit_all "$D"
start_session s13link "$D"
ln -s target-a "$D/current"
expect "an untracked symlink target is allowed" \
    0 "$(run_gate "$D" "$(payload s13link false)")"
rm -f "$D/current"
ln -s target-b "$D/current"
expect "an untracked symlink target change invalidates the stamp" \
    2 "$(run_gate "$D" "$(payload s13link false)")"

# --- unborn repositories still have a tree state ------------------------------
D=$(new_unborn_repo unborn)
write_verify "$D" 1
start_session s13unborn "$D"
echo first > "$D/file.txt"
expect "an unborn repository with a change is gated" \
    2 "$(run_gate "$D" "$(payload s13unborn false)")"

# --- the ledger records a caught false completion ----------------------------
D=$(new_repo ledger); write_verify "$D" 1; commit_all "$D"
start_session s14 "$D"; dirty "$D"
TRANSCRIPT="$SANDBOX/transcript.jsonl"
printf '%s\n' \
  '{"type":"assistant","message":{"content":[{"type":"text","text":"All tests pass. Ready to merge."}]}}' \
  > "$TRANSCRIPT"
export PROVE_IT_LEDGER=1 PROVE_IT_LEDGER_DIR="$SANDBOX/ledger"
expect "ledger case still blocks" 2 "$(run_gate "$D" "$(payload s14 false "$TRANSCRIPT")")"

LEDGER="$SANDBOX/ledger/ledger.jsonl"
# Assert on parsed JSON, not on its formatting: json.dumps puts a space after
# each colon, so grepping for '"claim":"..."' would test the serializer.
ledger_field() {  # field -> value, via python
    PI_LEDGER="$LEDGER" PI_FIELD="$1" python3 2>/dev/null <<'PY'
import json, os
with open(os.environ["PI_LEDGER"], encoding="utf-8") as fh:
    rec = json.loads(fh.readlines()[-1])
print(rec.get(os.environ["PI_FIELD"]))
PY
}

ledger_rows() { [ -f "$LEDGER" ] && wc -l < "$LEDGER" | tr -d ' ' || echo 0; }

if [ -f "$LEDGER" ]; then
    ok "ledger file written"
    expect "ledger captures the agent's claim" \
        "All tests pass. Ready to merge." "$(ledger_field claim)"
    expect "ledger records the exit code" 1 "$(ledger_field exit_code)"
else
    bad "ledger file written" "file at $LEDGER" "missing"
    bad "ledger captures the agent's claim" "a claim" "no ledger"
    bad "ledger records the exit code" 1 "no ledger"
fi

# Blocking three times over one stretch of work is one false completion, not
# three. A ledger that counted retries would inflate its own headline number.
_=$(run_gate "$D" "$(payload s14 true "$TRANSCRIPT")")
expect "a retry does not add a second ledger row" 1 "$(ledger_rows)"
unset PROVE_IT_LEDGER PROVE_IT_LEDGER_DIR

# --- the ledger stays off unless asked for -----------------------------------
D=$(new_repo noledger); write_verify "$D" 1; commit_all "$D"
start_session s15 "$D"; dirty "$D"
export PROVE_IT_LEDGER_DIR="$SANDBOX/ledger-off"
_=$(run_gate "$D" "$(payload s15 false "$TRANSCRIPT")")
[ -e "$SANDBOX/ledger-off" ] \
    && bad "ledger is off by default" "no directory" "created" \
    || ok "ledger is off by default"
unset PROVE_IT_LEDGER_DIR

# --- a session in one repo must not gate a different repo --------------------
# Change trusted repo A, then stop while sitting in untrusted repo B. B's
# verify.sh must not run. Found by an independent security review, 2026-07-09.
A=$(new_repo cross-a); write_verify "$A" 0; commit_all "$A"
B=$(new_repo cross-b); write_verify "$B" 1; commit_all "$B"
start_session s16 "$A"; start_session s16 "$B"
dirty "$A"     # B is never touched in this session
expect "changing repo A does not gate repo B" 0 "$(run_gate "$B" "$(payload s16 false)")"
dirty "$B"
expect "once B is changed too, B is gated" 2 "$(run_gate "$B" "$(payload s16 false)")"

# --- the fallback path, for a session that began outside the repository ------
# No baseline exists, so the gate falls back to the write marker plus a dirty
# tree. It is the weaker test, and the reason the baseline exists at all.
D=$(new_repo fallback); write_verify "$D" 1; commit_all "$D"
dirty "$D"                                    # no start_session for s17
expect "without a baseline, an unmarked session is not gated" \
    0 "$(run_gate "$D" "$(payload s17 false)")"
mark_wrote s17 "$D"
expect "without a baseline, a marked dirty session is gated" \
    2 "$(run_gate "$D" "$(payload s17 false)")"

# --- state never lands in shared /tmp ----------------------------------------
# A predictable name in a world-writable directory is a symlink target. Compare
# against the snapshot taken before the first hook ran: only files this run
# created count, and only the names this project would ever use are considered,
# so an unrelated process making a temp file cannot fail the suite.
tmp_state > "$SANDBOX/tmp-after"
STRAY=$(comm -13 "$SANDBOX/tmp-before" "$SANDBOX/tmp-after" | grep -c . || true)
expect "the gate creates nothing in shared /tmp" 0 "$STRAY"

# The stamp belongs to this repository, not to whichever case happened to run
# first. Checking for any stamp-* at all would pass without this case running.
D=$(new_repo statedir); write_verify "$D" 0; commit_all "$D"
start_session s18 "$D"; dirty "$D"
_=$(run_gate "$D" "$(payload s18 false)")
ROOT=$(git -C "$D" rev-parse --show-toplevel)
KEY=$(printf '%s' "$ROOT" | cksum | tr -s ' ' '-')
[ -f "$PROVE_IT_STATE_DIR/stamp-$KEY" ] \
    && ok "the stamp is written under PROVE_IT_STATE_DIR, keyed to this repo" \
    || bad "the stamp is written under PROVE_IT_STATE_DIR, keyed to this repo" \
           "stamp-$KEY" "missing"

perms() { ls -ld "$1" | cut -c1-10; }

expect "state dir is 0700" "drwx------" "$(perms "$PROVE_IT_STATE_DIR")"

# --- the ledger holds conversation text, so it must not be world readable ----
D=$(new_repo ledgerperm); write_verify "$D" 1; commit_all "$D"
start_session s19 "$D"; dirty "$D"
export PROVE_IT_LEDGER=1 PROVE_IT_LEDGER_DIR="$SANDBOX/ledger-perm"
_=$(run_gate "$D" "$(payload s19 false "$TRANSCRIPT")")
expect "ledger dir is 0700" "drwx------" "$(perms "$PROVE_IT_LEDGER_DIR")"
expect "ledger file is 0600" "-rw-------" "$(perms "$PROVE_IT_LEDGER_DIR/ledger.jsonl")"
unset PROVE_IT_LEDGER PROVE_IT_LEDGER_DIR

# --- a session id off the wire lands in a filename, so it must be sanitised ---
D=$(new_repo traversal)
( cd "$D" && printf '{"session_id":"../../../../../../tmp/prove-it-pwn"}' \
    | bash "$MARKER_HOOK" )
[ -e "/tmp/prove-it-pwn" ] \
    && bad "a hostile session id cannot escape the state dir" "no file" "wrote /tmp/prove-it-pwn" \
    || ok "a hostile session id cannot escape the state dir"

echo
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
