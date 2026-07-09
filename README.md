# prove-it

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

**Your agent cannot end its turn until your repo proves itself.**

Coding agents say "tests pass" without running them, and "fixed" without ever
reproducing the bug. Not out of malice: an agent cannot tell what it did from
what it meant to do, so it reports the intention.

`prove-it` makes *done* something an agent has to pass, not something it gets to
say. Put a `verify.sh` at your repo root. When the agent tries to stop, the gate
runs it. Non-zero exit, and the turn does not end.

```
agent: "All tests pass. Ready to merge."
       └─ tries to end turn
          └─ prove-it runs ./verify.sh
             └─ exit 1:  FAIL src/auth.test.ts  (3 failed, 41 passed)
                └─ turn blocked, agent keeps working

agent: "Actually, three tests were failing. Fixing."
```

Roughly half the time, an agent asked for evidence answers "you're right, it
isn't done yet."

## Install

Requires `bash`, `git`, `python3`. No packages, no daemon, nothing to sign up
for. Clone it anywhere:

```bash
git clone https://github.com/YOUR_ORG/prove-it ~/.local/share/prove-it
```

Wire the two hooks into Claude Code by merging
[`hooks/settings.example.json`](hooks/settings.example.json) into your
`.claude/settings.json` (per repo) or `~/.claude/settings.json` (everywhere).

Then write the only file that matters:

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

That is the whole setup. There is no `verify.sh` in your repo yet, so until you
write one, the gate does nothing at all.

## Your first five minutes

Start smaller than you think. A `verify.sh` that only runs `git diff --check`
is already worth having, and it will pass, which teaches you the gate is quiet
when things are fine.

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first. Never ship a check you have not seen pass.
```

Now watch it fail on purpose, so you know the gate is real:

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

Ask your agent to edit any file, then let it finish. It will try to end its
turn, the gate will run `verify.sh`, and the turn will be blocked. Undo the
`exit 1` and the same agent sails through.

From there, add one real check at a time: the test command you actually run,
then the type checker, then the diff hygiene. Every check you add is a sentence
in your answer to *what does proven mean here*. Stop when the whole thing takes
about a minute.

The mistake to avoid is writing an ambitious `verify.sh` on day one. A slow or
flaky gate gets bypassed within a week, and a bypassed gate is worse than none:
it tells you a check happened when it did not.

## How it decides to run

The gate is quiet by default. It runs `verify.sh` only when every one of these
is true:

- the session actually edited files (a read-only session has nothing to prove)
- an executable `verify.sh` exists at the repo root
- the working tree has uncommitted changes
- this exact tree state has not already passed

That last one means a passing tree is verified once, not on every stop. Failures
print the last 20 lines of output to the agent, which is usually enough for it
to fix the cause without being told.

To get past the gate on purpose: `PROVE_IT_SKIP=1`. To turn it off for good:
delete `verify.sh`. Both are deliberate. A gate nobody can remove is a gate
people route around.

## Opting out is the feature

The hardest failure mode is not a flaky check. It is an agent that cannot pass
`verify.sh` and quietly edits `verify.sh` instead. The gate's failure message
says so in as many words, and the spec makes it a stated violation. Watch for it
in your diffs anyway. That is what the diff evidence is for.

## The `verify.sh` convention

The script in `hooks/` is small on purpose. The real artifact is the convention
it implements, written down in **[SPEC.md](SPEC.md)**: a repository declares how
it proves itself, in a known place, with a known contract, and an agent may not
claim completion until that proof passes.

Read the spec for the four kinds of evidence a `verify.sh` should assert
against - command output, diff, reproduction, cross-check - and for the
conformance levels.

**One honest note up front.** This tool enforces exactly one thing: that
`verify.sh` returned zero before the turn ended. Whether that zero *means*
anything depends entirely on the checks you wrote. A `verify.sh` containing only
`exit 0` will pass this gate and prove nothing. The tool is Level 1. The
evidence is Level 2, and Level 2 is a practice, not a feature.

## Recipes

Starting points per stack, in [`recipes/`](recipes/). Copy one to `verify.sh`
and cut what does not apply. Keep it under a minute; slow checks belong in CI.

| | |
|---|---|
| [`node.sh`](recipes/node.sh) | tests, typecheck, lint, diff hygiene |
| [`python.sh`](recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](recipes/flutter.sh) | analyze, test, format check |

The hard part of adopting this is never wiring the hook. It is answering "what
does *proven* mean in this repo" for the first time.

## The ledger

Set `PROVE_IT_LEDGER=1` and every caught false completion appends one line to
`~/.prove-it/ledger.jsonl`:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

What was claimed, what was demanded, what was true. Local disk only, never
transmitted, off unless you turn it on. After a month you stop guessing about
how your agent fails and start reading it.

## This repo gates itself

`prove-it` has a `verify.sh`, and it runs the gate against real git repos in a
temp directory: failing check blocks, passing check allows, read-only session is
untouched, clean tree is skipped, bypass works.

```bash
./verify.sh
```

It would be an odd thing to ship otherwise.

## License

MIT.
