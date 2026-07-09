# Changelog

Notable changes to `prove-it`. The convention has its own version, stated at the
top of [SPEC.md](SPEC.md), and it moves more slowly than the code.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project uses [semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0]

First public release. Convention `verify.sh` 0.1, reference implementation, and
one deliberate limitation stated in plain sight.

### Added

- **The `verify.sh` convention** ([SPEC.md](SPEC.md)). A repository declares how
  it proves itself, at a known path, with a known contract. Four kinds of
  evidence: command output, diff, reproduction, cross-check.
- **The gate** (`hooks/prove-it.sh`). A Claude Code `Stop` hook that runs
  `verify.sh` at the repo root and blocks the turn on non-zero exit. Skips
  read-only sessions, clean trees, and tree states that already passed.
  Bypass with `PROVE_IT_SKIP=1`.
- **Claude Code plugin** (`/plugin install prove-it@whynext`), with two commands.
  `/prove-it:init` writes a first `verify.sh` and makes the user watch it fail
  once. `/prove-it:ledger` reads back what the gate has caught. The hooks are
  plain bash and remain usable without the plugin.
- **`bin/prove-it`**, a dependency-free CLI behind those commands. `init`
  detects the stack and scaffolds a gate that passes on the day it is written,
  with the stack's own checks commented out until you have watched each pass.
  `doctor` says whether the gate would fire here and what is stopping it.
  `ledger` summarises what the gate has caught.
- **A SessionStart notice.** Installing the plugin arms nothing on its own, so
  the plugin says once per session whether this repository has a gate. A silent
  inert gate is worse than none: you would believe you were covered.
- **The ledger** (`PROVE_IT_LEDGER=1`). One JSON line per caught false
  completion, holding what the agent claimed, what was demanded, and what was
  true. It keeps the lines of output that name a failure rather than the tail,
  because test runners end with a duration and begin the interesting part
  further up. Local disk only, never transmitted, off by default.
- **Recipes** for Node, Python, Go, and Flutter.
- **Every document in eleven languages.** README, SPEC, CONTRIBUTING, SECURITY,
  and CODE_OF_CONDUCT, held to their English originals by
  `scripts/check_i18n.py`. The English SPEC is normative, and each translation
  says so and links back to it.

### Security

Found by an independent review of this release before it shipped, and fixed
before the first tag. Each has a regression test in `tests/test_gate.sh`.

- The session marker and the tree-state stamp lived in shared `/tmp` under names
  derived from the repository path. On a multi-user machine a planted symlink
  could have redirected the stamp write. State now lives in
  `$XDG_STATE_HOME/prove-it/`, mode `0700`.
- The ledger inherited the process umask and was typically created world
  readable, despite holding conversation text. It is now created `0600` inside a
  `0700` directory.
- The session marker recorded that *a* file was edited, not *where*. Editing a
  trusted repository and then stopping inside an untrusted one would have run
  the untrusted `verify.sh`. The marker is now keyed by repository.

### Known limitations

- The gate enforces that `verify.sh` returned zero. It cannot enforce that the
  zero means anything. A `verify.sh` containing only `exit 0` passes. This is
  Level 1 of the spec's conformance levels, and no tool can give you Level 2.
- Only Claude Code exposes an end-of-turn hook that can block a turn. Other
  agents can run the gate, but not be stopped by it.

[Unreleased]: https://github.com/WhyNext/prove-it/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/WhyNext/prove-it/releases/tag/v0.1.0
