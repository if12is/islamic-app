# Islamic App 🕌

A comprehensive, production-ready Islamic mobile application with prayer times, Quran reading, Azkar (remembrances), and more. Built with Flutter following Clean Architecture principles and SOLID design patterns.

## Features

- ✅ **Prayer Times**: Calculated on device (`adhan`) — works offline, for any date, with selectable methods
- ✅ **Holy Quran**: The full Mushaf ships with the app — instant, offline, with page/juz/sajdah data
- ✅ **Reader controls**: Font, size, line spacing, margins, reading themes, brightness lock, auto-scroll
- ✅ **Verse tools**: Tafsir (5 editions, cached), bookmarks with tags and notes, share as text or image
- ✅ **Index**: Surahs, juz, hizb, Mushaf pages, sajdah verses, and "go to" any exact reference
- ✅ **Reflections**: A notes screen with search, ordering, and plain-text export
- ✅ **Hijri calendar**: The Islamic month with its events, fasting days, each day's prayer times, and a full Ramadan imsakiya
- ✅ **Memorisation**: Progressive masking, spaced review, and a "finish the verse" quiz
- ✅ **Reciter library**: Seven reciters, per-surah downloads, and offline playback
- ✅ **Backup**: Export everything to a JSON file and restore it on another device
- ✅ **Recitation**: Verse-by-verse playback with synced highlight, background audio, adjustable speed, range repetition for memorisation, and a sleep timer
- ✅ **Azkar**: The full Hisn al-Muslim — 136 chapters, 352 supplications with their virtues and references, bundled offline
- ✅ **Khatmah plan & daily wird**: A plan that re-spreads what is left, a combined daily wird card, a reading streak, and a year heat map
- ✅ **Home-screen widget**: Next prayer, countdown, today's timetable, and the Hijri date
- ✅ **Qibla Direction**: Compass showing the direction to Kaaba from your location
- ✅ **Hijri Calendar**: Islamic calendar dates integrated throughout the app
- ✅ **Dark Mode**: Full support for light and dark themes
- ✅ **RTL Arabic**: Complete right-to-left support for Arabic language using Cairo font
- ✅ **Offline Access**: Cache offline data for prayer times and Quran verses
- ✅ **Notifications**: Real scheduling seven days ahead — per-prayer alert modes, three bundled adhans (or import your own), a separate Fajr adhan, pre-adhan and iqama reminders, sun-anchored azkar, Friday/fasting/Hijri occasions, quiet hours, all from one notification centre
- ✅ **Location Services**: Automatic location detection for accurate prayer times

## Latest Achievements (March 2026)

- ✅ Delivered Prayer Times flow end-to-end (entity, model, local datasource, repository, provider, and UI)
- ✅ Implemented Quran reader improvements with Surah page enhancements and API service updates
- ✅ Completed Azkar experience updates with categories view, details view, and improved navigation
- ✅ Completed onboarding and splash experience polish for first-launch flow
- ✅ Added startup sync and shared provider wiring for better app initialization
- ✅ Refined design/theme system and app-wide loading/error handling components
- ✅ Updated app branding assets (Android, iOS, and Web icons/manifest)

## Screenshots

> Coming soon...

## Architecture

This project implements **Feature-First Clean Architecture** with strict separation of concerns:

```
├── Presentation Layer (UI & State)
│   ├── Pages
│   ├── Widgets
│   └── Providers (Riverpod)
│
├── Domain Layer (Business Logic - No external dependencies)
│   ├── Entities
│   ├── Repositories (Abstract)
│   └── Use Cases
│
└── Data Layer (Data Management)
    ├── Models
    ├── Data Sources (Remote/Local)
    └── Repository Implementation
```

### Key Principles

- **Independent Layers**: Each layer can be tested and modified independently
- **Dependency Injection**: Riverpod manages all dependencies
- **Error Handling**: Functional approach using `Either<Failure, Success>`
- **Immutability**: Entities use `Equatable` for value equality
- **SOLID Principles**: Single responsibility, open/closed, proper abstraction

For detailed architecture documentation, see [ARCHITECTURE.md](ARCHITECTURE.md)

## Tech Stack

### Core
- **Flutter**: Latest stable version
- **Dart**: Programming language

### State Management
- **Flutter Riverpod**: Reactive dependency injection and state management
- **Provider**: Peer dependency for Riverpod

### Networking & Storage
- **Dio**: HTTP client with interceptors
- **Hive**: Local persistent storage for caching
- **Shared Preferences**: Simple key-value storage

### UI/Design
- **Material Design 3**: Modern UI framework
- **Cairo Font**: Arabic typography
- **Animations**: Smooth transitions and micro-interactions

### APIs
- **Aladhan Prayer Times API**: Prayer times and Islamic calendar
- **Quran.com API v4**: Quran verses and metadata
- **Local JSON**: Azkar offline data

### Utilities
- **Equatable**: Value equality for entities
- **Dartz**: Functional programming (Either/Option)
- **Logger**: Structured logging
- **Geolocator**: Location services
- **Flutter Compass**: Compass functionality
- **Just Audio**: Audio playback for Quran recitation
- **Flutter Local Notifications**: Push notifications

## Getting Started

### Prerequisites
- Flutter SDK: `>=3.19.0` (`brew install --cask flutter` on macOS, then `flutter doctor`)
- Dart SDK: `>=3.7.0`
- A device: Android emulator, iOS Simulator, Chrome, macOS, or a USB phone

### Run while developing

```bash
git clone https://github.com/if12is/islamic-app.git
cd islamic-app
flutter pub get
flutter devices
flutter run
```

- Hot reload: press `r` in the terminal where `flutter run` is active
- Hot restart: press `R`
- Web preview: `flutter run -d chrome`
- Cursor: Run and Debug → **Islamic App** (see `.vscode/launch.json`)

See [QUICKSTART.md](QUICKSTART.md) for extra commands. Agent/project map: [AGENTS.md](AGENTS.md).

## GitHub APK workflow

Every push to `master` builds a release APK and **replaces** the rolling GitHub Release [`apk-latest`](https://github.com/if12is/islamic-app/releases/tag/apk-latest) (the previous preview APK is deleted).

| How you trigger it | Rolling `apk-latest` | Kept versioned release |
|---|---|---|
| `git push origin master` | replace previous | no |
| commit message includes `[release]` | replace previous | yes |
| `./scripts/release.sh 1.1.0+2` | replace previous | yes (`v1.1.0`) |
| `git tag v1.1.0 && git push origin v1.1.0` | replace previous | yes |
| Actions → Run workflow | `update_latest` checkbox | `create_versioned_release` checkbox |
| commit message includes `[skip apk]` | skip | skip |

```bash
# Versioned release from the CLI (opt-in)
./scripts/release.sh 1.1.0+2

# Manual workflow (GitHub CLI)
gh workflow run android-apk.yml -f update_latest=true -f create_versioned_release=false
```

The CI APK is debug-signed for testing, not Play Store. Workflow: `.github/workflows/android-apk.yml`.

## Project Structure

```
islamic_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── core/                        # Shared functionality
│   │   ├── constants/               # App constants
│   │   ├── localization/            # ar/en strings
│   │   ├── routing/                 # go_router stub (HomePage is live nav)
│   │   ├── services/                # Core services
│   │   ├── theme/                   # Theme configuration
│   │   └── utils/                   # Utilities & helpers
│   ├── features/                    # Feature modules
│   │   ├── onboarding/              # Onboarding screens
│   │   ├── home/                    # Home dashboard
│   │   ├── prayer_times/            # Prayer times feature
│   │   ├── quran/                   # Quran reading
│   │   ├── azkar/                   # Azkar & Tasbeeh
│   │   └── settings/                # App settings
│   └── shared/                      # Shared across features
│       ├── providers/               # Global providers
│       └── widgets/                 # Reusable widgets
└── assets/
    ├── data/                        # JSON data files
    ├── fonts/                       # Custom fonts (Cairo)
    ├── images/                      # Images
    └── icons/                       # Icons
```

## Feature Implementation Status

| Feature | Status | Details |
|---------|--------|---------|
| Prayer Times | ✅ 100% | Local/remote datasources, models, and UI complete |
| Quran | ✅ 90% | API integration, caching service, and Surah reader implemented |
| Azkar | ✅ 100% | Categories, details pages, data sync, and Tasbeeh counter complete |
| Settings | ✅ 100% | Theme toggle, prayer method selector, and full app settings done |
| Onboarding | ✅ 100% | Splash screens and new user onboarding flow complete |
| Dark Mode | ✅ 100% | Full light/dark theme support |
| RTL Arabic | ✅ 100% | Cairo font configured, RTL layout ready |
| Notifications | ✅ 80% | Core notification service added, prayer alerts configured |
| Qibla Compass | ⏳ 0% | Dependencies ready, implementation pending |

## API Documentation

### Aladhan Prayer Times API

```
GET https://api.aladhan.com/v1/timings?latitude={lat}&longitude={lng}&method={method}

Parameters:
- latitude (double): Geographic latitude
- longitude (double): Geographic longitude
- method (int): Calculation method (2=ISNA, 3=Muslim World League, 4=Umm Al-Qura, 5=Egyptian Authority)
- date (optional, string): YYYY-MM-DD format

Response: { "code": 200, "data": { "timings": {...}, "date": {...} } }
```

### Quran.com API

```
GET https://quran.com/api/v4/chapters
GET https://quran.com/api/v4/chapters/{chapterId}/verses
GET https://quran.com/api/v4/chapters/{chapterId}/info-en  (English info)

Response: { "chapters": [...] } or { "verses": [...] }
```

## Caching Strategy

- **Prayer Times**: 24-hour cache (updates if location changes)
- **Quran Data**: 7-day cache (user-initiated refresh available)
- **Azkar**: Static local JSON (always available offline)
- **Settings**: Immediately persisted to SharedPreferences

## Error Handling

All operations that can fail return `Either<Failure, Success>`:

```dart
final result = await getPrayerTimesUseCase(...);

result.fold(
  (failure) => print('Error: ${failure.message}'),
  (success) => print('Success: $success'),
);
```

**Failure Types**:
- `NetworkFailure`: No internet or connection timeout
- `ServerFailure`: HTTP errors (4xx, 5xx)
- `DataFailure`: JSON parsing errors
- `CacheFailure`: Local storage errors
- `NotFoundFailure`: Resource not found
- `UnknownFailure`: Unexpected errors

## Internationalization (i18n)

The app supports:
- **Arabic** (RTL) - Default/Primary language
- **English** (LTR) - Secondary language

Configure in `main.dart`:
```dart
supportedLocales: const [
  Locale('ar', ''),  // Arabic
  Locale('en', ''),  // English
],
locale: const Locale('ar', ''),  // Default
```

## Building for Production

### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed build instructions.

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/features/prayer_times/domain/usecases/
```

## Code Quality

```bash
# Analyze code
flutter analyze

# Format code
dart format lib/

# Check for issues
dart fix --dry-run
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## Roadmap

- [x] Complete Prayer Times UI with countdown timer
- [x] Implement Quran reading screen with verse navigation
- [x] Add prayer time notifications
- [x] Salat reminder customization
- [ ] Implement Qibla compass functionality
- [ ] Add widget support
- [ ] Implement user authentication
- [ ] Add cloud sync for bookmarks
- [ ] Offline Quran download support
- [ ] Multiple recitation options for Quran
- [ ] Hijri calendar view

## Performance Optimization

- **Lazy Loading**: Data only fetched when needed
- **Caching**: Intelligent cache strategy to reduce API calls
- **Offline First**: Works without internet when cached
- **Efficient State Management**: Riverpod's fine-grained reactivity
- **Widget Performance**: Widgets rebuilt only when data changes

## Security Considerations

- ✅ Sensitive data cached with Hive encryption (can be enabled)
- ✅ API calls over HTTPS only
- ✅ No storing of authentication tokens (currently no auth)
- ⏳ Rate limiting on API calls (to implement)
- ⏳ Input validation on all user inputs (to implement)

## Accessibility

- Material Design 3 compliance
- Semantic widgets for screen readers
- Sufficient color contrast ratios
- Large touch targets (48x48 minimum)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Aladhan**: Prayer times API
- **Quran.com**: Quran API
- **Flutter Team**: Amazing framework
- **Islamic Academy**: Islamic content standards

## Support

For issues, questions, or suggestions:
- 📧 Email: support@islamicapp.com
- 🐛 Issues: [GitHub Issues](https://github.com/if12is/islamic-app/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/if12is/islamic-app/discussions)

## FAQ

**Q: Can I run this app offline?**
A: Yes! Cached prayer times, Quran verses, and Azkar work offline.

**Q: Which Islamic calculation method is best?**
A: Different regions use different methods. The app supports multiple methods (ISNA, Muslim World League, Umm Al-Qura, Egyptian Authority). Choose based on your location.

**Q: How often do prayer times update?**
A: Prayer times are cached for 24 hours. You can manually refresh or they'll update if your location changes significantly.

**Q: Is there Arabic language support?**
A: Yes! The app fully supports Arabic with RTL layout and the Cairo font for beautiful typography.

---

**Made with ❤️ for the Muslim community**

Last Updated: April 2026 | Version: 1.1.0-beta

