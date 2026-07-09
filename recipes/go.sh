#!/bin/bash
# Recipe: Go. Copy to your repo root as verify.sh and trim.
# Target: under a minute. Slow or networked checks belong in CI, not here.
set -eu
cd "$(dirname "$0")"

go test ./...

# Cross-check: vet finds what the compiler and tests both let through.
go vet ./...

# gofmt -l prints files that need formatting; any output means fail.
UNFORMATTED=$(gofmt -l .)
if [ -n "$UNFORMATTED" ]; then
    echo "verify.sh: gofmt needed:" >&2
    printf '%s\n' "$UNFORMATTED" >&2
    exit 1
fi

git diff --check

echo "verify.sh OK"
