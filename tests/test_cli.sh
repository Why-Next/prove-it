#!/bin/bash
# Exercises bin/prove-it and the SessionStart hook against real git repos.
# The point of the CLI is that a user who just installed the plugin gets a
# working gate without writing anything, so these cases are the install
# experience, not an edge case.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
CLI="$HERE/../bin/prove-it"
SESSION_HOOK="$HERE/../hooks/session-start.sh"

SANDBOX=$(mktemp -d)
export PROVE_IT_STATE_DIR="$SANDBOX/state"
trap 'rm -rf "$SANDBOX"' EXIT

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL  %s (expected %s, got %s)\n' "$1" "$2" "$3"; }
expect() { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }

new_repo() {  # name, marker file
    local dir="$SANDBOX/$1"
    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" config user.email "test@example.com"
    git -C "$dir" config user.name "test"
    [ -n "${2:-}" ] && echo "x" > "$dir/$2"
    echo base > "$dir/file.txt"
    git -C "$dir" add -A
    git -C "$dir" -c commit.gpgsign=false commit -qm init
    echo dirty >> "$dir/file.txt"
    printf '%s' "$dir"
}

echo "prove-it cli"

# --- init detects the stack ---------------------------------------------------
for pair in "node:package.json" "go:go.mod" "python:pyproject.toml" "flutter:pubspec.yaml"; do
    stack=${pair%%:*}; marker=${pair##*:}
    D=$(new_repo "detect-$stack" "$marker")
    OUT=$( cd "$D" && bash "$CLI" init 2>&1 )
    case "$OUT" in
        *"detected $stack"*) ok "init detects $stack" ;;
        *) bad "init detects $stack" "detected $stack" "$(printf '%s' "$OUT" | head -1)" ;;
    esac
done

D=$(new_repo detect-generic "")
OUT=$( cd "$D" && bash "$CLI" init 2>&1 )
case "$OUT" in *"detected generic"*) ok "init falls back to generic" ;;
    *) bad "init falls back to generic" "detected generic" "$(printf '%s' "$OUT" | head -1)" ;; esac

# --- the generated verify.sh passes on the day it is written ------------------
D=$(new_repo fresh package.json)
( cd "$D" && bash "$CLI" init >/dev/null 2>&1 )
( cd "$D" && bash ./verify.sh >/dev/null 2>&1 )
expect "the generated verify.sh passes immediately" 0 $?
[ -x "$D/verify.sh" ] && ok "the generated verify.sh is executable" \
                      || bad "the generated verify.sh is executable" "executable" "not"

# Every stack suggestion ships commented out, or the gate fails on day one.
if grep -qE '^[^#]*npm test' "$D/verify.sh"; then
    bad "stack suggestions are commented out" "commented" "active"
else
    ok "stack suggestions are commented out"
fi

# --- the failure demo fails for the right reason ------------------------------
# A copy under /tmp would cd out of the repository and die on `git diff --check`
# with exit 129 and a page of git usage. The user must see exit 1 instead.
D=$(new_repo demo package.json)
OUT=$( cd "$D" && bash "$CLI" init 2>&1 )
case "$OUT" in
    *"-> exit 1  (this is what blocks a turn)"*) ok "the failure demo exits 1" ;;
    *) bad "the failure demo exits 1" "exit 1" "$(printf '%s' "$OUT" | grep -o 'exit [0-9]*' | tail -1)" ;;
esac
case "$OUT" in
    *"Not a git repository"*) bad "the failure demo runs inside the repo" "no git error" "git error" ;;
    *) ok "the failure demo runs inside the repo" ;;
esac
[ -e "$D/.prove-it-demo.sh" ] && bad "the demo copy is cleaned up" "gone" "left behind" \
                             || ok "the demo copy is cleaned up"

# --- init never clobbers an existing gate ------------------------------------
D=$(new_repo existing package.json)
printf '#!/bin/bash\necho mine\n' > "$D/verify.sh"; chmod +x "$D/verify.sh"
OUT=$( cd "$D" && bash "$CLI" init 2>&1 )
expect "init refuses to overwrite verify.sh" "echo mine" "$(sed -n 2p "$D/verify.sh")"
case "$OUT" in *"already exists"*) ok "init says why it refused" ;;
    *) bad "init says why it refused" "already exists" "$OUT" ;; esac

# --- doctor reports the truth -------------------------------------------------
D=$(new_repo doc-none "")
( cd "$D" && bash "$CLI" doctor >/dev/null 2>&1 )
expect "doctor fails when verify.sh is absent" 1 $?

D=$(new_repo doc-nonexec "")
printf '#!/bin/bash\nexit 0\n' > "$D/verify.sh"      # not executable
( cd "$D" && bash "$CLI" doctor >/dev/null 2>&1 )
expect "doctor fails when verify.sh is not executable" 1 $?

D=$(new_repo doc-ok "")
printf '#!/bin/bash\nexit 0\n' > "$D/verify.sh"; chmod +x "$D/verify.sh"
( cd "$D" && bash "$CLI" doctor >/dev/null 2>&1 )
expect "doctor passes on a healthy repo" 0 $?

OUT=$( cd "$SANDBOX" && bash "$CLI" doctor 2>&1 ); RC=$?
expect "doctor fails outside a git repository" 1 "$RC"

# --- the SessionStart hook tells the user whether the gate is armed -----------
payload() { printf '{"session_id":"%s"}' "$1"; }

D=$(new_repo notice-off "")
OUT=$( cd "$D" && payload n1 | bash "$SESSION_HOOK" 2>&1 )
case "$OUT" in *"gate is inert"*) ok "session hook warns when no verify.sh" ;;
    *) bad "session hook warns when no verify.sh" "gate is inert" "$OUT" ;; esac

D=$(new_repo notice-on "")
printf '#!/bin/bash\nexit 0\n' > "$D/verify.sh"; chmod +x "$D/verify.sh"
OUT=$( cd "$D" && payload n2 | bash "$SESSION_HOOK" 2>&1 )
case "$OUT" in *"gate armed"*) ok "session hook confirms when armed" ;;
    *) bad "session hook confirms when armed" "gate armed" "$OUT" ;; esac

# Twice per session would be nagging.
OUT=$( cd "$D" && payload n2 | bash "$SESSION_HOOK" 2>&1 )
expect "session hook speaks once per session" "" "$OUT"

# A different repository in the same session gets its own notice.
E=$(new_repo notice-other "")
OUT=$( cd "$E" && payload n2 | bash "$SESSION_HOOK" 2>&1 )
case "$OUT" in *"gate is inert"*) ok "session hook notices a different repo" ;;
    *) bad "session hook notices a different repo" "a notice" "$OUT" ;; esac

OUT=$( cd "$D" && PROVE_IT_QUIET=1 payload n3 | PROVE_IT_QUIET=1 bash "$SESSION_HOOK" 2>&1 )
expect "PROVE_IT_QUIET=1 silences the hook" "" "$OUT"

OUT=$( cd "$SANDBOX" && payload n4 | bash "$SESSION_HOOK" 2>&1 )
expect "session hook is silent outside a git repository" "" "$OUT"

# --- ledger --------------------------------------------------------------------
export PROVE_IT_LEDGER_DIR="$SANDBOX/no-ledger"
OUT=$( bash "$CLI" ledger 2>&1 )
case "$OUT" in *"off by default"*) ok "ledger explains itself when absent" ;;
    *) bad "ledger explains itself when absent" "off by default" "$OUT" ;; esac

mkdir -p "$SANDBOX/has-ledger"
printf '%s\n' \
  '{"ts":"2026-07-09T04:12:33Z","repo":"/r","exit_code":1,"claim":"All tests pass.","evidence_demanded":"verify.sh exit 0","actual":["3 failed"]}' \
  > "$SANDBOX/has-ledger/ledger.jsonl"
export PROVE_IT_LEDGER_DIR="$SANDBOX/has-ledger"
OUT=$( bash "$CLI" ledger 2>&1 )
case "$OUT" in *"All tests pass."*) ok "ledger reports the agent's claim" ;;
    *) bad "ledger reports the agent's claim" "the claim" "$OUT" ;; esac
unset PROVE_IT_LEDGER_DIR

bash "$CLI" help >/dev/null 2>&1
expect "help exits 0" 0 $?
bash "$CLI" nonsense >/dev/null 2>&1
expect "an unknown command exits non-zero" 1 $?

echo
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
