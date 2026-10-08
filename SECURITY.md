# Security Policy

The Action downloads a versioned ReleaseCheck binary from the official core repository and verifies its SHA-256 checksum before execution. It does not execute the package under inspection or invoke package managers.

Do not report package findings as Action vulnerabilities. For core verifier security issues, follow the [core security policy](https://github.com/ReleaseCheck/releasecheck/blob/main/SECURITY.md). For Action-specific issues, use private maintainer contact until a dedicated security contact is configured. Do not include secrets, tokens, or untrusted executable artifacts in public issues.
