#!/bin/bash
# Recipe: Node / TypeScript. Copy to your repo root as verify.sh and trim.
# Target: under a minute. Slow or networked checks belong in CI, not here.
set -eu
cd "$(dirname "$0")"

# Command output: the test runner's own verdict, not our belief about it.
npm test

# Cross-check: the type checker is independent of the test suite.
npx tsc --noEmit

npm run lint --if-present

# Diff hygiene: no conflict markers, no whitespace damage.
git diff --check

# Debug leftovers are the thing linters miss. A focused test is the worst of
# them: the suite goes green because it stopped running.
#
# console.log is deliberately absent. In anything with a command line interface
# it is ordinary output, and a check that fails on ordinary output is a check
# people learn to bypass. Add it here only if your project never prints.
if git diff HEAD | grep -nE '^\+.*(\bdebugger\b|\.only\()' ; then
    echo "verify.sh: debugger or focused test left in the diff" >&2
    exit 1
fi

echo "verify.sh OK"
