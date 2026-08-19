# Islamic App — Claude Code

Follow **AGENTS.md** as the source of truth for architecture, local run, GitHub APK CI, and release commands.

## Repo

- GitHub: https://github.com/if12is/islamic-app
- Account: **if12is** (never if13is)
- App: Flutter Islamic client (prayer times, Quran, Azkar, Qibla, settings)
- Language for code, commits, and agent docs: English

## Run locally

```bash
cd islamic-app
flutter pub get
flutter devices
flutter run
```

Hot reload: `r`. Hot restart: `R`. Analyze: `flutter analyze`. Tests: `flutter test`.

## APK on GitHub

- Push `master` → build APK and **replace** rolling release `apk-latest` (previous APK is deleted).
- Versioned release (kept): `./scripts/release.sh 1.1.0+2` or tag `v1.1.0` or commit `[release]`.
- Skip APK build: commit message `[skip apk]`.
- Manual: `gh workflow run android-apk.yml` with `update_latest` / `create_versioned_release`.

Workflow file: `.github/workflows/android-apk.yml`

## Code rules

- Feature-first Clean Architecture: `domain` (pure Dart) → `data` → `presentation`.
- Riverpod for state. `Either<Failure, T>` at data/domain boundaries.
- Strings via `context.tr`. Theme via `AppTheme` / `design_colors.dart`.
- `HomePage` is the live navigator (IndexedStack). `app_router.dart` is a stub until wired.
- Do not commit `build/`, secrets, or file-mode-only changes.
