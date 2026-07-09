#!/bin/bash
# Exercises hooks/prove-it.sh against real git repos in a sandbox.
# Each case builds a repo, feeds the hook a Stop-hook JSON payload on stdin,
# and asserts the exit code. 0 = let the turn end, 2 = block it.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
GATE="$HERE/../hooks/prove-it.sh"
MARKER_HOOK="$HERE/../hooks/mark-session-write.sh"

SANDBOX=$(mktemp -d)
# Isolate markers and stamps from the developer's real /tmp.
export TMPDIR="$SANDBOX/tmp"
mkdir -p "$TMPDIR"
trap 'rm -rf "$SANDBOX"' EXIT

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL  %s (expected exit %s, got %s)\n' "$1" "$2" "$3"; }

# A fresh git repo with one commit and a dirty working tree.
new_repo() {
    local dir="$SANDBOX/$1"
    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" config user.email "test@example.com"
    git -C "$dir" config user.name "test"
    echo "base" > "$dir/file.txt"
    git -C "$dir" add -A
    git -C "$dir" -c commit.gpgsign=false commit -qm init
    echo "dirty" >> "$dir/file.txt"     # uncommitted change: the gate may run
    printf '%s' "$dir"
}

write_verify() {  # dir, exit code
    printf '#!/bin/bash\necho "checking %s"\nexit %s\n' "$1" "$2" > "$1/verify.sh"
    chmod +x "$1/verify.sh"
}

payload() {  # session_id, stop_hook_active, transcript_path
    printf '{"session_id":"%s","stop_hook_active":%s,"transcript_path":"%s"}' \
        "$1" "$2" "${3:-}"
}

mark_wrote() { printf '{"session_id":"%s"}' "$1" | bash "$MARKER_HOOK"; }

run_gate() {  # dir, payload -> exit code
    ( cd "$1" && payload_in="$2"; printf '%s' "$payload_in" | bash "$GATE" >/dev/null 2>&1 )
    echo $?
}

expect() {  # name, expected, actual
    [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"
}

echo "prove-it gate"

# --- failing verify.sh blocks the turn ---------------------------------------
D=$(new_repo failing); write_verify "$D" 1; mark_wrote s1
expect "failing verify.sh blocks the turn" 2 "$(run_gate "$D" "$(payload s1 false)")"

# --- passing verify.sh lets it end -------------------------------------------
D=$(new_repo passing); write_verify "$D" 0; mark_wrote s2
expect "passing verify.sh allows the turn" 0 "$(run_gate "$D" "$(payload s2 false)")"

# --- no verify.sh means no gate (opt-in) -------------------------------------
D=$(new_repo bare); mark_wrote s3
expect "absent verify.sh is not a failure" 0 "$(run_gate "$D" "$(payload s3 false)")"

# --- non-executable verify.sh is treated as absent ---------------------------
D=$(new_repo nonexec); write_verify "$D" 1; chmod -x "$D/verify.sh"; mark_wrote s4
expect "non-executable verify.sh is skipped" 0 "$(run_gate "$D" "$(payload s4 false)")"

# --- a read-only session has nothing to prove --------------------------------
D=$(new_repo readonly); write_verify "$D" 1   # no mark_wrote for s5
expect "read-only session is not gated" 0 "$(run_gate "$D" "$(payload s5 false)")"

# --- a clean tree is skipped even when verify.sh would fail ------------------
D=$(new_repo clean); write_verify "$D" 1
git -C "$D" add -A; git -C "$D" -c commit.gpgsign=false commit -qm all; mark_wrote s6
expect "clean tree is skipped" 0 "$(run_gate "$D" "$(payload s6 false)")"

# --- stop_hook_active guards against an infinite loop ------------------------
D=$(new_repo loop); write_verify "$D" 1; mark_wrote s7
expect "stop_hook_active passes (no loop)" 0 "$(run_gate "$D" "$(payload s7 true)")"

# --- explicit bypass ---------------------------------------------------------
D=$(new_repo bypass); write_verify "$D" 1; mark_wrote s8
export PROVE_IT_SKIP=1
expect "PROVE_IT_SKIP=1 bypasses the gate" 0 "$(run_gate "$D" "$(payload s8 false)")"
unset PROVE_IT_SKIP

# --- a passing tree is verified once, not on every stop ----------------------
D=$(new_repo stamp); mark_wrote s9
write_verify "$D" 0
_=$(run_gate "$D" "$(payload s9 false)")          # first stop: runs, stamps
write_verify "$D" 1                               # would now fail...
# ...but writing verify.sh changed the tree, so the stamp must be invalidated.
expect "changing the tree re-runs verification" 2 "$(run_gate "$D" "$(payload s9 false)")"

# --- the ledger records a caught false completion ----------------------------
D=$(new_repo ledger); write_verify "$D" 1; mark_wrote s10
TRANSCRIPT="$SANDBOX/transcript.jsonl"
printf '%s\n' \
  '{"type":"assistant","message":{"content":[{"type":"text","text":"All tests pass. Ready to merge."}]}}' \
  > "$TRANSCRIPT"
export PROVE_IT_LEDGER=1 PROVE_IT_LEDGER_DIR="$SANDBOX/ledger"
expect "ledger case still blocks" 2 "$(run_gate "$D" "$(payload s10 false "$TRANSCRIPT")")"

LEDGER="$SANDBOX/ledger/ledger.jsonl"
# Assert on parsed JSON, not on its formatting: json.dumps puts a space after
# each colon, so grepping for '"claim":"..."' would test the serializer.
ledger_field() {  # field -> value, via python
    python3 -c "
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    rec = json.loads(fh.readlines()[-1])
print(rec.get(sys.argv[2]))
" "$LEDGER" "$1" 2>/dev/null
}

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
unset PROVE_IT_LEDGER PROVE_IT_LEDGER_DIR

# --- the ledger stays off unless asked for -----------------------------------
D=$(new_repo noledger); write_verify "$D" 1; mark_wrote s11
export PROVE_IT_LEDGER_DIR="$SANDBOX/ledger-off"
_=$(run_gate "$D" "$(payload s11 false "$TRANSCRIPT")")
[ -e "$SANDBOX/ledger-off" ] \
    && bad "ledger is off by default" "no directory" "created" \
    || ok "ledger is off by default"
unset PROVE_IT_LEDGER_DIR

echo
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
