#!/usr/bin/env python3
"""Fail if an embedded python block contains a character the shell would eat.

The hooks pass python source to `python3 -c "..."` inside a double-quoted shell
string. A double quote in that source closes the string early. The python then
never runs, the surrounding `2>/dev/null || true` swallows the error, and the
feature silently does nothing. That has happened once, to the ledger, and the
only reason it did not ship is that a test asserted the ledger file exists.

Backticks and `$(` would be worse: the shell would execute them.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHELL_FILES = sorted((ROOT / "hooks").glob("*.sh")) + [ROOT / "bin" / "prove-it"]

# python3 -c "  ...  " up to the closing quote that is followed by a newline or
# an argument. Non-greedy, so it stops at the first unescaped closing quote.
BLOCK = re.compile(r'python3 -c "(.*?)"\s', re.S)

DANGEROUS = {
    '"': "a double quote ends the shell string early",
    "`": "a backtick makes the shell execute the contents",
}


def main() -> int:
    problems = 0
    for path in SHELL_FILES:
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")

        for match in BLOCK.finditer(text):
            body = match.group(1)
            start_line = text[: match.start()].count("\n") + 1
            for offset, ch in enumerate(body):
                if ch in DANGEROUS:
                    line = start_line + body[:offset].count("\n")
                    rel = path.relative_to(ROOT)
                    print(f"{rel}:{line}: {DANGEROUS[ch]}")
                    problems += 1
            if "$(" in body:
                rel = path.relative_to(ROOT)
                print(f"{rel}:{start_line}: $( makes the shell run a subshell")
                problems += 1

    # A python -c block that is not double quoted at all is fine, but a heredoc
    # would be safer still. Say so once rather than failing on it.
    if problems:
        print(f"\ncheck_embedded_python: {problems} problem(s). Use single "
              f"quotes inside the block, or switch to a heredoc.", file=sys.stderr)
        return 1

    print("check_embedded_python: embedded python survives the shell")
    return 0


if __name__ == "__main__":
    sys.exit(main())
