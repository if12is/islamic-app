# Islamic App — Agent Guide

This file is the source of truth for Cursor, Claude Code, and other AI agents.
Write code, docs, and replies in **English**. UI copy may stay Arabic/English via `app_localizations.dart`.

GitHub repo: https://github.com/if12is/islamic-app (account **if12is**, not if13is).
Remote: `git@github.com:if12is/islamic-app.git` (SSH). HTTPS push needs a token.

## What this app is

Flutter Islamic mobile app: prayer times, Quran, Azkar/Tasbeeh, Qibla, settings, onboarding.
Stack: Flutter 3.19+ / Dart 3.7+, Riverpod, Dio, Hive, go_router (stub), Material 3, Cairo font, RTL Arabic.

Package name: `islamic_app` (`pubspec.yaml`).
Android applicationId: `com.islamicapp.islamic_app`.
App version: `version:` in `pubspec.yaml` (`1.0.0+1` = name `1.0.0`, build `1`).

## How to run during development

Flutter is required (`flutter` must be on PATH). On macOS:

```bash
brew install --cask flutter
flutter doctor
```

Then from the project root (`islamic-app/`):

```bash
flutter pub get
flutter devices
flutter run
```

Useful variants:

```bash
flutter run -d chrome          # web (quick UI checks)
flutter run -d macos           # desktop
flutter run --release          # closer to the CI APK
r                               # hot reload while flutter run is active
R                               # hot restart
flutter analyze
flutter test
```

In Cursor: Run and Debug → **Islamic App**. Device/emulator must be running (Android emulator, iOS Simulator, Chrome, or a USB phone with USB debugging).

Do not commit `build/`, `.dart_tool/`, or secrets.

## Project structure

```
islamic-app/
├── lib/
│   ├── main.dart                          # Entry: Hive/Dio init, ProviderScope, IslamicApp
│   ├── core/                              # Shared app infrastructure
│   │   ├── constants/app_constants.dart   # API URLs, cache TTLs, Kaaba coords, methods
│   │   ├── localization/app_localizations.dart
│   │   ├── routing/app_router.dart        # go_router stub (Home currently uses IndexedStack)
│   │   ├── services/                      # Hive, notifications, Quran cache, Azkar JSON, startup sync
│   │   ├── theme/                         # Material 3 light/dark + design tokens
│   │   ├── utils/failure.dart             # Either<Failure, T> error types
│   │   └── widgets/custom_loader.dart
│   ├── features/                          # Feature-first modules
│   │   ├── onboarding/                    # Splash + first-launch onboarding
│   │   ├── home/                          # Dashboard + bottom nav host
│   │   ├── prayer_times/                  # Full clean architecture + Qibla widget
│   │   ├── quran/                         # Quran.com API + Surah reader
│   │   ├── azkar/                         # Categories, details, Tasbeeh (local JSON)
│   │   └── settings/                      # Theme, locale, prayer method
│   └── shared/providers/app_providers.dart  # Theme, locale, first-launch, location
├── assets/data/azkar.json
├── assets/fonts/Cairo-Variable.ttf
├── android/ ios/ web/ macos/ linux/ windows/
├── .github/workflows/android-apk.yml      # CI APK + GitHub Releases
└── scripts/release.sh                     # Opt-in versioned release from CLI
```

### Feature layout (Clean Architecture)

When a feature has a domain/data layer, keep this shape:

```
lib/features/<name>/
  domain/     entities, repository interfaces, use cases  (no Flutter/Dio/Hive)
  data/       models, remote/local datasources, repository impl
  presentation/  pages, widgets, Riverpod providers
```

`prayer_times` is the reference implementation. Other features may still be presentation-heavy; when you add logic, follow this split.

### Runtime flow

1. `main.dart` → `AppServices.initialize()` → theme/locale prefs → background `runStartupSync()`.
2. `IslamicApp` shows splash/onboarding on first launch, then `HomePage`.
3. `HomePage` bottom nav: Dashboard (0), Quran (1), Azkar (2), Settings (3). Prayer times and Qibla open from the dashboard, not the nav bar.
4. APIs: Aladhan (`api.aladhan.com`) for timings; Quran.com v4 for chapters/verses; Azkar from bundled JSON + optional remote JSON.

## Architecture rules for agents

- Domain layer: no Flutter, Dio, Hive, or Riverpod imports.
- Failures: return `Either<Failure, T>` across data/domain. Map exceptions in the repository impl.
- State: Riverpod. Use `ConsumerWidget` / `ConsumerStatefulWidget`. `ref.watch` in `build`, `ref.read` for one-off actions.
- UI strings: `context.tr('key')` in `app_localizations.dart`. Add both `ar` and `en`.
- Theme: `AppTheme` + `design_colors.dart`. Do not hardcode random colors.
- Keep widgets small. Put API/cache work in services or data sources, not in pages.
- `app_router.dart` is a stub. Do not assume go_router is the live navigator until it is wired in `main.dart`.

## GitHub APK workflow

Workflow: `.github/workflows/android-apk.yml`

Release APK is **debug-signed** (see `android/app/build.gradle.kts`) so testers can install it. Not for Play Store.

| Command / trigger | Builds APK | Replaces rolling `apk-latest` (deletes previous) | Creates kept versioned release |
|---|---|---|---|
| `git push origin master` | yes | yes | no |
| commit message contains `[release]` then push | yes | yes | yes (from pubspec version) |
| `./scripts/release.sh 1.1.0+2` | yes | yes | yes (`v1.1.0`) |
| `git tag v1.1.0 && git push origin v1.1.0` | yes | yes | yes |
| Actions → Run workflow | yes | checkbox `update_latest` | checkbox `create_versioned_release` |
| commit message contains `[skip apk]` | no | no | no |

Rolling release URL: https://github.com/if12is/islamic-app/releases/tag/apk-latest  
Actions: https://github.com/if12is/islamic-app/actions

Manual dispatch via GitHub CLI:

```bash
# Build + replace rolling APK only
gh workflow run android-apk.yml -f update_latest=true -f create_versioned_release=false

# Build only, do not touch GitHub Releases
gh workflow run android-apk.yml -f update_latest=false -f create_versioned_release=false

# Build + versioned release (kept) + replace latest
gh workflow run android-apk.yml -f update_latest=true -f create_versioned_release=true -f version=1.1.0+2
```

Never delete versioned tags (`v1.x.x`) unless the user asks. Only `apk-latest` is deleted/recreated.

## Do not

- Do not change `origin` to another GitHub user.
- Do not commit execute-bit-only chmod noise (`100644` → `100755`).
- Do not add Play Store signing keys to git.
- Do not implement exploits, malware, or scrape private data.
