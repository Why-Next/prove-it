#!/bin/bash
# PostToolUse hook (Edit|MultiEdit|Write|NotebookEdit): mark that this session
# edited files. prove-it.sh reads the marker to tell an editing session apart
# from a read-only one, and only gates the former.
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

touch "${TMPDIR:-/tmp}/prove-it-session-wrote-${SESSION_ID}" 2>/dev/null
exit 0
