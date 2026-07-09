# prove-it

[![verify](https://github.com/WhyNext/prove-it/actions/workflows/verify.yml/badge.svg)](https://github.com/WhyNext/prove-it/actions/workflows/verify.yml)
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
non-zero exit keeps the turn open until the cause is fixed.

![prove-it blocks an agent that claims it is done](docs/demo.svg)

In my own use, a little under half of the turns that hit a failing gate come back
with the agent conceding it was not finished. Those turns would otherwise have
ended with the word "done."

## Install

As a Claude Code plugin:

```
/plugin marketplace add WhyNext/prove-it
/plugin install prove-it@whynext
```

The plugin registers two hooks, one to mark that a session edited files and one
to gate the turn, and adds two commands: `/prove-it:init` writes your first
`verify.sh`, and `/prove-it:ledger` reads back what the gate has caught.

For any other agent, clone the repository and wire the same two hooks. They are
plain bash and need only `bash`, `git`, and `python3`:

```bash
git clone https://github.com/WhyNext/prove-it ~/.local/share/prove-it
```

Merge [`hooks/settings.example.json`](hooks/settings.example.json) into your
`.claude/settings.json` for one repository, or `~/.claude/settings.json` for all
of them. The gate reads a Stop-hook JSON payload on stdin and answers with an
exit code, so anything that can run a script at end of turn can drive it.

Then write the file that matters:

```bash
cat > verify.sh <<'EOF'
#!/bin/bash
set -eu
cd "$(dirname "$0")"

npm test
npx tsc --noEmit
git diff --check

echo "verify.sh OK"
EOF
chmod +x verify.sh
```

Until that file exists, the gate does nothing at all.

## Your first five minutes

Start smaller than you want to. A `verify.sh` that runs only `git diff --check`
is worth having, and it passes, which shows you the gate stays quiet when the
repository is in good shape.

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first
```

Now make it fail on purpose:

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

Ask the agent to edit any file and let it finish. It will try to end the turn,
the gate will run `verify.sh`, and the turn will stay open. Remove the `exit 1`
and the same agent sails through. Never ship a check you have not watched fail.

From there, add one real check at a time: the test command you actually run, then
the type checker, then the diff hygiene. Each check you add is a sentence in your
answer to the question of what "proven" means in this repository. Stop when the
whole script takes about a minute.

The common mistake is writing an ambitious `verify.sh` on the first day. A gate
that is slow or flaky gets bypassed within a week, and a bypassed gate is worse
than no gate, because it reports that a check ran when nothing did.

## How it decides to run

The gate stays quiet unless all of these hold:

- this session edited files in this repository
- an executable `verify.sh` exists at the repository root
- the working tree has uncommitted changes
- this exact tree state has not already passed

The last condition means a passing tree is verified once rather than on every
stop. When verification fails, the agent sees the last twenty lines of output,
which is usually enough for it to fix the cause without being told what went
wrong.

`PROVE_IT_SKIP=1` gets past the gate on purpose. Deleting `verify.sh` turns it
off for good. Both escape hatches are deliberate: people route around a gate they
cannot remove.

## When the agent edits the gate

The hardest failure mode is not a flaky check. It is an agent that cannot make
`verify.sh` pass and edits `verify.sh` instead. The failure message tells it not
to, and [SPEC.md](SPEC.md) calls that a violation rather than a fix, but neither
of those is enforcement. Read your diffs. That is what the diff evidence in the
spec is for.

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
`/prove-it:ledger` summarises the file for you.

## This repo gates itself

`prove-it` has a `verify.sh`, and part of what it runs is the gate itself,
against real git repositories in a temporary directory: a failing check blocks,
a passing check allows, a read-only session is left alone, a clean tree is
skipped, the bypass works.

```bash
./verify.sh
```

CI runs that same script on Linux and macOS, plus a separate job that proves the
gate still blocks a repository whose checks fail.

## Contributing

Issues and pull requests are welcome. Changes to the convention belong in an
issue rather than a pull request against the reference implementation. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT.
