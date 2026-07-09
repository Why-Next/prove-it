# Contributing

## Where a change belongs

This repository holds two things of very different weight.

**[SPEC.md](SPEC.md) is the artifact.** It describes a convention that other
tools should be able to implement without reading a line of this code. Changes
to it belong in an **issue** first, so the discussion happens before anyone
writes a patch. A pull request that quietly widens the contract is harder to
argue with than a proposal that says what it is.

**`hooks/prove-it.sh` is the footnote.** It is one implementation, 70-odd lines,
and pull requests against it are welcome without ceremony.

If you are not sure which one you are touching, ask in an issue. Nobody minds.

## The gate applies to you too

This repo has a `verify.sh`. Before you open a pull request:

```bash
./verify.sh
```

It runs shell syntax checks, shellcheck, the plugin manifest validator, the long
dash check, the translation parity check, and the gate's own test suite against
real git repositories in a temp directory. CI runs the same script on Linux and
macOS, plus a separate job proving the gate still blocks a failing repo.

If `verify.sh` fails, fix the cause. Do not weaken `verify.sh`. That is the one
change we will not merge, for the reason the whole project exists.

## Adding a check

New checks are welcome when they would have caught a real bug. A check nobody
has seen fail is not a check. Break the thing on purpose, watch your check
notice, then fix it and commit both.

That is not a slogan. Two of the checks in `scripts/` exist because their first
version passed against a codebase that was already broken.

## Translations

`README.md` is canonical. The eleven translations in `docs/i18n/` are held to it
by `scripts/check_i18n.py`, which verifies heading counts, that headings are
actually translated, that accents survived, that code blocks are byte-identical
to the English, and that relative links resolve.

Two rules that trip people up:

- **Never a long dash.** No em dash, en dash, horizontal bar, or minus sign.
  Plain ASCII hyphen only, in every language, including the ones whose typography
  prefers otherwise. A long dash reads as machine-written text. (This paragraph
  names them rather than showing them, because `scripts/check_no_long_dash.py`
  reads this file too, and it is right to.)
- **Always the accents.** The dash rule is about six specific characters. It is
  not a ban on non-ASCII. `décidé` stays `décidé`; `è` never becomes `e'`.

## Recipes

A recipe is a starting point for one stack, not a finished `verify.sh`. Keep it
under a minute of runtime, prefer checks that produce evidence over checks that
produce opinions, and comment which of the spec's four kinds of evidence each
check delivers.

## Commits

Conventional commits (`feat:`, `fix:`, `docs:`, `chore:`). Say what changed and
why in the body. If you fixed a bug, say how you reproduced it.
