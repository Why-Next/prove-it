---
description: Scaffold a verify.sh for this repo, run it, and prove the gate works by watching it fail once.
argument-hint: "[optional: node | python | go | flutter - otherwise detected]"
---

# /prove-it:init

Give this repository a `verify.sh`. The point is not to write the file, it is to
answer the question the file asks: **what would have to be true for a change here
to be provably safe to hand back?**

## Arguments

$ARGUMENTS

## Do this, in order

**1. Refuse to overwrite.** If `verify.sh` already exists at the repo root, stop.
Show it to the user and ask whether they want to extend it instead. Never
silently replace a gate someone wrote.

**2. Detect the stack** unless the user named one. Look for `package.json`,
`pyproject.toml` or `requirements.txt`, `go.mod`, `pubspec.yaml`. If several
match, ask rather than guess. If none match, write the minimal version in step 3
and say so.

**3. Start smaller than feels right.** Write a `verify.sh` with *one* check:

```bash
#!/bin/bash
set -eu
cd "$(dirname "$0")"

git diff --check

echo "verify.sh OK"
```

`chmod +x verify.sh`. Do not paste an entire recipe on the first pass. A slow or
flaky gate gets bypassed within a week, and a bypassed gate is worse than none
because it says a check happened when it did not.

**4. Run it yourself.** `./verify.sh`. Show the user the real output. Never ship
a check you have not seen pass.

**5. Now watch it fail.** Temporarily append `exit 1` to `verify.sh`, run it
again, show the user the non-zero exit, then remove the `exit 1`. Do not skip
this. A user who has never seen the gate refuse a turn will not believe it works,
and will not trust it later when it refuses one for a real reason.

**6. Add checks one at a time.** Read the matching file in `recipes/` from the
prove-it plugin directory for this stack. For each check, ask the user whether
their repo actually passes it today. Add only the ones they say yes to. A
`verify.sh` that fails on `main` teaches people to bypass it on day one.

Aim for under a minute of runtime. Slow checks belong in CI.

**7. Say what is not proven.** Finish by telling the user, in one sentence, what
their `verify.sh` does *not* check. That sentence is the honest boundary of their
gate, and they should know it before they trust it.

## Do not

- Do not add checks the repo currently fails.
- Do not add network-dependent checks.
- Do not claim the gate is installed. It runs on the plugin's `Stop` hook; if the
  user has not installed the plugin, say so and point them at the README.
