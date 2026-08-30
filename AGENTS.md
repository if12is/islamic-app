# Islamic App — Agent Guide

This file is the source of truth for Cursor, Claude Code, and other AI agents.
Write code, docs, and replies in **English**. UI copy may stay Arabic/English via `app_localizations.dart`.

GitHub repo: https://github.com/if12is/islamic-app (account **if12is**, not if13is).
Remote: `git@github.com:if12is/islamic-app.git` (SSH). HTTPS push needs a token.

## What this app is

Flutter Islamic mobile app: prayer times, Quran, Azkar/Tasbeeh, Qibla, settings, onboarding.
Stack: latest stable Flutter / Dart, Riverpod, Dio (via SecureHttpClient), Hive, Material 3, RTL Arabic.

Offline-first is a hard rule now: prayer times are calculated on device (`adhan`), the full
Quran text ships with the app (`quran`), the full Hisn al-Muslim ships as an asset, and all
fonts are bundled (Cairo for UI, ReemKufi for headings, AmiriQuran / ScheherazadeNew for the
Mushaf). The network is used only for tafsir and recitation audio.

Package name: `islamic_app` (`pubspec.yaml`).
Android applicationId: `com.if12is.fajr` (Kotlin namespace stays `com.islamicapp.islamic_app`).
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
2. `IslamicApp` shows splash/onboarding on first launch, then `HomePage`. During Ramadan the splash
   plays a seasonal intro once a day (`SeasonalIntroService` decides, `SeasonalIntroScreen` plays it);
   any failure or timeout falls straight through to the app.
3. `HomePage` bottom nav has five slots, icons only, with Dashboard raised in a circle at the centre:
   Settings, Azkar, **Dashboard**, Quran, Prayer times. Tab indices stay logical (0 dashboard, 1 Quran,
   2 azkar, 3 settings, 4 prayer times) — `GlassNavBar` owns the visual order. Qibla opens from the dashboard.
4. Data sources: prayer times calculated locally by `PrayerCalculationService` (Aladhan is a fallback only); Quran text, pages, and juz from the bundled `quran` package; tafsir from AlQuran Cloud (cached in Hive for good); verse audio from `cdn.islamic.network`; Azkar from bundled JSON + GitHub JSON.

### Design system (read this before touching any screen)

`lib/core/theme/design_tokens.dart` is the only place a colour may be declared. `AppTokens` is a
`ThemeExtension`; read it with `context.tokens`, never `Color(0x…)` — `test/design_system_test.dart`
fails the build if a new literal appears outside the allowlist. `AppTheme.from(tokens)` builds both
themes, and `SeasonalTheme.dress(tokens, event)` returns a modified copy for Ramadan and the Eids,
which is why a season reaches every screen without any screen knowing about it.

The rule the palette rests on: **green is the identity, gold is the accent.** Gold is for the live
element, the hero card, and the one primary button on a screen. Text on gold is `tokens.onGold`
(deep green ink) — white on gold fails contrast and the test enforces it.

Shared components live in `lib/core/widgets/`: `AppScaffold` (wash + RTL + nav clearance),
`MeshBackground`, `AppCard`, `HeroCard`, `ProgressCard`, `AppListRow`, `SectionHeader`,
`PillSelector`, `ArcGauge`, `StoryRail`, `AyahBlock`, `HintPill`, `GhostIconButton`,
`GlassContainer`. Build a screen out of these rather than a fresh `Container` — see them all in
Settings → **معرض المكوّنات** (`DesignGalleryPage`), where the mood and season can be switched live.

Spacing, radii, shadows and motion come from `AppSpacing`, `AppRadii`, `AppShadows`, `AppMotion`.
Separate with space and elevation, not with borders.

### Seasonal decoration

`SeasonalDecorScope` (set once in `main.dart`) carries the current `SeasonalEvent` down the tree.
`MeshBackground` reads it and paints `SeasonalDecor` along the **top** of every page — lanterns,
stars, confetti or palms depending on the season. There is deliberately no bottom band: a silhouette
strip across the foot of the screen fought the floating nav bar for the same space and read as a row
of blobs. The bottom is the bar's own job, via `SeasonalNavFlourish`, which treats the bar's top
edge — a travelling light in Ramadan, breathing stars in the last ten nights, confetti crossing for
Fitr, a woven border for Adha.

**Each season gets its own drawing, never one drawing recoloured.** `SeasonalBanner` holds four
separate painters (crescent night / shaft of light / pennants and confetti / dune at dusk) precisely
because a shared composition with a swapped palette is what makes seasonal theming feel like a
checkbox. `SeasonalHeroArt` is the exception and is used only for onboarding.

All decoration is `IgnorePointer`, sits *behind* the page content, and stops dead when
`MediaQuery.disableAnimationsOf` is true.

Icons come from two places, and mixing them at the same size is what makes a screen look
assembled from parts:

- **UI icons** — `IslamicIcon` / `AppIcon` / `AppIconBadge` (`core/widgets/islamic_icon.dart`),
  backed by bundled Tabler SVGs in `assets/icons/` (MIT, licence file alongside). One stroke
  weight, one grid. Use these anywhere an icon labels a control.
- **Decorative motifs** — `Motif` / `MotifPainter` (`core/widgets/motif_icon.dart`): Kaaba, mosque,
  misbaha, rub' el hizb and the rest, drawn as paths for hero cards, the onboarding backdrop and
  seasonal decoration. Use them large; never as a 20px control icon.

Neither fetches anything at run time — an app that promises to work offline must not download its
own icons.

### Adhan sounds

The three bundled recordings live **twice**: in `android/app/src/main/res/raw/` for the
notification channels (a channel's sound is frozen when the channel is created, hence one channel
per sound) and in `assets/audio/` so Dart can play them. A raw resource is not reachable from
Flutter, and the in-app preview has to be. `AdhanPreviewPlayer` plays the file directly through
`just_audio` — never by posting a notification and hoping the channel sounds it, which is silent in
the foreground and impossible for a sound the OS owns.

### Seasonal artwork

`SeasonalHeroArt` (`core/widgets/seasonal_art.dart`) is the big illustration: an arabesque rosette,
a mosque skyline with lit windows and crescent finials, and lanterns swinging on cords. It is drawn
rather than photographed — a photo is somebody's mosque, a silhouette is everyone's, and it
recolours itself per season. It carries the onboarding when a season is on, and fills
`SeasonalBanner`. `CardCorners` adds the four quarter-rosettes to a card (`AppCard(corners: true)`),
used where a card holds revelation.

### Layout safety

`test/layout_overflow_test.dart` renders every shared component at 320px with 1.3× text in both
directions and fails on a single overflowed pixel. Fixed heights are the usual cause — prefer a
`ConstrainedBox(minHeight:)`, an `Expanded` bar, or a `FittedBox` over a `SizedBox(height:)` that a
font metric can outgrow.

### Typography

Three faces, three jobs, and they are not interchangeable: `ReemKufi` for titles
(`AppTextStyles.display`), `Cairo` for ordinary text (`AppTextStyles.body`), and `AmiriQuran`
for revelation (`AppTextStyles.quran`). All three are bundled — never reach for `google_fonts`,
which downloads at runtime and breaks offline.

Quranic text inside azkar and du'a is detected, not guessed: `QuranTextDetector` matches a line
against the whole normalized Mushaf and `ArabicTextBlock` renders the matched runs in the Mushaf
face inside a tinted frame. Use `ArabicTextBlock` for any text that may mix the two.

### Glass surfaces

`GlassContainer` and `GlassSearchField` (core/widgets) back the floating nav bar and the search
fields. They rely on a `BackdropFilter`, so whatever hosts them must let content scroll
underneath (`Scaffold(extendBody: true)` plus ~110px of bottom padding in scrollables).

### Location naming

`NearestCityService` bundles ~3,200 places (`assets/data/cities.json`, built by
`scripts/build_cities.py` + `scripts/finalize_cities.py` from GeoNames) with their governorate
and country in Arabic and English. `LocationService.describe` asks it first and the platform
geocoder second — the table is the only source that answers offline, on the web, and on devices
with no geocoding backend, and it answers at city level ("دمنهور، البحيرة، مصر") rather than
street level. Never show raw coordinates in the UI; if the table returns null (>120 km from any
known place) fall back to the geocoder, then to the stored label.

### Recitation check (experimental)

`RecitationService` wraps `speech_to_text` and uses the device's own recognizer: nothing is recorded,
nothing is uploaded, no model is downloaded by us. Which voice pack listens is the user's choice —
`RecitationLocaleSheet` lists what is installed, remembers the pick (`recitation_locale_id`), lets
several packs be switched between, and opens the system screen for adding more via the
`openSpeechSettings` method channel. A missing Arabic pack must never block anything else: the
feature is one screen behind a mic button, and the message says so. That recognizer is not built for classical recitation, so
`RecitationMatcher` (pure Dart, unit-tested) aligns what it heard against the text on the alef-stripped
skeleton, tolerating a dropped or inserted word, and grades each word correct / near / wrong. Treat its
output as a reading aid, never as a ruling — the screen says as much, and so should any feature built on it.

### Quran data

`QuranLocalService` is the single entry point: text, surah/juz/page indexes, hizb quarters,
sajdah verses, offline search, the verse of the day, and CDN audio URLs. Hizb quarter starts and
the 15 sajdah verses live in the generated `quran_meta_data.dart` — regenerate it rather than
hand-editing. Nothing in it performs I/O, so it is safe to call from the notification scheduler.

### Reading log, khatmah, and wird

`ReadingProgressStore` (Hive) records which Mushaf pages were opened on which day and for how
long; the reader writes to it as the user scrolls. Everything else is derived from that log:
the khatmah plan's progress, the streak and year heat map, and the daily wird card on the
dashboard. Never ask the user to "mark" a page — if they read it, it counts.

### Home-screen widget

`WidgetService` pushes the next prayer, the countdown, today's timetable, and the Hijri date to
`PrayerWidgetProvider` (Kotlin + `res/layout/prayer_widget.xml`) through `home_widget`. It is
refreshed by the same pass that reschedules notifications, so the widget can never drift from
the app.

### Memorisation

`HifzItem` carries its own spaced-repetition schedule (boxes of 1/2/4/7/15/30/60 days); the
review screen only grades, it never computes intervals inline. `HifzVerseView` handles the
progressive masking.

### Notifications

`NotificationService` owns channels, permissions, and exact scheduling; it schedules whatever it
is handed. `NotificationPlanner` (pure, unit-tested) turns `NotificationPreferences` plus the
calculated week into a list of `ScheduledNotification`s, and `NotificationScheduler` glues the two
to stored preferences. Refreshes are serialized, and run on launch, on any settings change, and
whenever the location or calculation method changes. Never call `zonedSchedule` from a page.

Notification taps and action buttons are resolved by `NotificationRouter` through
`appNavigatorKey`, using payloads like `quran:verse:2:255:play`. Adhan sounds are declared in
`NotificationService.adhanSounds` and shipped in `android/app/src/main/res/raw/` (see
`android/adhan_sounds.md` before adding one). Users can also import any audio file: `MainActivity` copies it into the
MediaStore notifications collection and returns a `content://` URI, because Android only plays a
sound the system itself can read. Android freezes a channel's sound at creation, so every sound —
bundled or imported — gets its own channel via `adhanChannelFor`.

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

## Secrets and API keys

**Never put a key in the repository.** Keys reach the build through
`--dart-define` from a GitHub Actions secret, and every one of them is absent
by default so the app still builds and works without it.

### `MAPS_EMBED_KEY` — the map on the nearest-mosques screen

Optional. Without it the screen still works: the OpenStreetMap list, and the
button that hands the search to whichever maps app is installed. With it, an
embedded Google map is drawn above the list showing mosques OpenStreetMap has
not been given — which in most Egyptian cities is nearly all of them.

To set it up:

1. Google Cloud Console → APIs & Services → Credentials → create an API key.
2. **Restrict it to the Maps Embed API and nothing else.** This is not
   optional and it is the whole security model. A key in a published APK can
   be extracted by anyone; the Maps Embed API is free with no request cap, so
   a key that unlocks only it is worth nothing to whoever extracts it. Leave
   it unrestricted, or restricted to anything billable, and it is a blank
   cheque — Places Nearby Search alone bills $32 per thousand calls past five
   thousand a month.
3. Add it as repository secret `MAPS_EMBED_KEY`.

Locally: `flutter run --dart-define=MAPS_EMBED_KEY=…`.

Do **not** use a key found in a tutorial or a gist. It belongs to someone
else, cannot be restricted by you, and stops working for every user the moment
its owner revokes it.

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

The default `GITHUB_TOKEN` cannot write repository secrets. The **Signing key** workflow needs `SIGNING_KEY_ADMIN_TOKEN` (PAT with Secrets: Read and write), or run `./scripts/mint-signing-key.sh` locally.

## Do not

- Do not change `origin` to another GitHub user.
- Do not commit execute-bit-only chmod noise (`100644` → `100755`).
- Do not add Play Store signing keys to git.
- Do not implement exploits, malware, or scrape private data.
