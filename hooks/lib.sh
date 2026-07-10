#!/bin/bash
# Shared helpers for the prove-it hooks. Sourced, never run.
#
# Embedded python always arrives through a quoted heredoc, never through
# `python3 -c "..."`. A double quote inside a double-quoted shell string ends
# that string, the error goes to /dev/null, and the feature quietly stops
# working. That happened once, to the ledger. scripts/check_embedded_python.py
# fails the build if anyone reintroduces the `-c` form.

# shellcheck shell=bash

pi_state_dir() {
    printf '%s' "${PROVE_IT_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/prove-it}"
}

# A stable, filesystem-safe name for a repository. Two repositories with the
# same checksum would share state, which is why the byte count is appended.
pi_repo_key() {
    printf '%s' "$1" | cksum | tr -s ' ' '-'
}

# Three lines on stdout: stop_hook_active (0 or 1), session id, transcript path.
# The session id becomes part of a filename, so it is reduced to a safe
# component first. A payload that is not an object yields the defaults.
pi_stop_fields() {
    PI_INPUT="$1" python3 2>/dev/null <<'PY'
import json, os

raw = os.environ.get("PI_INPUT") or ""
try:
    payload = json.loads(raw)
except ValueError:
    payload = {}
if not isinstance(payload, dict):
    payload = {}

print(1 if payload.get("stop_hook_active") else 0)

session = str(payload.get("session_id") or "unknown")
safe = "".join(c if (c.isalnum() or c in "-_") else "_" for c in session)[:64]
print(safe or "unknown")

print(str(payload.get("transcript_path") or "").replace("\n", " "))
PY
}

# A checksum of the working tree facts this gate is responsible for tracking:
# the commit, the index, the diff against it, and each untracked file's path,
# mode, and contents. Untracked files never appear in `git diff HEAD`, so they
# are hashed here directly. Nothing is truncated: a cap here would mean a change
# past the cap does not re-run the gate, and this hook is on the path of every
# single turn, so a silent cap would be invisible forever.
#
# The untracked files are hashed by one python process rather than one cksum per
# file. A repository with a few thousand untracked files turned that loop into
# several seconds of process spawning on every stop.
pi_tree_state() {
    local root=$1
    {
        git -C "$root" rev-parse HEAD 2>/dev/null
        git -C "$root" status --porcelain 2>/dev/null
        git -C "$root" diff HEAD 2>/dev/null
        PI_ROOT="$root" python3 2>/dev/null <<'PY'
import hashlib, os, stat, subprocess

root = os.environ["PI_ROOT"]
listing = subprocess.run(
    ["git", "-C", root, "ls-files", "--others", "--exclude-standard", "-z"],
    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
).stdout

digest = hashlib.sha256()
for name in sorted(n for n in listing.split(b"\0") if n):
    path = os.path.join(os.fsencode(root), name)
    digest.update(name + b"\0")
    try:
        info = os.lstat(path)
    except OSError:
        digest.update(b"<missing>\0")
        continue

    mode = stat.S_IFMT(info.st_mode) | stat.S_IMODE(info.st_mode)
    digest.update(("%o" % mode).encode())
    digest.update(b"\0")

    if stat.S_ISLNK(info.st_mode):
        try:
            target = os.readlink(path)
            if isinstance(target, str):
                target = os.fsencode(target)
            digest.update(b"symlink\0" + target)
        except OSError:
            digest.update(b"<unreadable-symlink>")
    elif stat.S_ISREG(info.st_mode):
        try:
            with open(path, "rb") as fh:
                for chunk in iter(lambda: fh.read(1 << 16), b""):
                    digest.update(chunk)
        except OSError:
            digest.update(b"<unreadable>")
    else:
        digest.update(b"<non-regular>")
    digest.update(b"\0")

print(digest.hexdigest())
PY
    } | cksum | tr -s ' ' '-'
}

# Whether the gate is armed in this repository right now.
pi_verify_state() {
    if [ -x "$1/verify.sh" ]; then printf 'armed'; else printf 'unarmed'; fi
}

# Content hash of the gate itself. The disarm check catches a verify.sh that
# was deleted or chmod -x'd mid-session; this catches the subtler move of
# keeping it executable and rewriting the checks inside it.
pi_gate_hash() {
    cksum < "$1/verify.sh" 2>/dev/null | tr -s ' ' '-'
}

# How many times the gate may block one stretch of work before it gives up and
# says so. Zero means never block, which is a warning-only mode.
pi_max_blocks() {
    local max=${PROVE_IT_MAX_BLOCKS:-3}
    case $max in
        '' | *[!0-9]*) max=3 ;;
    esac
    printf '%s' "$max"
}
