#!/usr/bin/env python3
"""Fail if any prose file contains a long dash.

Em, en, horizontal bar, and minus all read as machine-written text and cost the
reader trust. Plain hyphen only. Translation tools reinsert these constantly,
so this runs as part of verify.sh rather than living in a style guide nobody
opens.

Code blocks are checked too: a long dash inside a shell snippet is a command
that does not run.
"""

from __future__ import annotations

import pathlib
import sys
import unicodedata

# em, en, horizontal bar, minus sign, figure dash, non-breaking hyphen
BANNED = "—–―−‒‑"

ROOTS = (
    "README.md", "SPEC.md", "CONTRIBUTING.md", "CHANGELOG.md",
    "SECURITY.md", "CODE_OF_CONDUCT.md",
    "docs", "recipes", "hooks", "scripts", "tests", ".github", ".claude-plugin",
)
SUFFIXES = {".md", ".sh", ".py", ".json", ".yml", ".yaml", ".svg"}


def files() -> list[pathlib.Path]:
    root = pathlib.Path(__file__).resolve().parent.parent
    found: list[pathlib.Path] = []
    for entry in ROOTS:
        path = root / entry
        if path.is_file():
            found.append(path)
        elif path.is_dir():
            found.extend(p for p in path.rglob("*") if p.suffix in SUFFIXES)
    return sorted(found)


def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent
    hits = 0
    for path in files():
        if path.name == pathlib.Path(__file__).name:
            continue  # this file names the characters it bans
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            for col, ch in enumerate(line, 1):
                if ch in BANNED:
                    name = unicodedata.name(ch, "?")
                    rel = path.relative_to(root)
                    print(f"{rel}:{lineno}:{col}: {name} - use a plain hyphen")
                    hits += 1

    if hits:
        print(f"\ncheck_no_long_dash: {hits} long dash(es). Replace with '-'.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
