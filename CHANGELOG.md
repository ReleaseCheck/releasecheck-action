# Changelog

## Unreleased

- Added platform-aware acquisition for Linux, macOS, and Windows release archives, including a non-extracting PowerShell ZIP path.
- Added a manual post-release Action E2E workflow that consumes an explicit public core version and asserts the generated report and expected verifier outcome.
- Extended the offline Action regression suite to assert that a nonzero core verifier status is propagated.
- Refreshed project status to record the public v0.1.2 core release and the passing live Action end-to-end validation.
- Established the initial composite GitHub Action repository.
- Added explicit core-release version selection, SHA-256 archive verification, JSON/SARIF/human output selection, and exit-code propagation.
- Documented that the Action invokes a released core binary and never installs or executes the inspected package.
