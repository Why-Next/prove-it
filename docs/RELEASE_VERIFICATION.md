# Release Verification

Use this when you want to verify that a `prove-it` release asset came from this
repository's GitHub Actions release workflow.

## Verify the Checksum

Download the archive and checksum from the GitHub release page:

```bash
shasum -a 256 -c prove-it-v0.2.0.tar.gz.sha256
```

The command should print `OK`.

## Verify the Provenance Attestation

GitHub records provenance for the source archive created by the release
workflow. Verify it with:

```bash
gh attestation verify prove-it-v0.2.0.tar.gz -R Why-Next/prove-it
```

The verification should name `Why-Next/prove-it` as the repository and the
release workflow as the builder.

## Check the Tag

The archive is created with `git archive` from the tag. Confirm the tag points
to the commit you expect:

```bash
git fetch --tags origin
git rev-parse v0.2.0
```

Compare that commit with the release notes and the workflow run linked from the
GitHub release.

## When Verification Fails

Do not install the asset. Open an issue if the failure is public and harmless.
Email `hello@whynext.app` if the failure suggests a compromised release,
unexpected provenance, or tampered artifact.
