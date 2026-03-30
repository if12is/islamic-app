# Quick Start Guide

## Building & Running the Islamic App

### Prerequisites
```bash
# Verify Flutter is installed
flutter --version

# Get latest packages
flutter pub get

# Check for any issues
flutter doctor
```

### First Run
```bash
# Run on default device/emulator
flutter run

# Run with verbose output for debugging
flutter run -v

# Run on specific device
flutter run -d [device_id]
```

### Hot Reload
Press `r` in terminal while app is running to apply code changes without restarting.

## Building for Production

### Android
```bash
# Create release APK
flutter build apk --release

# Create App Bundle (for Google Play)
flutter build appbundle --release

# See output
ls -lh build/app/outputs/
```

### iOS
```bash
# Build for iOS
flutter build ios --release

# Archive for App Store
flutter build ios --release --no-codesign
```

### Web
```bash
flutter build web --release
```

## Key Features to Implement

### 1. Prayer Times Integration

**Current Status**: ✅ Complete data and domain layers
**Next Steps**:
1. Implement UI page (already started)
2. Create Riverpod providers (done)
3. Test with real Aladhan API
4. Add prayer notifications

**Code Example**:
```dart
// In your page
class PrayerTimesPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = PrayerTimesParams(
      latitude: 40.7128,  // New York
      longitude: -74.0060,
      method: 2,  // ISNA
    );
    
    final prayerTimesAsync = ref.watch(
      prayerTimesProvider(params)
    );
    
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Times')),
      body: prayerTimesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Text('Error: $error'),
        ),
        data: (prayerTimes) => ListView(
          children: prayerTimes.prayers
              .map((prayer) => ListTile(
                    title: Text(prayer.name),
                    trailing: Text(prayer.time),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
```

### 2. Dark/Light Theme

**Current Status**: ✅ Already implemented
**Using**: Riverpod StateNotifier

```dart
// Toggle theme
ref.read(themeModeProvider.notifier).toggleTheme();

// Set specific theme
ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark);
```

### 3. Location Services

**Current Status**: ⏳ Needs implementation
**Package**: `geolocator`

```dart
// Request location permission
LocationPermission permission = await Geolocator.requestLocationPermission();

// Get current location
Position position = await Geolocator.getCurrentPosition();
double lat = position.latitude;
double lng = position.longitude;
```

### 4. Local Caching with Hive

**Current Status**: ✅ Ready to use

```dart
// Cache prayer times
await localDataSource.cachePrayerTimes(prayerTimesModel);

// Retrieve cached data
final cached = await localDataSource.getCachedPrayerTimes();

// Clear cache
await localDataSource.clearCache();
```

### 5. Quran Feature

**Current Status**: ⏳ Needs implementation
**API**: Quran.com API v4

```dart
// Fetch all Surahs
final response = await dio.get('/chapters');
// Returns: { "chapters": [ { "id": 1, "name": "Al-Fatiha", ... } ] }

// Fetch verses for a Surah
final response = await dio.get('/chapters/1/verses');
// Returns: { "verses": [ { "verse_key": "1:1", "text_arabic": "...", ... } ] }
```

### 6. Azkar Feature

**Current Status**: ✅ JSON data ready, UI started

```dart
// Load Azkar from JSON
final jsonString = await rootBundle.loadString('assets/data/azkar.json');
final jsonData = jsonDecode(jsonString);
// Parse categories and azkar
```

### 7. Qibla Compass

**Current Status**: ⏳ Needs implementation
**Package**: `flutter_compass`

```dart
// Constants (already in app_constants.dart)
static const double kaabaLatitude = 21.4225;
static const double kaabaLongitude = 39.8264;

// Get compass bearing
CompassEvent.compassEvents.listen((CompassEvent event) {
  double heading = event.heading;
  
  // Calculate angle to Qibla from user location
  double qiblaAngle = calculateQiblaAngle(
    userLat, userLng,
    kaabaLatitude, kaabaLongitude
  );
});
```

## Code Organization Tips

### Adding a New Feature

1. **Domain Layer** (Business logic)
   ```
   features/new_feature/domain/
   ├── entities/
   │   └── new_entity.dart
   ├── repositories/
   │   └── new_repository.dart
   └── usecases/
       └── get_new_data_usecase.dart
   ```

2. **Data Layer** (Data management)
   ```
   features/new_feature/data/
   ├── datasources/
   │   ├── remote_datasource.dart
   │   └── local_datasource.dart
   ├── models/
   │   └── new_model.dart
   └── repositories/
       └── new_repository_impl.dart
   ```

3. **Presentation Layer** (UI)
   ```
   features/new_feature/presentation/
   ├── pages/
   │   └── new_page.dart
   ├── widgets/
   │   └── new_widget.dart
   └── providers/
       └── new_providers.dart
   ```

### Naming Conventions

- **Entities**: `PrayerEntity`, `QuranEntity`
- **Models**: `PrayerModel`, `QuranModel`
- **Repositories**: `PrayerTimesRepository` (interface), `PrayerTimesRepositoryImpl`
- **Data Sources**: `PrayerTimesRemoteDataSource`, `PrayerTimesLocalDataSource`
- **Use Cases**: `GetPrayerTimesUseCase`, `CachePrayerTimesUseCase`
- **Providers**: `prayerTimesProvider`, `getPrayerTimesUseCaseProvider`

## Common Issues & Solutions

### Issue: App crashes on startup
**Solution**: 
- Check that Hive is initialized: `await Hive.initFlutter()` in `main()`
- Verify all dependencies are installed: `flutter pub get`

### Issue: Riverpod providers not updating UI
**Solution**:
- Use `ConsumerWidget` instead of `StatelessWidget`
- Watch provider with: `ref.watch(xxxProvider)`
- Don't use `ref.read()` in build method

### Issue: API calls timeout
**Solution**:
- Check internet connection
- Increase timeout in Dio config
- For Aladhan: use example coordinates if network is slow

### Issue: Hot reload not working
**Solution**:
- Press `R` (uppercase) for hot restart
- If still fails, stop and run `flutter run` again

## Performance Tips

1. **Lazy Loading**
   ```dart
   final provider = FutureProvider.family((ref, id) async {
     // Only calls when actually watched
   });
   ```

2. **Memoization with `.select()`**
   ```dart
   // Only rebuild if name changes (not entire entity)
   final name = ref.watch(entityProvider.select((e) => e.name));
   ```

3. **Caching**
   - Prayer times cached for 24 hours
   - Quran data cached for 7 days
   - Use cache-first strategy

4. **Image Optimization**
   - Use WebP format when available
   - Resize images before display
   - Lazy load images in lists

## Testing

### Run All Tests
```bash
flutter test
```

### Run Specific Test
```bash
flutter test test/features/prayer_times/domain/usecases/get_prayer_times_usecase_test.dart
```

### Generate Coverage Report
```bash
flutter test --coverage
```

## Deployment Checklist

- [ ] Update version in `pubspec.yaml`
- [ ] Update `README.md` with new features
- [ ] Test on both Android and iOS
- [ ] Test on both light and dark themes
- [ ] Verify RTL layout for Arabic
- [ ] Run linting: `flutter analyze`
- [ ] Run tests: `flutter test`
- [ ] Build APK/iOS app
- [ ] Sign app with proper certificates
- [ ] Upload to Play Store/App Store

## Useful Commands

```bash
# Clean build
flutter clean
flutter pub get
flutter run

# Analyze code
flutter analyze

# Format code
dart format lib/

# Check for outdated packages
flutter pub outdated

# Get detailed device info
flutter devices -v

# Take screenshot
flutter screenshot

# Profile app performance
flutter run --profile

# Enable verbose logging
flutter run -v

# Generate Riverpod code
dart run build_runner build

# Generate JSON serialization
flutter pub run build_runner build
```

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Riverpod Documentation](https://riverpod.dev)
- [Aladhan Prayer Times API](https://aladhan.com/prayer-times-api)
- [Quran.com API](https://quran.com/api/v4)
- [Material Design 3](https://m3.material.io/)
- [Cairo Font Family](https://fonts.google.com/specimen/Cairo)

## Support & Contribution

Found a bug? Have a feature request?

1. Check if issue already exists
2. Provide detailed reproduction steps
3. Include device/Flutter version info
4. Submit PR with fixes

---

Happy coding! 🚀
