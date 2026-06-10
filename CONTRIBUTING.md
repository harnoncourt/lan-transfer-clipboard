# Contributing

Thanks for your interest in LAN Transfer Clipboard.

This project is an early MVP for local-network file and clipboard transfer. Contributions are welcome, especially around reliability, platform support, security hardening, tests, and documentation.

## Ground Rules

- Keep changes focused and easy to review.
- Prefer existing Flutter and Dart patterns already used in the project.
- Document protocol or platform behavior changes.
- Add or update tests when changing service behavior.
- Do not include generated build artifacts, secrets, signing certificates, provisioning profiles, or local machine paths.

## Development Setup

```bash
flutter pub get
flutter analyze
flutter test
```

Run the desktop app:

```bash
flutter run -d macos
```

Build common targets:

```bash
flutter build macos --release
flutter build apk --release
flutter build ios --release --no-codesign
```

Windows builds are produced through GitHub Actions.

## Pull Requests

Before opening a pull request:

1. Run `flutter analyze`.
2. Run `flutter test`.
3. Update docs when behavior changes.
4. Explain user-facing impact and any platform-specific testing.

## Security-Sensitive Changes

This project currently does not implement device pairing, authentication, or encryption. Please be explicit when a change affects the threat model. See [SECURITY.md](SECURITY.md) and [docs/security.md](docs/security.md).
