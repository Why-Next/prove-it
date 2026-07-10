#!/bin/bash
# SessionStart hook. Two jobs, one of them invisible.
#
# The visible one: say once, quietly, whether the gate is armed in this repo.
# Installing the plugin does not arm anything. Without a verify.sh the gate is
# inert, and a silent inert gate is the worst outcome available: the user
# believes their agent is being checked when nothing is checking it.
#
# The invisible one: record what this repository looked like before the session
# touched it, and whether the gate was armed at that moment.
#
#   baseline-*  the tree state at session start. The Stop hook compares against
#               it to decide whether this session changed anything. Asking the
#               tree, rather than asking which tool did the editing, is what
#               makes a change through Bash, git apply, a code generator, or a
#               commit count exactly as much as one through the Edit tool.
#   guard-*     armed or unarmed. An agent that cannot pass verify.sh can always
#               chmod -x it instead. Recording the starting state is what lets
#               the Stop hook tell a deliberate opt-out from a bypass.
#
# Prints at most two lines, once per session per repository. Never blocks.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=hooks/lib.sh
. "$HERE/lib.sh"

INPUT=$(cat)

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$ROOT" ] || exit 0

FIELDS=$(pi_stop_fields "$INPUT") || exit 0
SESSION_ID=$(printf '%s\n' "$FIELDS" | sed -n 2p)
[ -n "$SESSION_ID" ] || SESSION_ID=unknown

REPO_KEY=$(pi_repo_key "$ROOT")
STATE_DIR=$(pi_state_dir)
(umask 077 && mkdir -p "$STATE_DIR") 2>/dev/null || exit 0

# Written once. This hook fires again on resume and on compact, and the baseline
# has to keep pointing at the start of the session rather than at the middle of
# it. Otherwise a compaction forgives every change made before it.
BASELINE="$STATE_DIR/baseline-${SESSION_ID}-${REPO_KEY}"
[ -f "$BASELINE" ] || pi_tree_state "$ROOT" > "$BASELINE" 2>/dev/null

GUARD="$STATE_DIR/guard-${SESSION_ID}-${REPO_KEY}"
[ -f "$GUARD" ] || pi_verify_state "$ROOT" > "$GUARD" 2>/dev/null

# What the gate itself said at session start, so the Stop hook can tell the
# user when a pass went through a verify.sh that was rewritten mid-session.
# Recorded only for a gate that was armed: a verify.sh created during the
# session has no earlier self to differ from.
GATEHASH="$STATE_DIR/gatehash-${SESSION_ID}-${REPO_KEY}"
if [ ! -f "$GATEHASH" ] && [ -x "$ROOT/verify.sh" ]; then
    pi_gate_hash "$ROOT" > "$GATEHASH" 2>/dev/null
fi

# The state above is the point of this hook. The notice below is a courtesy, and
# silencing the courtesy must not silence the gate.
[ "${PROVE_IT_QUIET:-}" = "1" ] && exit 0

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
