#!/usr/bin/env python3
"""Fail if embedded python can be eaten by the shell before python sees it.

The old rule tried to be clever. It matched `python3 -c "..."` and looked for a
double quote inside the body. A double quote inside the body is exactly what
ends the body, so the regex stopped there and reported the file clean while the
shell had already torn the script in half. The check could not detect the one
bug it was written to detect, and no repair to that regex is worth trusting,
because the thing being parsed is shell quoting.

So the shape is banned rather than inspected. Embedded python arrives through a
heredoc with a quoted delimiter:

    python3 <<'PY'
    ...
    PY

Inside a quoted heredoc the shell performs no expansion at all: no `$`, no
backtick, no quote handling. Nothing is left to get wrong. Arguments go in as
argv or as environment variables, both of which the shell quotes properly.

Two rules, and a file either follows them or it does not:

  1. no `python -c` / `python3 -c` anywhere
  2. every python heredoc delimiter is quoted (`<<'PY'`, not `<<PY`)
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHELL_FILES = (
    sorted((ROOT / "hooks").glob("*.sh"))
    + sorted((ROOT / "tests").glob("*.sh"))
    + sorted((ROOT / "recipes").glob("*.sh"))
    + [ROOT / "bin" / "prove-it", ROOT / "verify.sh"]
)

DASH_C = re.compile(r"\bpython3?\s+-c\b")
PYTHON = re.compile(r"\bpython3?\b")

# Every heredoc delimiter on the line, however the line is otherwise composed.
# An unquoted delimiter means the shell expands $VAR, `cmd`, and $(cmd) inside
# the body before python is handed it.
HEREDOC = re.compile(r"<<-?\s*(\S+)")
QUOTED = ("'", '"', "\\")


def main() -> int:
    problems: list[str] = []

    for path in SHELL_FILES:
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT)

        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue  # a comment may name the thing it forbids

            if DASH_C.search(line):
                problems.append(
                    f"{rel}:{lineno}: python -c lets the shell parse the source "
                    f"before python does. Use a heredoc: python3 <<'PY'")

            if not PYTHON.search(line):
                continue
            for delimiter in HEREDOC.findall(line):
                if not delimiter.startswith(QUOTED):
                    problems.append(
                        f"{rel}:{lineno}: heredoc delimiter {delimiter} is not "
                        f"quoted, so the shell expands the python source. "
                        f"Write <<'{delimiter}'")

    if problems:
        for problem in problems:
            print(f"  {problem}")
        print(f"\ncheck_embedded_python: {len(problems)} problem(s).", file=sys.stderr)
        return 1

    print("check_embedded_python: embedded python reaches python unmodified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
