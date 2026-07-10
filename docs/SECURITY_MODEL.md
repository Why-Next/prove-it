# Security Model

`prove-it` is a local evidence gate. It makes a coding agent prove that a
repository-owned command passed before the agent can quietly hand work back.

It is not a sandbox, not a policy engine, and not a replacement for CI.

## Assets

The project protects:

- the user's attention, by refusing unsupported "done" claims
- the meaning of a repository's local verification command
- the release boundary for the hook implementation
- local privacy, by keeping gate state and ledger data on disk only

The project does not protect:

- secrets available to the agent process
- files outside the repository
- ignored files that `git` does not report
- a repository whose `verify.sh` is malicious
- a hostile agent with full write access to the same checkout

## Trust Boundaries

### User to repository

The user chooses whether to trust a repository's `verify.sh`. `prove-it` executes
that file as the current user. Read unfamiliar checks before letting an agent
work in that repository.

### Repository to hook state

Hook state is stored under `$XDG_STATE_HOME/prove-it` or
`~/.local/state/prove-it`, with private permissions. The state records checksums
and counters, not file contents.

### Local gate to CI

Local verification catches incomplete work before the agent stops. CI remains
the place for long, networked, secret-backed, or adversarial checks.

### Maintainer to release consumer

Release consumers should trust tagged releases, checksums, GitHub Actions logs,
and provenance attestations, not a maintainer's local machine.

## Threats and Controls

| Threat | Control |
| --- | --- |
| Agent says tests passed without running them | Stop hook runs `./verify.sh` before the turn ends |
| Agent commits or edits with a tool the hook did not mark | Tree-state comparison detects repository changes |
| Agent deletes or disables `verify.sh` during a session | Gate blocks deletion and executable-bit removal |
| Agent hides failure by repeating stops | Per-turn block budget yields with a warning, not a success |
| State-file path injection | Session identifiers are reduced before use in filenames |
| Symlink attack through shared temp paths | State is not written under shared `/tmp` |
| Release artifact cannot be tied to CI | Release workflow builds from tag and creates GitHub provenance |

## Residual Risk

An agent that can edit the repository can also edit the checks in `verify.sh`.
The gate detects crude disarming, but it cannot prove the checks are still
meaningful. Review diffs to `verify.sh`, `hooks/`, and workflows with extra
care.

An ignored file change may not change the tree state. If a proof depends on
ignored files, make `verify.sh` inspect them directly.

The gate yields after a configurable number of refusals to avoid hanging the
session. A yielded turn is unverified and should be treated that way.

## Security Review Checklist

Use this checklist for changes to hooks, workflows, release automation, or
`SPEC.md`:

- Does the change preserve the rule that `verify.sh` owns the proof?
- Does it add a negative test that watched the gate fail?
- Does it keep local state private and path-safe?
- Does it avoid new runtime dependencies?
- Does it avoid widening GitHub Actions permissions outside the job that needs
  them?
- Does it keep the release artifact tied to a tag, checksum, and provenance?
