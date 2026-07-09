# prove-it

[![verify](https://github.com/Why-Next/prove-it/actions/workflows/verify.yml/badge.svg)](https://github.com/Why-Next/prove-it/actions/workflows/verify.yml)
[![spec 0.1](https://img.shields.io/badge/spec-0.1-4F6134)](SPEC.md)
[![license MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)
![dependencies none](https://img.shields.io/badge/dependencies-none-4F6134)

English ·
[中文](docs/i18n/README.zh.md) ·
[Deutsch](docs/i18n/README.de.md) ·
[日本語](docs/i18n/README.ja.md) ·
[हिन्दी](docs/i18n/README.hi.md) ·
[Français](docs/i18n/README.fr.md) ·
[Italiano](docs/i18n/README.it.md) ·
[Português](docs/i18n/README.pt.md) ·
[Русский](docs/i18n/README.ru.md) ·
[Español](docs/i18n/README.es.md) ·
[한국어](docs/i18n/README.ko.md)

Your agent cannot end its turn until your repository proves itself.

Coding agents report that the tests pass when they never ran them, and that a bug
is fixed when they never reproduced it. The agent has no way to compare what it
did against what it meant to do, so it reports the intention. That is a design
property, not a character flaw, and no prompt fixes it.

`prove-it` turns the report into a check. Put a `verify.sh` at your repository
root. When the agent tries to end its turn, a hook runs the script, and a
non-zero exit sends the agent back to work instead of letting it stop.

![prove-it blocks an agent that claims it is done](docs/demo.svg)

The gate pushes back up to three times per turn and then yields, because a hook
that never yields hangs the session. Yielding is not the same as passing, so the
last thing you see is a warning that the turn ended unverified rather than the
word "done." Three is a number you can change, and none of this is a claim that
your agent cannot get past the gate. It is a claim that it cannot get past the
gate quietly.

Use it when a repository has a local command that must be true before an agent
hands work back: tests, type checks, lint, generated-file checks, migration dry
runs, or the small smoke test that proves the bug is gone. `prove-it` is most
useful in repositories where an agent edits code and then says "done" in the
same thread.

Do not use it as a sandbox, a CI replacement, or a place for long networked
jobs. If a check needs secrets, production access, or more than about a minute,
put that check in CI and keep `verify.sh` to the local proof the agent can run
while it is still working.

The first-day flow is deliberately small. Install the plugin, run
`/prove-it:init`, keep the generated `git diff --check` as the only active check,
then turn on one real command after you have watched it pass by hand. From then
on, when the agent changes the repository and tries to stop, `verify.sh` decides
whether it may hand the work back.

## Install

Three lines, and the third one does the work:

```
/plugin marketplace add Why-Next/prove-it
/plugin install prove-it@whynext
/prove-it:init
```

`/prove-it:init` detects your stack, writes a `verify.sh`, runs it so you watch
it pass, then runs a copy with `exit 1` appended so you watch the gate refuse a
turn. It takes about thirty seconds and it never overwrites a `verify.sh` you
already have.

The generated gate has exactly one active check, `git diff --check`, with the
checks for your stack written in as comments. It passes on the day you install
it, deliberately. A gate that fails on `main` the day it lands teaches people to
bypass it in the first week. Switch the commented checks on one at a time, after
you have watched each one pass by hand.

Nothing else is configured, and nothing runs until a `verify.sh` exists. If you
open a repository that has none, the plugin says so at the start of the session
rather than staying quiet and letting you assume you are covered.

## Without the plugin

The hooks are plain bash and need only `bash`, `git`, and `python3`:

```bash
git clone https://github.com/Why-Next/prove-it ~/.local/share/prove-it
~/.local/share/prove-it/bin/prove-it init
```

Merge [`hooks/settings.example.json`](hooks/settings.example.json) into your
`.claude/settings.json` for one repository, or `~/.claude/settings.json` for all
of them. The gate reads a Stop-hook JSON payload on stdin and answers with an
exit code, so anything that can run a script at end of turn can drive it.

`prove-it doctor` answers whether the gate would fire in the repository you are
standing in, and tells you what is stopping it if it would not:

```
repository   /home/you/src/api
verify.sh    present and executable
working tree dirty
blocks       up to 3 per turn, then it yields with a warning
state        /home/you/.local/state/prove-it
ledger       off (export PROVE_IT_LEDGER=1 to record what the gate catches)
```

## Growing the gate

Each check you add is a sentence in your answer to the question of what "proven"
means in this repository. Add the test command you actually run, then the type
checker, then whatever your reviews keep catching. Stop when the whole script
takes about a minute; slow checks belong in CI.

Run every check by hand before you switch it on. Never ship a check you have not
watched fail, either: a check that cannot fail is not a check, and you will not
find that out on the day you need it.

The common mistake is writing an ambitious `verify.sh` on the first day. A gate
that is slow or flaky gets bypassed within a week, and a bypassed gate is worse
than no gate, because it reports that a check ran when nothing did.

## How it decides to run

The gate stays quiet unless all of these hold:

- this session changed this repository
- an executable `verify.sh` exists at the repository root
- this exact tree state has not already passed

"Changed" is answered by the repository, not by a log of which tools ran. At the
start of a session the hook records what the tree looked like, and at every stop
it asks whether the tree still looks that way. A file rewritten by `sed`, a patch
applied with `git apply`, a file emitted by a code generator, and a commit are
all changes, because all of them change the tree. A session that only read
counts as nothing, even in a repository that was already dirty when it opened.

The last condition means a passing tree is verified once rather than on every
stop. When verification fails, the agent sees the last twenty lines of output,
which is usually enough for it to fix the cause without being told what went
wrong.

`PROVE_IT_SKIP=1` gets past the gate on purpose. Deleting `verify.sh` between
sessions turns it off for good. Both escape hatches are deliberate: people route
around a gate they cannot remove. `PROVE_IT_MAX_BLOCKS` sets how many times one
turn can be sent back, and `0` makes the gate report without ever blocking.

## When the agent edits the gate

The hardest failure mode is not a flaky check. It is an agent that cannot make
`verify.sh` pass and edits `verify.sh` instead.

The cheapest version of that is disarming the gate outright, so the gate refuses
it. The hook records whether `verify.sh` was executable when the session began,
and a session that ends with it deleted or with its executable bit removed is
blocked, told what it did, and told how to opt out honestly if that is what it
meant. Deleting `verify.sh` between sessions is still an opt-out and still takes
one command.

What remains unenforced is the subtle version: an agent that keeps `verify.sh`
executable and quietly guts the checks inside it. The failure message tells it
not to, and [SPEC.md](SPEC.md) calls that a violation rather than a fix, but
neither of those is enforcement. Read your diffs. That is what the diff evidence
in the spec is for.

## The `verify.sh` convention

The script in `hooks/` is deliberately small. What it implements is written down
in [SPEC.md](SPEC.md): a repository declares how it proves itself, at a known
path, with a known contract, and an agent may not claim completion until that
proof passes. The spec names a file and an exit code and never names a vendor, so
the plugin is one way to distribute the idea rather than the idea itself.

Read the spec for the four kinds of evidence a `verify.sh` should assert against,
which are command output, diff, reproduction, and cross-check, and for the
conformance levels.

## What this does not do

The gate enforces one thing: that `verify.sh` returned zero before the turn
ended. Whether that zero means anything depends entirely on the checks you wrote.
A `verify.sh` containing only `exit 0` passes this gate and proves nothing.

The spec calls that Level 1. Level 2 is whether your checks assert against real
evidence, and no tool can verify that for you, this one included.

Three more boundaries, stated plainly because you will otherwise find them at a
bad moment. The gate yields after `PROVE_IT_MAX_BLOCKS` refusals, so a determined
agent reaches the end of its turn; what it cannot do is arrive there silently.
Files your `.gitignore` excludes are invisible to the change detection, so a
`verify.sh` that reads an ignored `.env` may be skipped when only that file
changed. And a session that begins outside the repository it later edits has no
baseline to compare against, which drops the gate back to the weaker test of
whether the working tree is dirty.

## Recipes

Starting points per stack live in [`recipes/`](recipes/). Copy one to
`verify.sh` and cut what does not apply. Keep it under a minute; slow checks
belong in CI.

| | |
|---|---|
| [`node.sh`](recipes/node.sh) | tests, typecheck, lint, diff hygiene |
| [`python.sh`](recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](recipes/flutter.sh) | analyze, test, format check |

Wiring the hook is the easy part. The work is answering what "proven" means in
your repository, and no recipe answers that for you.

## The ledger

Set `PROVE_IT_LEDGER=1` and each caught false completion appends one line to
`~/.prove-it/ledger.jsonl`:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

The line records what the agent claimed, what was demanded of it, and what turned
out to be true. The file is written to local disk with mode `0600`, nothing
transmits it anywhere, and it stays off until you turn it on. After a month of
entries you can stop guessing about how your agent fails and read it instead.
`/prove-it:ledger` summarises the file for you, as does `prove-it ledger` on the
command line.

## This repo gates itself

`prove-it` has a `verify.sh`, and part of what it runs is the gate itself,
against real git repositories in a temporary directory: a failing check blocks,
a passing check allows, a read-only session is left alone, a clean tree is
not mistaken for no work after a commit, the bypass works.

```bash
./verify.sh
```

CI runs that same script on Linux and macOS, plus a separate job that proves the
gate still blocks a repository whose checks fail. The repository also runs
CodeQL, OpenSSF Scorecard, and a tag release workflow that packages source with
a checksum and GitHub provenance attestation.

## Project trust

Read [SECURITY.md](SECURITY.md) before using this in repositories you do not
trust. `prove-it` executes the repository-owned `verify.sh`; it is a guardrail,
not a sandbox.

Release steps live in [RELEASE.md](RELEASE.md), including the checklist for
verification, workflow status, checksums, and provenance attestation. Support
boundaries live in [SUPPORT.md](SUPPORT.md).

## Contributing

Issues and pull requests are welcome. Changes to the convention belong in an
issue rather than a pull request against the reference implementation. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT.
