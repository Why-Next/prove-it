#!/usr/bin/env python3
"""Check the repository's GitHub automation security posture.

This is intentionally text-based instead of a full YAML validator. The checks
are about policies that should be visible in review:

- every workflow declares least-privilege permissions
- every job has a timeout
- remote actions are pinned to a full commit SHA
- checkout does not leave a write token in the working tree
- supply-chain workflows and ownership files exist
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WORKFLOWS = ROOT / ".github" / "workflows"

REQUIRED_WORKFLOWS = {
    "verify.yml",
    "scorecard.yml",
    "codeql.yml",
    "release.yml",
}

REMOTE_ACTION = re.compile(
    r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)?@[0-9a-f]{40}$"
)
USES_LINE = re.compile(r"^(?P<indent>\s*)(?:-\s+)?uses:\s*(?P<value>\S+)")
STEP_LINE = re.compile(r"^(?P<indent>\s*)-\s+")
JOB_LINE = re.compile(r"^  (?P<name>[A-Za-z0-9_-]+):\s*$")


def strip_comment(value: str) -> str:
    return value.split("#", 1)[0].strip().strip("'\"")


def workflow_files() -> list[pathlib.Path]:
    if not WORKFLOWS.is_dir():
        return []
    return sorted(p for p in WORKFLOWS.iterdir() if p.suffix in {".yml", ".yaml"})


def require_files(errors: list[str]) -> None:
    found = {p.name for p in workflow_files()}
    missing = sorted(REQUIRED_WORKFLOWS - found)
    if missing:
        errors.append(f".github/workflows missing required file(s): {missing}")

    for rel in (".github/dependabot.yml", ".github/CODEOWNERS"):
        if not (ROOT / rel).is_file():
            errors.append(f"missing {rel}")


def job_blocks(lines: list[str]) -> dict[str, list[str]]:
    jobs: dict[str, list[str]] = {}
    in_jobs = False
    current: str | None = None
    for line in lines:
        if line.startswith("jobs:"):
            in_jobs = True
            current = None
            continue
        if in_jobs and line and not line.startswith((" ", "#")):
            break
        if not in_jobs:
            continue

        match = JOB_LINE.match(line)
        if match:
            current = match.group("name")
            jobs[current] = [line]
        elif current:
            jobs[current].append(line)
    return jobs


def step_blocks(lines: list[str]) -> list[tuple[int, int, list[str]]]:
    """Return YAML list item blocks.

    A GitHub Actions step can be written as `- uses: ...` or as `- name: ...`
    followed by a nested `uses:` key. The latter is the common form, and it is
    exactly the form most likely to hide an unpinned action if this checker only
    looks at the first line.
    """
    blocks: list[tuple[int, int, list[str]]] = []
    starts: list[tuple[int, str]] = []
    for i, line in enumerate(lines):
        match = STEP_LINE.match(line)
        if match:
            starts.append((i, match.group("indent")))

    for pos, (start, indent) in enumerate(starts):
        end = len(lines)
        next_step = re.compile(rf"^{re.escape(indent)}-\s+")
        for j in range(start + 1, len(lines)):
            if next_step.match(lines[j]):
                end = j
                break
        blocks.append((start, end, lines[start:end]))
    return blocks


def block_for_line(blocks: list[tuple[int, int, list[str]]], lineno: int) -> list[str]:
    for start, end, block in blocks:
        if start <= lineno < end:
            return block
    return []


def check_workflow(path: pathlib.Path, errors: list[str]) -> None:
    rel = path.relative_to(ROOT)
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    if re.search(r"^permissions:\s*write-all\s*$", text, re.M):
        errors.append(f"{rel}: uses permissions: write-all")
    if not re.search(r"^permissions:\s*$", text, re.M):
        errors.append(f"{rel}: no top-level permissions block")
    if re.search(r"^\s*pull_request_target:\s*$", text, re.M):
        errors.append(f"{rel}: pull_request_target requires a separate review")

    jobs = job_blocks(lines)
    if not jobs:
        errors.append(f"{rel}: no jobs found")
    for job, block in jobs.items():
        if not any(re.search(r"^\s+timeout-minutes:\s*\d+\s*$", line) for line in block):
            errors.append(f"{rel}: job {job} has no timeout-minutes")

    blocks = step_blocks(lines)
    for i, line in enumerate(lines):
        match = USES_LINE.match(line)
        if not match:
            continue
        value = strip_comment(match.group("value"))
        if value.startswith("./") or value.startswith("docker://"):
            continue
        if not REMOTE_ACTION.fullmatch(value):
            errors.append(f"{rel}:{i + 1}: action is not pinned to a full SHA: {value}")
        if value.startswith("actions/checkout@"):
            block = "\n".join(block_for_line(blocks, i) or [line])
            if not re.search(r"persist-credentials:\s*false\b", block):
                errors.append(f"{rel}:{i + 1}: checkout must set persist-credentials: false")

    if path.name == "scorecard.yml" and "ossf/scorecard-action@" not in text:
        errors.append(f"{rel}: missing OpenSSF Scorecard action")
    if path.name == "codeql.yml":
        if "github/codeql-action/init@" not in text or "github/codeql-action/analyze@" not in text:
            errors.append(f"{rel}: missing CodeQL init/analyze")
    if path.name == "release.yml":
        if "actions/attest-build-provenance@" not in text:
            errors.append(f"{rel}: release package is not attested")


def main() -> int:
    errors: list[str] = []
    require_files(errors)
    for path in workflow_files():
        check_workflow(path, errors)

    if errors:
        for error in errors:
            print(f"  {error}")
        print(f"\ncheck_workflows: {len(errors)} problem(s).", file=sys.stderr)
        return 1

    print("check_workflows: workflows are pinned and least-privilege")
    return 0


if __name__ == "__main__":
    sys.exit(main())
