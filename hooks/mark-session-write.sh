#!/bin/bash
# PostToolUse hook (Edit|MultiEdit|Write|NotebookEdit): mark that this session
# edited files in this repository. prove-it.sh reads the marker to tell an
# editing session apart from a read-only one, and only gates the former.
#
# The marker is keyed by session AND by repository. A session that edited repo A
# must not cause repo B's verify.sh to run when the agent happens to stop with
# B as the working directory.
#
# State lives in a private directory, not in shared /tmp, because a predictable
# name in a world-writable directory is a symlink attack waiting for a
# multi-user machine.
#
# Always exits 0. This hook never blocks anything.

set -u

SESSION_ID=$(cat | python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('session_id', 'unknown'))
except Exception:
    print('unknown')
" 2>/dev/null) || exit 0

# Nothing to gate outside a git repository.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$ROOT" ] || exit 0
REPO_KEY=$(printf '%s' "$ROOT" | cksum | tr -s ' ' '-')

STATE_DIR="${PROVE_IT_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/prove-it}"
(umask 077 && mkdir -p "$STATE_DIR") 2>/dev/null || exit 0

touch "$STATE_DIR/wrote-${SESSION_ID}-${REPO_KEY}" 2>/dev/null
exit 0
