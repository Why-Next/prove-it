---
description: Scaffold a verify.sh for this repo, run it, and prove the gate works by watching it fail once.
argument-hint: "[optional: notes on what this repo considers proven]"
---

# /prove-it:init

Give this repository a `verify.sh`. Writing the file is the easy part. The work
is answering the question the file asks: what would have to be true for a change
here to be provably safe to hand back?

## Arguments

$ARGUMENTS

## Do this, in order

**1. Run the scaffolder.** It lives in the plugin directory:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/prove-it" init
```

It detects the stack, writes a `verify.sh` whose only active check is
`git diff --check`, runs it so the user sees it pass, then runs a copy with
`exit 1` appended so the user sees it fail. If `verify.sh` already exists it
refuses and leaves it alone.

Show the user its real output. Do not paraphrase it.

**2. Explain what it wrote.** The generated file has one active check and a list
of commented-out suggestions for the detected stack. It passes today by design.
A gate that fails on `main` the day it lands teaches people to bypass it in the
first week.

**3. Switch on one check at a time.** Read the commented lines. For each one, run
the command yourself and show the user the result. Uncomment only the checks that
pass right now. If `npm test` fails on their clean checkout, that is a fact worth
knowing, and it is not something to hide behind a comment character.

Keep the whole script under a minute. Slow checks belong in CI.

**4. Name what is not proven.** Finish with one sentence saying what this
`verify.sh` does not check. That sentence is the honest boundary of their gate,
and they should hear it before they start trusting it.

## Do not

- Do not uncomment a check without running it first.
- Do not add checks that need the network.
- Do not claim the gate is now active without saying that it only fires when the
  plugin is installed and the session has edited files in this repository.
  `bash "${CLAUDE_PLUGIN_ROOT}/bin/prove-it" doctor` answers that question for
  real, and you should run it if the user seems unsure.
