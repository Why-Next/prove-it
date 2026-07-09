#!/bin/bash
# Recipe: Python. Copy to your repo root as verify.sh and trim.
# Target: under a minute. Slow or networked checks belong in CI, not here.
set -eu
cd "$(dirname "$0")"

# Command output: pytest's verdict. -q keeps the tail readable for the agent.
python -m pytest -q

# Cross-check: static types are an independent source from the tests.
python -m mypy . || true   # drop the `|| true` once the codebase is clean

python -m ruff check .

git diff --check

if git diff HEAD | grep -nE '^\+.*(breakpoint\(\)|import pdb|print\()' ; then
    echo "verify.sh: debugger or stray print left in the diff" >&2
    exit 1
fi

echo "verify.sh OK"
