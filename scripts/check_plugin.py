#!/usr/bin/env python3
"""Validate the Claude Code plugin manifests, and then some.

`claude plugin validate` checks the shape of the JSON. It does not check that a
marketplace entry's `source` directory exists, or that the commands a hook fires
are real files on disk. Both of those fail at install time on someone else's
machine, which is the worst place to find out. So this checks them here.

Runs `claude plugin validate` too when the CLI is on PATH, and says so when it
is not rather than passing quietly.
"""

from __future__ import annotations

import json
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MARKETPLACE = ROOT / ".claude-plugin" / "marketplace.json"
PLUGIN = ROOT / ".claude-plugin" / "plugin.json"
HOOKS = ROOT / "hooks" / "hooks.json"

# The token Claude Code substitutes for the installed plugin's directory.
PLUGIN_ROOT = re.compile(r'\$\{CLAUDE_PLUGIN_ROOT\}')


def load(path: pathlib.Path, errors: list[str]) -> dict | None:
    if not path.is_file():
        errors.append(f"missing {path.relative_to(ROOT)}")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"{path.relative_to(ROOT)}: invalid JSON: {exc}")
        return None


def check_marketplace(errors: list[str]) -> None:
    data = load(MARKETPLACE, errors)
    if not data:
        return
    entries = data.get("plugins", [])
    if not entries:
        errors.append("marketplace.json lists no plugins")
    for entry in entries:
        source = entry.get("source")
        if not source:
            errors.append(f"marketplace entry {entry.get('name')} has no source")
            continue
        # The official validator accepts a source that points nowhere.
        target = (ROOT / source).resolve()
        if not target.is_dir():
            errors.append(f"marketplace source does not exist: {source}")
        elif not (target / ".claude-plugin" / "plugin.json").is_file():
            errors.append(f"marketplace source has no plugin.json: {source}")


def check_hooks(errors: list[str]) -> None:
    data = load(HOOKS, errors)
    if not data:
        return
    events = data.get("hooks", {})
    required = {"Stop", "PostToolUse", "SessionStart"}
    missing = required - set(events)
    if missing:
        errors.append(f"hooks.json does not register {sorted(missing)}")

    # Every command a hook fires has to exist, with ${CLAUDE_PLUGIN_ROOT} standing
    # in for this repo.
    for event, groups in events.items():
        for group in groups:
            for hook in group.get("hooks", []):
                command = hook.get("command", "")
                for raw in re.findall(r'"?\$\{CLAUDE_PLUGIN_ROOT\}"?(/[\w./-]+)', command):
                    script = ROOT / raw.lstrip("/")
                    if not script.is_file():
                        errors.append(f"{event} hook points at a missing file: {raw}")
                    elif not script.stat().st_mode & 0o111:
                        errors.append(f"{event} hook target is not executable: {raw}")
                if "${CLAUDE_PLUGIN_ROOT}" not in command:
                    errors.append(
                        f"{event} hook command must use ${{CLAUDE_PLUGIN_ROOT}}, "
                        f"not a path relative to the user's cwd: {command}")


def check_cli(errors: list[str]) -> None:
    """The install flow runs through bin/prove-it, so it has to be there."""
    cli = ROOT / "bin" / "prove-it"
    if not cli.is_file():
        errors.append("bin/prove-it is missing")
        return
    if not cli.stat().st_mode & 0o111:
        errors.append("bin/prove-it is not executable")

    text = cli.read_text(encoding="utf-8")
    for sub in ("init", "doctor", "ledger"):
        if f"cmd_{sub}" not in text:
            errors.append(f"bin/prove-it has no {sub} subcommand")

    # /prove-it:init shells out to the CLI. A rename would strand the command.
    init = (ROOT / "commands" / "init.md").read_text(encoding="utf-8")
    if "bin/prove-it" not in init:
        errors.append("commands/init.md no longer calls bin/prove-it")


def check_commands(errors: list[str]) -> None:
    """Slash commands are discovered by filename, so a typo is a silent no-op."""
    commands = ROOT / "commands"
    if not commands.is_dir():
        errors.append("commands/ is missing")
        return

    found = sorted(p.name for p in commands.glob("*.md"))
    expected = ["init.md", "ledger.md"]
    if found != expected:
        errors.append(f"commands/ holds {found}, expected {expected}")

    for path in commands.glob("*.md"):
        text = path.read_text(encoding="utf-8")
        if not text.startswith("---\n"):
            errors.append(f"commands/{path.name}: no YAML frontmatter")
            continue
        front = text.split("---\n", 2)[1]
        if "description:" not in front:
            errors.append(f"commands/{path.name}: frontmatter has no description")
        # The README advertises these names; a rename breaks the docs silently.
        if f"/prove-it:{path.stem}" not in text:
            errors.append(
                f"commands/{path.name}: body never names /prove-it:{path.stem}")

    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for path in commands.glob("*.md"):
        if f"/prove-it:{path.stem}" not in readme:
            errors.append(f"README.md never mentions /prove-it:{path.stem}")


def check_versions(errors: list[str]) -> None:
    plugin = load(PLUGIN, errors)
    if not plugin:
        return
    version = plugin.get("version", "")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        errors.append(f"plugin.json version is not semver: {version!r}")

    changelog = ROOT / "CHANGELOG.md"
    if changelog.is_file():
        text = changelog.read_text(encoding="utf-8")
        if f"[{version}]" not in text and f"## {version}" not in text:
            errors.append(f"CHANGELOG.md has no entry for version {version}")


def run_official_validator(errors: list[str]) -> None:
    if not shutil.which("claude"):
        print("check_plugin: claude CLI not installed, skipping official validate")
        return
    result = subprocess.run(
        ["claude", "plugin", "validate", str(ROOT)],
        capture_output=True, text=True, timeout=60,
    )
    if result.returncode != 0:
        errors.append("claude plugin validate failed:\n" + (result.stdout or result.stderr).strip())


def main() -> int:
    errors: list[str] = []
    check_marketplace(errors)
    check_hooks(errors)
    check_cli(errors)
    check_commands(errors)
    check_versions(errors)
    run_official_validator(errors)

    if errors:
        for err in errors:
            print(f"  {err}")
        print(f"\ncheck_plugin: {len(errors)} problem(s).", file=sys.stderr)
        return 1
    print("check_plugin: manifests valid, hook targets exist")
    return 0


if __name__ == "__main__":
    sys.exit(main())
