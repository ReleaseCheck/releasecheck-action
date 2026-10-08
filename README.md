# ReleaseCheck GitHub Action

This repository contains the official GitHub Actions integration for [ReleaseCheck](https://github.com/ReleaseCheck/releasecheck).

The Action invokes a released ReleaseCheck core binary. It does not reimplement registry metadata handling, archive inspection, source comparison, security analysis, or provenance parsing.

## Current status

ReleaseCheck has not published `v0.1.0` yet. This Action repository is structurally ready for the first core release, and its local CI validates the action metadata and download/checksum command path. A live end-to-end Action run remains blocked until a matching public core release exists.

The initial integration supports Ubuntu runners with Bash, `curl`, `tar`, and `sha256sum`. Windows and macOS runner support should be added only with tested platform-specific acquisition behavior.

## Usage

```yaml
jobs:
  verify-release:
    runs-on: ubuntu-latest
    steps:
      - uses: ReleaseCheck/releasecheck-action@main
        with:
          ecosystem: npm
          package: example-package
          releasecheck-version: 0.1.0
          format: sarif
          output: releasecheck.sarif
```

Use a released Action tag or commit in production after the first release. The `releasecheck-version` input is required and must be an explicit semantic version. The Action downloads the matching Linux amd64 archive from the core release and verifies its SHA-256 checksum before execution.

Inputs:

- `ecosystem`: `npm` or `pypi`.
- `package`: package name.
- `version`: optional package version.
- `artifact`: optional PyPI release filename.
- `timeout`: ReleaseCheck timeout, default `30s`.
- `releasecheck-version`: released core version without `v`.
- `format`: `human`, `json`, or `sarif`; default `json`.
- `output`: report path relative to the workspace; default `releasecheck-report.json`.

The Action propagates ReleaseCheck exit codes: `0` for `MATCH`, `1` for `REVIEW` or `INCOMPLETE`, `2` for usage errors, and `3` for operational errors.

## Boundaries

The core tool never installs or executes the package being inspected. This Action does not invoke npm, pip, package installation scripts, build backends, or arbitrary package code. It only downloads and executes the explicitly selected ReleaseCheck release binary.

For actual verification semantics and limitations, read the [core README](https://github.com/ReleaseCheck/releasecheck) and [public documentation](https://github.com/ReleaseCheck/releasecheck-docs).

## Development

```text
bash tests/validate-action.sh
```

Do not claim end-to-end success until a public core release has been published and tested through the Action.
