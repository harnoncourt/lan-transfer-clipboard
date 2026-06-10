# Security Policy

LAN Transfer Clipboard is currently an MVP intended for trusted local networks.

## Supported Versions

Security reports should target the latest release and the `main` branch.

## Current Security Status

The current version does not yet provide production-grade security guarantees:

- No device pairing.
- No authentication.
- No end-to-end encryption.
- No request signing.
- No per-device trust list.
- No file content scanning.

Use it only on networks you trust.

## Reporting a Vulnerability

Please do not open a public issue for a vulnerability that could put users at risk.

Preferred reporting path:

1. Use GitHub's private vulnerability reporting or security advisory flow if available.
2. Include affected version, platform, reproduction steps, and expected impact.
3. Avoid sharing exploit details publicly until a fix is available.

We will try to acknowledge reports promptly and coordinate fixes in public once it is safe to do so.

## Security Roadmap

The high-priority security roadmap is tracked in [docs/security.md](docs/security.md), including device pairing, trust management, size limits, signing, encryption, and receive confirmation.
