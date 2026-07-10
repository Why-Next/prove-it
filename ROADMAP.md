# Roadmap

This roadmap describes direction, not a promise of dates.

## Now

- Keep the gate small, auditable, and dependency-free.
- Keep `./verify.sh` under one minute on normal developer machines.
- Improve installation diagnostics before adding new integration surfaces.
- Treat security boundary documentation as part of the product.

## Next

- Publish the first signed or annotated release with downloadable source
  package, SHA-256 checksum, and GitHub provenance attestation.
- Add more real-world recipes only after each has a clear failure mode it can
  catch.
- Improve ledger summaries so users can see recurring false-completion patterns
  without exposing private transcript content.
- Collect downstream feedback on `SPEC.md` before changing conformance levels.

## Later

- Explore adapters for other agents that can run an end-of-turn hook.
- Add optional policy checks for repositories that want stricter local gates.
- Document patterns for CI-only checks that should not run inside `verify.sh`.

## Non-Goals

- No daemon.
- No network service.
- No telemetry.
- No sandbox claims.
- No package-manager dependency just to install the hook.
