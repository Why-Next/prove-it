#!/bin/bash
# Recipe: Flutter / Dart. Copy to your repo root as verify.sh and trim.
# Target: under a minute. Integration and golden tests belong in CI, not here.
set -eu
cd "$(dirname "$0")"

flutter analyze

flutter test

# --set-exit-if-changed turns "would reformat" into a failure.
dart format --output=none --set-exit-if-changed .

git diff --check

echo "verify.sh OK"
