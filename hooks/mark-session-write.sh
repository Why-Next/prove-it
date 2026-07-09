#!/bin/bash
# PostToolUse hook: mark that this session wrote something in this repository.
#
# This marker is a fallback, not the primary signal. The Stop hook decides
# whether a session changed a repository by comparing the working tree against
# the baseline that session-start.sh recorded, which catches a change however it
# was made. The marker only matters when there is no baseline, which happens
# when the session began somewhere other than this repository.
#
# It fires on Bash too, because `sed -i`, `git apply`, and every code generator
# in existence write files without going near the Edit tool. A marker is cheap
# and blocks nothing; a missing one used to mean a failing repo sailed through.
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

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=hooks/lib.sh
. "$HERE/lib.sh"

INPUT=$(cat)

# Nothing to gate outside a git repository.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$ROOT" ] || exit 0

FIELDS=$(pi_stop_fields "$INPUT") || exit 0
SESSION_ID=$(printf '%s\n' "$FIELDS" | sed -n 2p)
[ -n "$SESSION_ID" ] || SESSION_ID=unknown

REPO_KEY=$(pi_repo_key "$ROOT")
STATE_DIR=$(pi_state_dir)
(umask 077 && mkdir -p "$STATE_DIR") 2>/dev/null || exit 0

touch "$STATE_DIR/wrote-${SESSION_ID}-${REPO_KEY}" 2>/dev/null
exit 0
