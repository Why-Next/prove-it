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

# Reproduction and debug leftovers are the two things linters miss.
if git diff HEAD | grep -nE '^\+.*(console\.log|debugger|\.only\()' ; then
    echo "verify.sh: debug statement or focused test left in the diff" >&2
    exit 1
fi

echo "verify.sh OK"
