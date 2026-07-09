# Security

## What this software does on your machine

`prove-it` runs a script that lives in the repository you have open. If you open
a repository you do not trust, and its `verify.sh` is executable, your agent
ending a turn will execute that file.

That behaviour is the design rather than a defect in it, and the risk is the one
you already accept when you run `npm install` or open a project with a
`Makefile`. Read an unfamiliar `verify.sh` before you let an agent work in the
repository that contains it, the way you would read an unfamiliar `postinstall`
script.

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

Treat it as conversation data. Nothing in this project reads it back or sends it
anywhere, but it remains an ordinary file, so your backups will copy it and
anyone with read access to your home directory can open it.

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

Expect an acknowledgement within a few days. One person maintains this, so
patience helps, and so does the reproduction. A report I cannot reproduce is one
I cannot fix.

## Supported versions

The latest release. This project is small enough that backporting is not a
service anyone would benefit from.
