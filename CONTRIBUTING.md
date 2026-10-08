# Contributing to releasecheck-action

This repository owns only the GitHub Actions integration. The verification engine belongs to [ReleaseCheck/releasecheck](https://github.com/ReleaseCheck/releasecheck). User-facing documentation belongs to [ReleaseCheck/releasecheck-docs](https://github.com/ReleaseCheck/releasecheck-docs).

Run the structural test:

```text
bash tests/validate-action.sh
```

Keep the core version explicit and deterministic. Do not add package-manager execution, dynamic installers, `curl | sh`, unpinned production dependencies, or verification logic that belongs in the core repository. Changes to release URLs, checksum handling, shell input validation, or exit-code behavior require focused tests and security review.
