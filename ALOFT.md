# Aloft云上游

Android and Windows subscription client for https://www.aloft.icu, based on
[FlClash v0.9.4](https://github.com/chen08209/FlClash/tree/v0.9.4).

## Account experience

- Sign in with an existing website account. Registration, password recovery and
  purchases open the official website in the system browser.
- Display the account's remaining combined traffic, expiry and available plans.
  Pricing and membership restrictions come from XBoard, including private channels.
- On Connect, refresh eligibility, download the account's Clash subscription,
  validate it through the original core and use its lifecycle controller to connect.
- Store the session in platform secure storage; never persist the password.
- Sign out stops the connection, removes the managed profile, clears the local
  session and attempts to revoke the website token. Other imported profiles are retained.
- Account API calls use verified HTTPS without redirects. Subscription URLs must
  belong to the official domain. No administrator endpoint or embedded customer credential is used.

## Building and testing

Use the Flutter/Go/Rust versions in `.github/workflows/aloft-client.yml` and initialize
the pinned submodules. The project requirements and safe mode rules are in AGENTS.md.

```sh
flutter pub get
flutter gen-l10n
dart run flutter_launcher_icons
flutter analyze --no-fatal-infos
flutter test test/features/aloft
dart tool/package.dart windows --arch amd64
dart tool/package.dart android --arch arm64
```

The CI preview APK uses a development signing key and a separate `.dev` application ID.
Production Android distribution requires a backed-up release keystore supplied through
the existing Gradle signing inputs. Never commit signing keys or credentials. The Windows
preview is unsigned. The client does not improve the physical route to the server.

## Source and licenses

This is a modified distribution, not an official FlClash release. The original
GPL-3.0 license, copyright notices and third-party notices remain in the source.
Distribute corresponding source and build instructions alongside binaries. FlClash's
original project and core credits remain accessible from About. The Aloft account,
branding and build additions were made on 2026-11-24.
