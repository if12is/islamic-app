# Islamic App - Development Guide

## Project Overview

A comprehensive, production-ready Islamic mobile application built with Flutter, implementing Clean Architecture, SOLID principles, and featuring Riverpod for state management.

## Technology Stack

### Core Framework
- **Flutter**: Latest stable version for cross-platform development
- **Dart**: Programming language

### State Management & Dependency Injection
- **Riverpod** (flutter_riverpod): Reactive dependency injection and state management
- **Provider**: State management at presentation layer

### Architecture
- **Clean Architecture**: Separation of concerns into Domain, Data, and Presentation layers
- **Feature-First Structure**: Each feature is self-contained and modular

### Networking & Data
- **Dio**: HTTP client with interceptors for API calls
- **Hive**: Local persistent storage for caching
- **Shared Preferences**: Simple key-value storage for settings

### APIs Integrated
- **Aladhan API** (https://aladhan.com/prayer-times-api): Prayer times data
- **Quran.com API** (https://quran.com/api/v4): Quran verses and metadata
- **Local JSON Assets**: Azkar and offline data

### UI/UX
- **Material Design 3**: Modern UI framework
- **Cairo Font**: Arabic typography support
- **Localization**: RTL support for Arabic

### Additional Packages
- **go_router**: Declarative routing
- **geolocator**: Location services
- **flutter_compass**: Compass functionality
- **just_audio**: Audio playback
- **flutter_local_notifications**: Push notifications
- **equatable**: Value equality
- **dartz**: Functional programming (Either/Option)
- **logger**: Logging utility

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── core/                              # Core functionality
│   ├── constants/
│   │   └── app_constants.dart         # App-wide constants
│   ├── routing/
│   │   ├── app_router.dart            # Go Router configuration
│   │   └── route_names.dart           # Route name constants
│   ├── services/
│   │   ├── app_services.dart          # Service initialization
│   │   └── location_service.dart      # Location services
│   ├── theme/
│   │   └── app_theme.dart             # Theme definitions (light/dark)
│   └── utils/
│       ├── failure.dart               # Error/Failure definitions
│       ├── extensions.dart            # Dart extensions
│       └── validators.dart            # Input validators
├── features/                          # Feature modules
│   ├── onboarding/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── pages/
│   │       ├── providers/
│   │       └── widgets/
│   ├── home/                          # Home dashboard
│   ├── prayer_times/                  # Prayer times feature
│   ├── quran/                         # Quran reading feature
│   ├── azkar/                         # Azkar & Tasbeeh counter
│   └── settings/                      # App settings
├── shared/                            # Shared across features
│   ├── providers/
│   │   └── app_providers.dart         # Global Riverpod providers
│   └── widgets/
│       └── custom_widgets.dart        # Reusable UI components
└── assets/
    ├── data/
    │   └── azkar.json                 # Azkar data
    ├── fonts/
    │   ├── Cairo-*.ttf                # Arabic typography
    │   └── Tajawal-*.ttf              # Alternative Arabic font
    ├── images/
    └── icons/
```

## Clean Architecture Layers

### 1. Domain Layer (Business Logic)
- **Entities**: Pure business objects (immutable, no external dependencies)
- **Repositories (Abstract)**: Interfaces defining data contracts
- **Use Cases**: Business logic encapsulation

**Location**: `features/[feature]/domain/`

### 2. Data Layer (Data Management)
- **Models**: Entities extended with JSON serialization
- **Data Sources**: Remote (API) and Local (cache) data retrieval
- **Repository Implementation**: Concrete implementation combining data sources

**Location**: `features/[feature]/data/`

### 3. Presentation Layer (UI)
- **Pages**: Full-screen widgets
- **Widgets**: Reusable UI components
- **Providers**: Riverpod state management

**Location**: `features/[feature]/presentation/`

## Getting Started

### Prerequisites
- Flutter SDK (>=3.19.0)
- Dart SDK (>=3.7.0)
- Android Studio / Xcode for native development

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd islamic-app
   ```

2. **Get dependencies**
   ```bash
   flutter pub get
   ```

3. **Run code generation** (if using json_serializable)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Generate Riverpod providers** (if using riverpod_generator)
   ```bash
   dart run build_runner build
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

## Running the App

### Development
```bash
flutter run
```

### Release Build
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

### Run Tests
```bash
flutter test
```

## Features Implementation

### Prayer Times Feature

**Data Layer Flow:**
1. `PrayerTimesRemoteDataSource` → Fetches from Aladhan API
2. `PrayerTimesLocalDataSource` → Caches with Hive
3. `PrayerTimesRepositoryImpl` → Coordinates both with fallback logic

**Domain Layer:**
- `GetPrayerTimesUseCase` → Business logic for fetching times
- `PrayerTimesEntity` → Pure business object

**Presentation Layer:**
- `prayer_times_providers.dart` → Riverpod state management
- Async FutureProvider with error handling
- UI rebuilds reactively on state changes

### Error Handling

The app uses the `Either` type from the `dartz` package for functional error handling:

```dart
Future<Either<Failure, PrayerTimesEntity>> getPrayerTimes(...)
```

**Failure Types:**
- `NetworkFailure`: No internet connection
- `ServerFailure`: Server-side errors (4xx, 5xx)
- `DataFailure`: JSON parsing errors
- `CacheFailure`: Local storage errors
- `NotFoundFailure`: Resource not found
- `UnknownFailure`: Unexpected errors

## Riverpod State Management

### Provider Types Used

1. **Provider** (Computed values)
   ```dart
   final dioProvider = Provider((ref) => createDioClient());
   ```

2. **FutureProvider** (Async operations)
   ```dart
   final prayerTimesProvider = FutureProvider.family((ref, params) async { ... });
   ```

3. **StateNotifierProvider** (Mutable state)
   ```dart
   final themeModeProvider = StateNotifierProvider((ref) => ThemeModeNotifier(...));
   ```

### Watching Providers

In widgets, use `ConsumerWidget` or `ConsumerStatefulWidget`:

```dart
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerTimes = ref.watch(prayerTimesProvider(params));
    // Use prayerTimes...
  }
}
```

## RTL & Localization

The app supports both Arabic (RTL) and English (LTR):

```dart
// In main.dart
supportedLocales: const [
  Locale('ar', ''),  // Arabic (RTL)
  Locale('en', ''),  // English
],
locale: const Locale('ar', ''),  // Default to Arabic
```

### Cairo Font for Arabic

Configured in `pubspec.yaml`:
```yaml
fonts:
  - family: Cairo
    fonts:
      - asset: assets/fonts/Cairo-Regular.ttf
      - asset: assets/fonts/Cairo-Bold.ttf
        weight: 700
```

## Caching Strategy

**Prayer Times Caching:**
1. Try fetching from Aladhan API
2. On success, cache locally with Hive
3. On API failure, use cached data if available
4. If both fail, return error

**Cache Location**: Hive box named `prayer_times_cache`

## API Endpoints

### Aladhan API
- Base URL: `https://api.aladhan.com/v1`
- Timings endpoint: `/timings?latitude=...&longitude=...&method=...`

### Quran.com API
- Base URL: `https://quran.com/api/v4`
- Chapters: `/chapters`
- Verses: `/chapters/{chapterId}/verses`

## Best Practices

### Code Organization
- ✅ Each feature is self-contained
- ✅ No cross-feature imports (use shared layer)
- ✅ Separation of concerns (Domain → Data → Presentation)

### Error Handling
- ✅ Use `Either<Failure, T>` for operations that can fail
- ✅ Create specific Failure types, not generic exceptions
- ✅ Always provide user-friendly error messages

### State Management
- ✅ Use `ref.watch()` for reactive updates
- ✅ Use `ref.read()` for one-time reads
- ✅ Create separate providers for each piece of state

### Code Quality
- ✅ Add descriptive comments for complex logic
- ✅ Use `equatable` for value equality
- ✅ Keep widgets small and focused
- ✅ Use constants for repeated values

## Debugging

### Riverpod DevTools
```dart
// Add to pubspec.yaml dev_dependencies
riverpod: any
flutter_riverpod: any

// Use ProviderContainer for debugging
```

### Enabling Logs
```dart
// In datasources, use print() or logger package
print('📤 [API Request] GET /timings');
print('📥 [API Response] Status: 200');
print('❌ [API Error] NetworkException: Connection timeout');
```

## Contributing

1. Create a feature branch
2. Implement changes following Clean Architecture
3. Add tests for business logic
4. Submit a pull request

## License

[Your License Here]

## Support

For issues and questions, please contact:
- Email: support@islamicapp.com
- Issues: GitHub Issues

---

**Last Updated**: March 2024
**Version**: 1.0.0-alpha
