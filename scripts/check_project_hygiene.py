#!/usr/bin/env python3
"""Check the non-code files that make the project operable in public."""

from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

REQUIRED = [
    "README.md",
    "SPEC.md",
    "SECURITY.md",
    "CONTRIBUTING.md",
    "CODE_OF_CONDUCT.md",
    "CHANGELOG.md",
    "RELEASE.md",
    "SUPPORT.md",
    ".github/CODEOWNERS",
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/ISSUE_TEMPLATE/bug_report.yml",
    ".github/ISSUE_TEMPLATE/spec_proposal.yml",
    ".github/dependabot.yml",
]


def main() -> int:
    errors: list[str] = []
    for rel in REQUIRED:
        path = ROOT / rel
        if not path.is_file():
            errors.append(f"missing {rel}")
        elif path.stat().st_size == 0:
            errors.append(f"{rel} is empty")

    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for rel in ("SECURITY.md", "CONTRIBUTING.md", "RELEASE.md", "SUPPORT.md"):
        if f"]({rel})" not in readme and f"`{rel}`" not in readme:
            errors.append(f"README.md does not point to {rel}")

    pr = (ROOT / ".github" / "PULL_REQUEST_TEMPLATE.md").read_text(encoding="utf-8")
    if "./verify.sh" not in pr:
        errors.append("pull request template does not ask for ./verify.sh evidence")

    if errors:
        for error in errors:
            print(f"  {error}")
        print(f"\ncheck_project_hygiene: {len(errors)} problem(s).", file=sys.stderr)
        return 1

    print("check_project_hygiene: public project files present")
    return 0


if __name__ == "__main__":
    sys.exit(main())
