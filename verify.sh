#!/bin/bash
# prove-it proves itself. This is the file the gate runs on this repo.
set -eu
cd "$(dirname "$0")"

# Command output: every shell script parses.
for f in hooks/*.sh recipes/*.sh tests/*.sh verify.sh; do
    bash -n "$f"
done

# Cross-check: shellcheck is an independent source from bash's own parser.
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning hooks/*.sh verify.sh tests/*.sh
else
    echo "verify.sh: shellcheck not installed, skipping static analysis"
fi

# The example settings file has to be valid JSON, or the install silently fails.
python3 -c "import json; json.load(open('hooks/settings.example.json'))"

# Prose hygiene across every language: plain hyphens only.
python3 scripts/check_no_long_dash.py

# Cross-check: every translation still agrees with the English original.
python3 scripts/check_i18n.py

# Reproduction: the gate blocks a failing repo and allows a passing one.
bash tests/test_gate.sh

# Diff hygiene.
git diff --check

echo "verify.sh OK"
