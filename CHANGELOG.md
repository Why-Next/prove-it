# Changelog

Notable changes to `prove-it`. The convention has its own version, stated at the
top of [SPEC.md](SPEC.md), and it moves more slowly than the code.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project uses [semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0]

The gate did not gate. An independent review, cross-checked against a second
model, found five ways an agent reached the end of a turn without verification
and one way the project's own CI could not have proved otherwise. Every one of
them now has a test that fails when the fix is removed.

### Fixed

- **The gate blocked exactly once per turn.** Claude Code sets `stop_hook_active`
  on every stop after the first block, and the hook read that flag as permission
  to let the turn end. An agent that fixed nothing and simply stopped again was
  waved through. The turn is now sent back up to `PROVE_IT_MAX_BLOCKS` times
  (default 3), and when the budget is spent the gate yields with a warning the
  user cannot miss rather than in silence.
- **Committing bypassed the gate.** Verification was skipped whenever the working
  tree was clean, so an agent that committed its work before stopping was never
  checked. Committing is the most ordinary thing an agent does.
- **Editing without the Edit tool bypassed the gate.** The hook only knew a
  session had changed a repository if a `PostToolUse` marker fired for `Edit`,
  `Write`, or `NotebookEdit`. A file rewritten with `sed`, a patch applied with
  `git apply`, or anything a code generator emitted left no marker, and the
  repository looked read-only. Change is now measured by comparing the working
  tree against a baseline recorded at session start, so it does not matter which
  tool did the writing.
- **`chmod -x verify.sh` was a silent bypass.** Disarming the gate inside the
  session it was about to block is now refused and explained. Deleting
  `verify.sh` between sessions is still the one-command opt-out it always was.
- **The tree-state stamp ignored untracked files past the 500th.** A `head -500`
  meant a change beyond the cap left the state hash unchanged, and verification
  was skipped. The cap is gone, and hashing is a single process rather than one
  per file, which made it faster than the version that cut corners.
- **The tree-state stamp ignored mode-only changes on untracked files.** A helper
  script could stop being executable while its contents stayed the same, and a
  `verify.sh` that cared about that bit could be skipped after it should have
  started failing.
- **The CI job that proves the gate can fail could not have passed.** It ran the
  session hook in the workspace and the gate in a sandbox repository. The state
  is keyed by repository, the keys never matched, and the gate exited 0 while the
  job asserted 2.
- **`check_embedded_python.py` could not detect the bug it was written for.** It
  matched `python3 -c "..."` and searched the body for a double quote, but a
  double quote in the body is what ends the body. Embedded python now arrives
  through quoted heredocs and the `-c` form is banned outright, which is a rule
  that cannot silently miss.
- **`prove-it init` overwrote and then deleted `.prove-it-demo.sh`** if a
  repository happened to have a file by that name. The demo copy is now a
  `mktemp` name.
- **`recipes/python.sh` failed every diff containing `print(`**, and
  `recipes/node.sh` every diff containing `console.log`. Both are ordinary output
  in anything with a command line. A check that cries wolf is one people learn to
  bypass. Only debuggers and focused tests are flagged now.
- **`recipes/` was never shellchecked**, though it is the code people copy into
  their own repositories.

### Changed

- `PostToolUse` also matches `Bash`, so the fallback marker survives a session
  that began outside the repository it later edits.
- `prove-it doctor` reports the block budget, and no longer implies that a clean
  working tree means nothing to prove.
- The session identifier from the hook payload is sanitised before it becomes
  part of a filename.
- [SPEC.md](SPEC.md) gains two requirements: decide by what changed rather than
  by which tool changed it, and never end a turn silently after a failed
  verification. Both are things this implementation got wrong.

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

[Unreleased]: https://github.com/WhyNext/prove-it/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/WhyNext/prove-it/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/WhyNext/prove-it/releases/tag/v0.1.0
