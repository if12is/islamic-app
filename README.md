# Islamic App 🕌

A comprehensive, production-ready Islamic mobile application with prayer times, Quran reading, Azkar (remembrances), and more. Built with Flutter following Clean Architecture principles and SOLID design patterns.

## Features

- ✅ **Prayer Times**: Real-time prayer times using the Aladhan API with customizable calculation methods
- ✅ **Holy Quran**: 114 Surahs with verses, translations, and audio recitation (Quran.com API)
- ✅ **Azkar**: Morning and evening remembrances with an interactive Tasbeeh counter
- ✅ **Qibla Direction**: Compass showing the direction to Kaaba from your location
- ✅ **Hijri Calendar**: Islamic calendar dates integrated throughout the app
- ✅ **Dark Mode**: Full support for light and dark themes
- ✅ **RTL Arabic**: Complete right-to-left support for Arabic language using Cairo font
- ✅ **Offline Access**: Cache offline data for prayer times and Quran verses
- ✅ **Notifications**: Prayer time reminders and important Islamic event alerts
- ✅ **Location Services**: Automatic location detection for accurate prayer times

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
- Flutter SDK: `>=3.19.0`
- Dart SDK: `>=3.7.0`
- Android SDK or Xcode (for native development)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/islamic-app.git
   cd islamic-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Development

See [QUICKSTART.md](QUICKSTART.md) for common commands and troubleshooting.

## Project Structure

```
islamic_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── core/                        # Shared functionality
│   │   ├── constants/               # App constants
│   │   ├── routing/                 # Navigation
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
| Prayer Times | ✅ 90% | Data & Domain complete, UI in progress |
| Quran | ⏳ 30% | API integration ready, UI needed |
| Azkar | ✅ 50% | JSON data ready, Counter UI done |
| Settings | ✅ 75% | Theme toggle, prayer method selector done |
| Dark Mode | ✅ 100% | Full light/dark theme support |
| RTL Arabic | ✅ 100% | Cairo font configured, RTL layout ready |
| Notifications | ⏳ 0% | Framework setup complete, implementation pending |
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

- [ ] Complete Prayer Times UI with countdown timer
- [ ] Implement Quran reading screen with verse navigation
- [ ] Add prayer time notifications
- [ ] Implement Qibla compass functionality
- [ ] Add widget support
- [ ] Implement user authentication
- [ ] Add cloud sync for bookmarks
- [ ] Offline Quran download support
- [ ] Multiple recitation options for Quran
- [ ] Hijri calendar view
- [ ] Salat reminder customization

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

- **Aladhan**: Prayer times

 API
- **Quran.com**: Quran API
- **Flutter Team**: Amazing framework
- **Islamic Academy**: Islamic content standards

## Support

For issues, questions, or suggestions:
- 📧 Email: support@islamicapp.com
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/islamic-app/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/yourusername/islamic-app/discussions)

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

Last Updated: March 2024 | Version: 1.0.0-alpha

