# Islamic App — Agent Guide

This file is the source of truth for Cursor, Claude Code, and other AI agents.
Write code, docs, and replies in **English**. UI copy may stay Arabic/English via `app_localizations.dart`.

GitHub repo: https://github.com/if12is/islamic-app (account **if12is**, not if13is).
Remote: `git@github.com:if12is/islamic-app.git` (SSH). HTTPS push needs a token.

## What this app is

Flutter Islamic mobile app: prayer times, Quran, Azkar/Tasbeeh, Qibla, settings, onboarding.
Stack: latest stable Flutter / Dart, Riverpod, Dio (via SecureHttpClient), Hive, Material 3, RTL Arabic.

Offline-first is a hard rule now: prayer times are calculated on device (`adhan`), the full
Quran text ships with the app (`quran`), and all fonts are bundled (Cairo for UI, ReemKufi for
headings, AmiriQuran / ScheherazadeNew for the Mushaf). The network is only used for tafsir,
recitation audio, and the Azkar dataset.

Package name: `islamic_app` (`pubspec.yaml`).
Android applicationId: `com.islamicapp.islamic_app`.
App version: `version:` in `pubspec.yaml` (`1.0.0+1` = name `1.0.0`, build `1`).

## How to run during development

Flutter is required (`flutter` must be on PATH). This machine can use:

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter --version   # expect latest stable
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
│   │   ├── constants/app_constants.dart   # API URLs, cache TTLs, storage keys, Kaaba coords
│   │   ├── localization/app_localizations.dart
│   │   ├── models/notification_preferences.dart  # alert modes + reminder settings
│   │   ├── routing/app_router.dart        # go_router stub (Home currently uses IndexedStack)
│   │   ├── services/                      # Hive, prayer calculation + settings store, Hijri
│   │   │                                  # service, notification service/scheduler/router,
│   │   │                                  # Azkar JSON, startup sync
│   │   ├── theme/                         # Material 3 light/dark + design tokens
│   │   ├── utils/failure.dart             # Either<Failure, T> error types
│   │   └── widgets/custom_loader.dart
│   ├── features/                          # Feature-first modules
│   │   ├── onboarding/                    # Splash + first-launch onboarding
│   │   ├── home/                          # Dashboard + bottom nav host
│   │   ├── prayer_times/                  # Full clean architecture + Qibla widget
│   │   ├── quran/                         # Offline Mushaf, reader, tafsir, bookmarks, notes,
│   │   │                                  # verse audio (background + repeat + sleep timer)
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

1. `main.dart` → `AppServices.initialize()` (Hive + notifications + time zones) → `JustAudioBackground.init()` → theme/locale prefs → background `runStartupSync()` → `NotificationScheduler.refresh()`.
2. `IslamicApp` shows splash/onboarding on first launch, then `HomePage`.
3. `HomePage` bottom nav: Dashboard (0), Quran (1), Azkar (2), Settings (3). Prayer times and Qibla open from the dashboard, not the nav bar.
4. Data sources: prayer times calculated locally by `PrayerCalculationService` (Aladhan is a fallback only); Quran text, pages, and juz from the bundled `quran` package; tafsir from AlQuran Cloud (cached in Hive for good); verse audio from `cdn.islamic.network`; Azkar from bundled JSON + GitHub JSON.

### Quran data

`QuranLocalService` is the single entry point: text, surah/juz/page indexes, hizb quarters,
sajdah verses, offline search, the verse of the day, and CDN audio URLs. Hizb quarter starts and
the 15 sajdah verses live in the generated `quran_meta_data.dart` — regenerate it rather than
hand-editing. Nothing in it performs I/O, so it is safe to call from the notification scheduler.

### Notifications

`NotificationService` owns channels, permissions, and exact scheduling; it schedules whatever it
is handed. `NotificationPlanner` (pure, unit-tested) turns `NotificationPreferences` plus the
calculated week into a list of `ScheduledNotification`s, and `NotificationScheduler` glues the two
to stored preferences. Refreshes are serialized, and run on launch, on any settings change, and
whenever the location or calculation method changes. Never call `zonedSchedule` from a page.

Notification taps and action buttons are resolved by `NotificationRouter` through
`appNavigatorKey`, using payloads like `quran:verse:2:255:play`. Adhan sounds are declared in
`NotificationService.adhanSounds`; a sound only becomes selectable once its file is in
`android/app/src/main/res/raw/` and its id is listed in `bundledAdhanSoundIds` (Android freezes a
channel's sound at creation, so each sound gets its own channel).

## Keep Flutter and packages current

Agents MUST use the latest stable Flutter SDK and the newest compatible package versions.

- Before adding a package, check pub.dev for the current stable version. Do not copy old versions from memory.
- After Flutter upgrades: `flutter pub upgrade --major-versions`, then `flutter analyze` and `flutter test`.
- Prefer Material 3 widgets: `NavigationBar`, `NavigationDestination` (with `selectedIcon`), `FilledButton` / `FilledButton.tonal`, `SegmentedButton`, `MenuAnchor`, `SearchAnchor`, `ListTile`, `Switch.adaptive`, `Card`, `CircleAvatar`, `CircularProgressIndicator.adaptive`.
- Use `Color.withValues(alpha:)` instead of `withOpacity`.
- HTTP only through `SecureHttpClient` (`lib/core/services/secure_http_client.dart`). Never construct a raw `Dio()` for production APIs.
- Never fetch Quran text or prayer times over the network — both are available on device.
- Every `AudioSource` needs a `MediaItem` tag: `just_audio_background` is initialized globally and throws without one.
- Log with `AppLogger`, never `print`.
- Validate coordinates, surah/juz numbers, search queries, and reciter URLs before network I/O.
- Android: keep `usesCleartextTraffic=false` and `network_security_config.xml`. Do not allow HTTP.
- UI copy stays bilingual via `context.tr`. Touch targets >= 48px. Respect `MediaQuery.disableAnimationsOf`.

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
