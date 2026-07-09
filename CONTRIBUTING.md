# Contributing

## Where a change belongs

This repository holds two things of different weight.

[SPEC.md](SPEC.md) describes a convention that other tools should be able to
implement without reading a line of this code. Changes to it start as an issue,
so that the discussion happens before anyone writes a patch. A pull request that
quietly widens the contract is harder to argue with than a proposal that says
plainly what it wants to change.

`hooks/prove-it.sh` is one implementation of that convention, seventy-odd lines
of it, and pull requests against it need no ceremony.

If you are unsure which of the two you are touching, open an issue and ask.

## The gate applies to you too

This repository has a `verify.sh`. Run it before you open a pull request:

```bash
./verify.sh
```

It checks shell syntax, runs shellcheck, validates the plugin manifests, enforces
the prose rules below, holds the translations to the English originals, and runs
the gate's own test suite against real git repositories in a temporary directory.
CI runs the same script on Linux and macOS, plus a separate job proving the gate
still blocks a repository whose checks fail.

If `verify.sh` fails, fix the cause. Do not weaken `verify.sh`. That is the one
change this project will not merge, for the reason the project exists.

## Adding a check

A new check is welcome when it would have caught a real bug. Break something on
purpose, watch your check notice, then fix it and commit both. A check nobody has
watched fail is not a check.

Two of the scripts under `scripts/` exist because their first versions passed
against a codebase that was already broken.

## Translations

`README.md` and `SPEC.md` are canonical, and the English text of `SPEC.md`
governs where a translation disagrees with it. `scripts/check_i18n.py` holds
every translation to its original: heading counts, whether the headings were
translated at all, whether the accents survived, whether code blocks are
byte-identical to the English, and whether relative links resolve.

Two rules trip people up.

Never use a long dash. No em dash, en dash, horizontal bar, or minus sign. Plain
ASCII hyphen only, in every language, including the ones whose typography prefers
otherwise, because a long dash reads as machine-written text. (This paragraph
names the characters rather than showing them, since
`scripts/check_no_long_dash.py` reads this file too.)

Always keep the accents. The dash rule covers six specific characters and is not
a ban on non-ASCII. `décidé` stays `décidé`, and `è` never becomes `e'`. An early
translation stripped every accent in the file by over-applying the first rule.

## Recipes

A recipe is a starting point for one stack rather than a finished `verify.sh`.
Keep it under a minute of runtime, prefer checks that produce evidence over
checks that produce opinions, and note which of the spec's four kinds of evidence
each check delivers.

## Commits

Conventional commits (`feat:`, `fix:`, `docs:`, `chore:`). Say in the body what
changed and why. If you fixed a bug, say how you reproduced it.

## Releases

Maintainers follow [RELEASE.md](RELEASE.md). A release needs a clean local
`./verify.sh`, green `verify`, `codeql`, and `scorecard` workflows on `main`,
and the tag workflow's checksum plus provenance attestation. Do not publish from
an unverified tree.
