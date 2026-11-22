# Contributing to Fajr (الفجر)

Thank you for helping. Fajr is a free, offline-first prayer-times and Quran app with no ads, no tracking and no account.
Contributions are welcome in English or Arabic: code, tests, translations, Arabic speech/recitation data, and bug reports
from real phones (adhan delivery differs a lot between brands).

[`AGENTS.md`](./AGENTS.md) is the source of truth for architecture and conventions; [`ARCHITECTURE.md`](./ARCHITECTURE.md)
and [`DEVELOPMENT.md`](./DEVELOPMENT.md) go deeper.

## Pick something to work on
- [`good first issue`](https://github.com/if12is/islamic-app/labels/good%20first%20issue): small and self-contained, with pointers to the files involved.
- [`help wanted`](https://github.com/if12is/islamic-app/labels/help%20wanted): larger work, including the on-device Quran recitation model.
- Comment on the issue before you start, so two people do not do the same work.

## Set up
```bash
git clone https://github.com/if12is/islamic-app.git
cd islamic-app
flutter pub get
flutter run              # a phone, emulator, or: flutter run -d chrome
flutter analyze
flutter test
```
Use the latest stable Flutter SDK.

## Conventions
- Feature-first Clean Architecture: `domain` (pure Dart) → `data` → `presentation`, Riverpod for state,
  `Either<Failure, T>` at data/domain boundaries.
- UI strings only through `context.tr`, with every key in **both** `ar` and `en`
  (`lib/core/localization/app_localizations.dart`; `test/localization_keys_test.dart` checks this).
- HTTP only through `SecureHttpClient` (host allowlist); logging through `AppLogger`.
- Offline-first: prayer times, the Mushaf and azkar must keep working with no network.
- Material 3 widgets; theme via `AppTheme` / `design_colors.dart`.
- Code, comments and commits in English.

## Religious content
Quran text, hadith, azkar and duas must come from a named, reliable source, given in the PR.
Do not add audio unless you can state who owns it and that it may be redistributed.

## Pull requests
1. One issue per PR, with a test for new behaviour.
2. `flutter analyze` clean and `flutter test` green.
3. User-visible change: add a short `ar` + `en` line to `whats_new.json`.
4. Pushes to `master` build and publish the APK. Maintainers merge; add `[skip apk]` to the PR title for docs-only changes.

## License
The code is licensed under [GPL-3.0-or-later](./LICENSE); by opening a pull request you agree your contribution is licensed the same way.
Bundled third-party material keeps its own license: see [`NOTICE.md`](./NOTICE.md).
Please follow the [Code of Conduct](./CODE_OF_CONDUCT.md).
