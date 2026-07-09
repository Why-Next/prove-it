#!/usr/bin/env python3
"""Hold every translated document to its English original.

Translations rot quietly. A heading disappears, a shell command picks up a smart
quote, a link keeps pointing at the repository root from a subdirectory. None of
it surfaces in review, because nobody reads all fifty files.

Checks, per document and locale:
  - the file exists
  - heading and code fence counts match the English original
  - the headings were translated rather than left in English
  - accented languages kept their accents and did not fake them with '
  - code block contents are byte-identical to the English original
  - every relative link resolves to a real file
  - a language bar does not link to the page it sits on
  - SPEC translations carry the notice that the English text governs
"""

from __future__ import annotations

import os
import pathlib
import re
import sys

# GDP order, then Korean. The canonical text is English.
LOCALES = ["zh", "de", "ja", "hi", "fr", "it", "pt", "ru", "es", "ko"]

# stem -> minimum accented characters expected in an accented language.
# Short documents cannot clear the floor that a long one does.
DOCS = {
    "README": 25,
    "SPEC": 25,
    "CONTRIBUTING": 15,
    "SECURITY": 15,
    "CODE_OF_CONDUCT": 3,
}

ROOT = pathlib.Path(__file__).resolve().parent.parent
I18N = ROOT / "docs" / "i18n"

# Locales whose prose cannot be written correctly without diacritics. A
# translator told to avoid one punctuation mark tends to over-apply the rule and
# strip these too, turning "décidé" into "decide" and "è" into "e'".
ACCENTED = {"de", "fr", "it", "pt", "es"}
ACCENT_CHARS = re.compile(
    r"[àâäáãéèêëíìîïóòôöõúùûüñçßÀÂÄÁÃÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÑÇ]")
# "cio'", "puo'", "e'" - an apostrophe standing in for a grave accent.
FAKE_ACCENT = re.compile(r"[a-z]'(?=[\s.,;:)\]]|$)", re.M)

FENCE = re.compile(r"^```[a-z]*\n(.*?)^```", re.S | re.M)
HEADING = re.compile(r"^#{1,6}\s+(.*)$", re.M)
LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")

# Every SPEC translation must open with a blockquote saying the English text
# governs, and that blockquote must link to the English text. Grepping for the
# word "normative" was not enough: a file can satisfy a keyword while leaving
# the reader no way to reach the document that actually governs.
SPEC_NOTICE_LINK = "../../SPEC.md"
SPEC_NOTICE_LINES = 15


def code_blocks(text: str) -> list[str]:
    return FENCE.findall(text)


def headings(text: str) -> list[str]:
    """Headings outside code blocks. A `#!/bin/bash` shebang is not a heading."""
    return HEADING.findall(FENCE.sub("", text))


def check(stem: str, floor: int, locale: str, canon: str, errors: list[str]) -> None:
    path = I18N / f"{stem}.{locale}.md"
    if not path.is_file():
        errors.append(f"{locale}: missing docs/i18n/{stem}.{locale}.md")
        return

    text = path.read_text(encoding="utf-8")
    rel = path.relative_to(ROOT)

    want_headings, got_headings = headings(canon), headings(text)
    if len(want_headings) != len(got_headings):
        errors.append(
            f"{rel}: {len(got_headings)} headings, English has {len(want_headings)}")
    else:
        # The project name stays; the section titles must not. Comparing the
        # whole list rather than each heading keeps a term that happens to be
        # identical in both languages from tripping this.
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
        if accents < floor:
            errors.append(
                f"{rel}: only {accents} accented characters, expected at least "
                f"{floor}. The accents were stripped. Only long dashes are "
                f"banned, not diacritics.")
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

    if f"]({stem}.{locale}.md)" in text:
        errors.append(f"{rel}: language bar links to itself")

    if stem == "SPEC":
        head = text.splitlines()[:SPEC_NOTICE_LINES]
        quote = [line for line in head if line.lstrip().startswith(">")]
        if not quote:
            errors.append(
                f"{rel}: must open with a blockquote stating that the English "
                f"text governs")
        elif SPEC_NOTICE_LINK not in "\n".join(quote):
            errors.append(
                f"{rel}: the notice must link the governing text as "
                f"{SPEC_NOTICE_LINK}, so a reader can reach it")


def main() -> int:
    errors: list[str] = []

    for stem, floor in DOCS.items():
        canonical = ROOT / f"{stem}.md"
        if not canonical.is_file():
            errors.append(f"missing canonical {stem}.md")
            continue
        canon = canonical.read_text(encoding="utf-8")
        for locale in LOCALES:
            check(stem, floor, locale, canon, errors)

    # The English README must offer every translation, or they are unreachable.
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for locale in LOCALES:
        if f"docs/i18n/README.{locale}.md" not in readme:
            errors.append(f"README.md: language bar is missing {locale}")

    if errors:
        for err in errors:
            print(f"  {err}")
        print(f"\ncheck_i18n: {len(errors)} problem(s).", file=sys.stderr)
        return 1

    print(f"check_i18n: {len(DOCS)} documents x {len(LOCALES)} locales match "
          f"their English originals")
    return 0


if __name__ == "__main__":
    sys.exit(main())
