# Open Source Readiness

This file is the project's public operating checklist. It exists so maintainers
can improve the project without relying on memory or vibes.

## Repository

- Public organization-owned repository: yes
- License: MIT
- Default branch: `main`
- Branch protection: required checks, strict updates, linear history, force push
  disabled, branch deletion disabled, one approving review required
- Merge policy: squash merge only, delete branch on merge
- Discussions: enabled
- Wiki and Projects: disabled until there is a real operating need

## Security

- Security policy: `SECURITY.md`
- Private vulnerability reporting: enabled
- Secret scanning: enabled
- Secret scanning push protection: enabled
- Dependabot security updates: enabled
- CodeQL: enabled
- OpenSSF Scorecard: enabled
- Actions default token permission: read-only
- Release provenance: GitHub artifact attestation

## Contributor Experience

- README explains when to use the project and when not to
- `CONTRIBUTING.md` explains evidence expectations
- Pull request template asks for command output, diff, reproduction, and
  cross-check evidence
- Bug report and spec proposal templates exist
- Maintainer and governance files are public
- Roadmap states current priorities and non-goals

## Release Quality

- Release checklist exists in `RELEASE.md`
- Release verification instructions exist in `docs/RELEASE_VERIFICATION.md`
- Release workflow builds from tag
- Release assets include source archive and SHA-256 checksum
- GitHub provenance attestation is generated for the archive

## Known Scorecard Limits

Some OpenSSF Scorecard checks are intentionally not maxed out at project birth:

- `Maintained` improves with time and project activity.
- `Contributors` improves only when more organizations contribute.
- `Code-Review` improves after reviewed changes are merged over time.
- `Fuzzing` is not currently a good fit for this shell-hook project; adversarial
  behavior is covered with shell tests against real temporary git repositories.
- OpenSSF Best Practices Badge requires a separate self-certification workflow.

The goal is not to game the aggregate score. The goal is to make each remaining
gap explicit and either fix it or explain why it is not the right control.
