# Changelog

## Unreleased

- Added a manual post-release Action E2E workflow that consumes an explicit public core version and asserts the generated report and expected verifier outcome.
- Refreshed project status to record the completed Phase 16 re-audit and the still-pending public core release required for live Action end-to-end validation.
- Established the initial composite GitHub Action repository.
- Added explicit core-release version selection, SHA-256 archive verification, JSON/SARIF/human output selection, and exit-code propagation.
- Documented that live end-to-end execution awaits the first public ReleaseCheck core release.
