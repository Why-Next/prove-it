# Governance

`prove-it` is maintained as a small, conservative reference implementation of
the `verify.sh` convention.

The project optimizes for predictable behavior over feature volume. A change is
welcome when it makes false completion harder, makes the boundary clearer, or
helps users install the gate without learning the internals first.

## Roles

### Maintainer

A maintainer may triage issues, review pull requests, cut releases, and change
repository settings. Maintainers are listed in [MAINTAINERS.md](MAINTAINERS.md).

### Contributor

A contributor may open issues, propose spec changes, add tests, improve
documentation, or send pull requests. No special status is needed to contribute.

## Decision Process

Implementation changes use normal pull requests. A maintainer can merge them
when CI is green, the required review has approved, and the evidence in the pull
request matches the risk.

Specification changes are different. `SPEC.md` describes a convention other
tools can implement, so changes to it start as an issue. The issue should state:

- what behavior changes
- why the existing contract is insufficient
- what an independent implementation would have to do differently
- what compatibility risk the change creates

If a proposal is small and uncontroversial, a maintainer can accept it after a
public discussion. If it changes the meaning of conformance, it should stay open
long enough for downstream users to object before a pull request lands.

## Security Changes

Security-sensitive changes include:

- hook execution behavior
- state directory or ledger behavior
- release workflows and artifact publication
- GitHub Actions permissions
- anything that changes when `verify.sh` runs or does not run

These changes require maintainer review even if they are small. A pull request
must include command output and a reproduction or negative test whenever the
change affects enforcement.

## Release Authority

A maintainer cuts releases from `main` only after the release checklist in
[RELEASE.md](RELEASE.md) passes. Releases are immutable in practice: if a
release is wrong, publish a newer release and mark the bad one as superseded.

## Project Scope

In scope:

- the `verify.sh` convention
- the Claude Code hook implementation
- installation and diagnostic tooling
- recipes that help repositories write their own `verify.sh`

Out of scope:

- sandboxing untrusted repositories
- replacing CI
- hosting long-running or secret-backed checks locally
- guaranteeing that a hostile agent cannot bypass local files it can edit
