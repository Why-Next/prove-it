# Release process

This project is small, but it sits on the trust path of other repositories. A
release is not ready because the code looks right. It is ready when the evidence
below exists.

## Before tagging

1. Start from a clean working tree.
2. Run `./verify.sh` locally.
3. Check that the latest `verify`, `codeql`, and `scorecard` workflows are green
   on `main`.
4. Read the diff for `verify.sh`, `hooks/`, `.github/workflows/`, and
   `.claude-plugin/` with extra suspicion. These files define what users trust.
5. Confirm `CHANGELOG.md` has an entry for the plugin version in
   `.claude-plugin/plugin.json`.
6. Confirm `SECURITY.md` still states the real boundary: this is not a sandbox
   and it executes a repository-owned `verify.sh`.

## Tagging

Use an annotated tag. Sign it when your local Git setup supports signing.

```bash
git tag -a v0.2.0 -m "prove-it v0.2.0"
git push origin v0.2.0
```

The `release` workflow packages the tag with `git archive`, writes a SHA-256
checksum, and asks GitHub to create a provenance attestation for the archive.
The generated artifact is the thing to attach to the GitHub release.

## Release notes

Release notes must include:

- what changed for users
- what changed in the convention, if `SPEC.md` moved
- the verification command and result
- the security boundary, especially that `verify.sh` is repository-owned code
- the artifact checksum and a link to the GitHub attestation

## If a release is bad

Do not delete a tag silently. Publish a new patch release and mark the bad
release as superseded in GitHub Releases. If the issue is security-sensitive,
follow `SECURITY.md` first and write public details only after the fix exists.
