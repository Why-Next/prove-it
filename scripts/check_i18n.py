#!/usr/bin/env python3
"""Hold every translated README to the English one.

Translations rot silently: a heading disappears, a shell command picks up a
smart quote, a link keeps pointing at the repo root from a subdirectory. None
of that shows up in review because nobody on the team reads all eleven files.

Checks, per locale:
  - the file exists
  - heading count and code fence count match the English original
  - the headings are actually translated, not left in English
  - accented languages kept their accents, and did not fake them with '
  - code block contents are byte-identical to the English original
  - every relative link resolves to a real file
  - the language bar does not link to the page it is on
"""

from __future__ import annotations

import os
import pathlib
import re
import sys

# GDP order, then Korean. The canonical text is English.
LOCALES = ["zh", "de", "ja", "hi", "fr", "it", "pt", "ru", "es", "ko"]

# Locales whose prose cannot be written correctly without diacritics. A
# translator told to avoid one punctuation mark tends to over-apply the rule and
# strip these too, turning "décidé" into "decide" and "è" into "e'". The floor is
# well under what a real translation of this README produces (de 56, es 97).
ACCENTED = {"de", "fr", "it", "pt", "es"}
ACCENT_FLOOR = 25
ACCENT_CHARS = re.compile(
    r"[àâäáãéèêëíìîïóòôöõúùûüñçßÀÂÄÁÃÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÑÇ]")
# "cio'", "puo'", "e'" - an apostrophe standing in for a grave accent.
FAKE_ACCENT = re.compile(r"[a-z]'(?=[\s.,;:)\]]|$)", re.M)

ROOT = pathlib.Path(__file__).resolve().parent.parent
CANONICAL = ROOT / "README.md"
I18N = ROOT / "docs" / "i18n"

FENCE = re.compile(r"^```[a-z]*\n(.*?)^```", re.S | re.M)
HEADING = re.compile(r"^#{1,6}\s+(.*)$", re.M)
LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")


def code_blocks(text: str) -> list[str]:
    return FENCE.findall(text)


def headings(text: str) -> list[str]:
    """Headings outside code blocks. A `#!/bin/bash` shebang is not a heading."""
    return HEADING.findall(FENCE.sub("", text))


def check(locale: str, canon: str, errors: list[str]) -> None:
    path = I18N / f"README.{locale}.md"
    if not path.is_file():
        errors.append(f"{locale}: missing {path.relative_to(ROOT)}")
        return

    text = path.read_text(encoding="utf-8")
    rel = path.relative_to(ROOT)

    want_headings, got_headings = headings(canon), headings(text)
    if len(want_headings) != len(got_headings):
        errors.append(
            f"{rel}: {len(got_headings)} headings, English has {len(want_headings)}")
    else:
        # The project name stays; the section titles must not. Comparing whole
        # lists rather than each heading keeps a term that is the same word in
        # both languages from tripping this.
        sections_want, sections_got = want_headings[1:], got_headings[1:]
        if sections_want and sections_want == sections_got:
            errors.append(f"{rel}: section headings are still in English")

    want_blocks, got_blocks = code_blocks(canon), code_blocks(text)
    if len(want_blocks) != len(got_blocks):
        errors.append(
            f"{rel}: {len(got_blocks)} code blocks, English has {len(want_blocks)}")
    else:
        for i, (want, got) in enumerate(zip(want_blocks, got_blocks), 1):
            if want != got:
                errors.append(
                    f"{rel}: code block {i} was altered. Commands must be "
                    f"byte-identical to the English original.")

    if locale in ACCENTED:
        prose = FENCE.sub("", text)
        accents = len(ACCENT_CHARS.findall(prose))
        if accents < ACCENT_FLOOR:
            errors.append(
                f"{rel}: only {accents} accented characters. The accents were "
                f"stripped. Only long dashes are banned, not diacritics.")
        fakes = len(FAKE_ACCENT.findall(prose))
        if fakes > 5:
            errors.append(
                f"{rel}: {fakes} apostrophes standing in for accents "
                f"(e' instead of è). Write the accented letter.")

    for _, target in LINK.findall(text):
        if target.startswith(("http://", "https://", "#", "mailto:")):
            continue
        resolved = pathlib.Path(os.path.normpath(path.parent / target))
        if not resolved.exists():
            errors.append(f"{rel}: broken link -> {target}")

    if f"](README.{locale}.md)" in text:
        errors.append(f"{rel}: language bar links to itself")


def main() -> int:
    if not CANONICAL.is_file():
        print("check_i18n: README.md not found", file=sys.stderr)
        return 1

    canon = CANONICAL.read_text(encoding="utf-8")
    errors: list[str] = []
    for locale in LOCALES:
        check(locale, canon, errors)

    # The English README must offer every translation, or they are unreachable.
    for locale in LOCALES:
        if f"docs/i18n/README.{locale}.md" not in canon:
            errors.append(f"README.md: language bar is missing {locale}")

    if errors:
        for err in errors:
            print(f"  {err}")
        print(f"\ncheck_i18n: {len(errors)} problem(s).", file=sys.stderr)
        return 1

    print(f"check_i18n: {len(LOCALES)} locales match README.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
