#!/bin/bash
# SessionStart hook: say once, quietly, whether the gate is armed in this repo.
#
# Installing the plugin does not arm anything. Without a verify.sh the gate is
# inert, and a silent inert gate is the worst outcome available: the user
# believes their agent is being checked when nothing is checking it.
#
# Prints at most two lines, once per session per repository. Never blocks.

set -u

[ "${PROVE_IT_QUIET:-}" = "1" ] && exit 0

SESSION_ID=$(cat | python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('session_id', 'unknown'))
except Exception:
    print('unknown')
" 2>/dev/null) || exit 0

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$ROOT" ] || exit 0
REPO_KEY=$(printf '%s' "$ROOT" | cksum | tr -s ' ' '-')

STATE_DIR="${PROVE_IT_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/prove-it}"
(umask 077 && mkdir -p "$STATE_DIR") 2>/dev/null || exit 0

# One notice per session per repository, however many times this fires.
NOTICE="$STATE_DIR/notice-${SESSION_ID}-${REPO_KEY}"
[ -f "$NOTICE" ] && exit 0
touch "$NOTICE" 2>/dev/null

if [ -x "$ROOT/verify.sh" ]; then
    echo "prove-it: gate armed. ./verify.sh must pass before a turn can end."
else
    echo "prove-it: no executable verify.sh here, so the gate is inert."
    echo "prove-it: run /prove-it:init to write one, or ignore this and it stays off."
fi

exit 0
