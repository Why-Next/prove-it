#!/bin/bash
# prove-it proves itself. This is the file the gate runs on this repo.
#
# Under a minute, and every check produces evidence rather than an opinion.
# CI runs exactly this script on Linux and macOS. There is no second, secret
# pipeline: what we ask of you is what we ask of ourselves.
set -eu
cd "$(dirname "$0")"

# Command output: every shell script parses.
for f in hooks/*.sh recipes/*.sh tests/*.sh bin/prove-it verify.sh; do
    bash -n "$f"
done

# Cross-check: shellcheck is an independent source from bash's own parser.
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning hooks/*.sh bin/prove-it verify.sh tests/*.sh
else
    echo "verify.sh: shellcheck not installed, skipping static analysis"
fi

# Every JSON file we ship has to parse, or the install silently fails.
for f in hooks/settings.example.json hooks/hooks.json \
         .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f"
done

# The plugin manifests, the hook targets they name, and the version they claim.
python3 scripts/check_plugin.py

# The CI workflow has to parse, or a green local run means nothing.
python3 -c "
import sys
try:
    import yaml
except ImportError:
    print('verify.sh: pyyaml not installed, skipping workflow parse')
    sys.exit(0)
yaml.safe_load(open('.github/workflows/verify.yml'))
"

# The README's demo image has to be well-formed, or GitHub renders a broken icon
# where the pitch should be.
python3 -c "import xml.etree.ElementTree as ET; ET.parse('docs/demo.svg')"

# Prose hygiene across every language: plain hyphens only.
python3 scripts/check_no_long_dash.py

# Cross-check: every translation still agrees with the English original.
python3 scripts/check_i18n.py

# Reproduction: the gate blocks a failing repo and allows a passing one.
bash tests/test_gate.sh

# Reproduction: a fresh install produces a working gate without hand-editing.
bash tests/test_cli.sh

# Diff hygiene.
git diff --check

echo "verify.sh OK"
