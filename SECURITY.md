# Security

## What this software does on your machine

`prove-it` runs a script that lives in the repository you have open. That is the
entire design, and it is worth being blunt about what it means: **if you open a
repository you do not trust, and its `verify.sh` is executable, your agent
ending a turn will execute that file.**

This is not a vulnerability, it is the feature. It is also indistinguishable
from the risk you already accept by running `npm install` or opening a project
with a `Makefile`. Treat an unfamiliar `verify.sh` the way you treat an
unfamiliar `postinstall` script: read it first.

The gate only runs when the session edited files **in that same repository**, the
working tree is dirty, and an executable `verify.sh` exists at the repo root.
Cloning and reading a repository never triggers it, and editing one repository
never causes another repository's `verify.sh` to run.

## What it writes on disk

Two markers, both in a private directory created mode `0700`:
`$XDG_STATE_HOME/prove-it/`, or `~/.local/state/prove-it/` when that is unset.
Override with `PROVE_IT_STATE_DIR`. Nothing is written to shared `/tmp`, because
these filenames are derived from the repository path and are therefore
predictable, and a predictable name in a world-writable directory is a symlink
target.

The optional ledger (`PROVE_IT_LEDGER=1`, **off by default**) appends one JSON
line per caught false completion to `~/.prove-it/ledger.jsonl`, created mode
`0600` inside a `0700` directory. Each line holds:

- the agent's last message before it tried to stop, truncated to 300 characters
  and drawn from your local transcript, so it can contain anything that was in
  your conversation
- the absolute path of the repository
- the exit code and the last five lines of your `verify.sh` output
- a timestamp

Treat it as conversation data. Nothing in this project ever reads it back or
sends it anywhere, but it is an ordinary file: your backups will copy it, and
anyone with read access to your home directory can read it.

## What it sends

Nothing. The software that runs on your machine contains no telemetry, no
network call, and no update check. You can confirm this with a single grep for
`curl`, `wget`, `urllib`, `requests`, or `socket` across `hooks/` and
`scripts/`.

Continuous integration is the one exception, and it is not code you run: the
GitHub Actions workflow installs `shellcheck` from `apt` or `brew` before
running the same `verify.sh` you would run locally.

## Reporting a vulnerability

Email **hello@whynext.app** with the details and a reproduction. Please do not
open a public issue for anything that lets a repository escape the boundaries
described above.

Expect an acknowledgement within a few days. This is maintained by one person,
so please be patient, and please do include the reproduction: a report I cannot
reproduce is a report I cannot fix, which is the same principle the tool itself
is built on.

## Supported versions

The latest release. This project is small enough that backporting is not a
service anyone would benefit from.
