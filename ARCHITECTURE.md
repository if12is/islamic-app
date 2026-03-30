# Clean Architecture Guide

## Overview

This project implements **Feature-First Clean Architecture** with strict separation of concerns across three layers:

```
Presentation Layer (UI)
        ↓ (Uses UseCase)
Domain Layer (Business Logic)
        ↓ (Depends on Repository)
Data Layer (Data Management)
```

## Architecture Principles

### 1. Independence of Frameworks
The business logic (Domain layer) has zero dependencies on Flutter, Riverpod, or any framework.

### 2. Testability
Each layer can be tested independently by mocking dependencies.

### 3. Independence of UI
The UI framework can be replaced without changing business logic.

### 4. Independence of Database
The database or data source can be changed without affecting domain logic.

### 5. Independence of Entity Frameworks
Entities are PODOs (Plain Old Dart Objects) with no external dependencies.

## Layer Breakdown

## Layer 1: Domain Layer

**Purpose**: Contains pure business logic with NO external dependencies

**Responsibility**:
- Define business entities
- Define repository interfaces (contracts)
- Implement use cases (business logic)

**Location**: `lib/features/[feature]/domain/`

### Components

#### 1.1 Entities
Pure business objects representing core concepts.

**Example: PrayerEntity**
```dart
class PrayerEntity extends Equatable {
  final String name;
  final String time;
  
  const PrayerEntity({required this.name, required this.time});
  
  @override
  List<Object?> get props => [name, time];  // For equality
}
```

**Characteristics**:
- Immutable (`final` properties)
- No methods (except pure domain logic)
- No external dependencies
- Use `Equatable` for value equality

#### 1.2 Repository (Abstract)
Interface defining data contracts that Data layer must implement.

**Example: PrayerTimesRepository**
```dart
abstract class PrayerTimesRepository {
  Future<Either<Failure, PrayerTimesEntity>> getPrayerTimes({
    required double latitude,
    required double longitude,
    int method = 3,
    String? date,
  });
}
```

**Characteristics**:
- Abstract class (defines contract)
- Uses `Either<Failure, Success>` for error handling
- Method signatures match data retrieval needs
- Implemented in Data layer

#### 1.3 Use Cases
Encapsulate individual business operations.

**Example: GetPrayerTimesUseCase**
```dart
class GetPrayerTimesUseCase {
  final PrayerTimesRepository repository;
  
  GetPrayerTimesUseCase({required this.repository});
  
  Future<Either<Failure, PrayerTimesEntity>> call({
    required double latitude,
    required double longitude,
    int method = 3,
    String? date,
  }) async {
    // Can add business logic, validation, etc.
    return await repository.getPrayerTimes(
      latitude: latitude,
      longitude: longitude,
      method: method,
      date: date,
    );
  }
}
```

**Characteristics**:
- Single responsibility (one operation per class)
- Uses repository to access data
- Returns `Either<Failure, Success>`
- Can include validation and pre/post-processing

## Layer 2: Data Layer

**Purpose**: Implement data sources and repository concretely

**Responsibility**:
- Fetch data from remote APIs
- Retrieve data from local cache
- Map API responses to entities
- Implement repository interface

**Location**: `lib/features/[feature]/data/`

### Components

#### 2.1 Data Sources
Abstract classes defining how to access specific data sources.

**Remote Data Source (API calls)**:
```dart
class PrayerTimesRemoteDataSource {
  final Dio _dio;
  
  Future<PrayerTimesModel> getPrayerTimes({
    required double latitude,
    required double longitude,
    required int method,
    required String location,
    String? date,
  }) async {
    try {
      final response = await _dio.get('/timings', queryParameters: {...});
      // Parse and return model
    } catch (e) {
      throw RemoteException(message: 'Failed to fetch prayer times');
    }
  }
}
```

**Local Data Source (Hive cache)**:
```dart
class PrayerTimesLocalDataSource {
  Future<void> cachePrayerTimes(PrayerTimesModel prayerTimes) async {
    final box = await Hive.openBox('prayer_times_cache');
    await box.put('cached', prayerTimes.toJson());
  }
  
  Future<PrayerTimesModel?> getCachedPrayerTimes() async {
    final box = await Hive.openBox('prayer_times_cache');
    final cached = box.get('cached');
    if (cached == null) return null;
    return PrayerTimesModel.fromJson(cached);
  }
}
```

**Characteristics**:
- Concrete implementations (not abstract)
- Handle network/database access
- Throw specific exceptions (RemoteException, CacheException)
- Perform data transformation

#### 2.2 Models
Maps entities with JSON serialization for persistence.

```dart
class PrayerTimesModel extends PrayerTimesEntity {
  const PrayerTimesModel({
    required List<PrayerEntity> prayers,
    required HijriDateEntity hijriDate,
    // ... other properties
  }) : super(
    prayers: prayers,
    hijriDate: hijriDate,
    // ...
  );
  
  factory PrayerTimesModel.fromJson(Map<String, dynamic> json) {
    return PrayerTimesModel(
      prayers: (json['prayers'] as List)
          .map((p) => PrayerEntity(...))
          .toList(),
      // ... deserialize other fields
    );
  }
  
  Map<String, dynamic> toJson() => {
    'prayers': prayers.map((p) => {...}).toList(),
    // ... serialize other fields
  };
}
```

**Characteristics**:
- Extend domain entities
- Add JSON serialization
- Add factory constructors for API/cache parsing
- Can include API-specific transformation logic

#### 2.3 Repository Implementation
Combines data sources and implements repository interface.

```dart
class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  final PrayerTimesRemoteDataSource remoteDataSource;
  final PrayerTimesLocalDataSource localDataSource;
  
  @override
  Future<Either<Failure, PrayerTimesEntity>> getPrayerTimes({
    required double latitude,
    required double longitude,
    int method = 3,
    String? date,
  }) async {
    try {
      // 1. Try remote API
      final remoteModel = await remoteDataSource.getPrayerTimes(
        latitude: latitude,
        longitude: longitude,
        method: method,
        location: 'User Location',
        date: date,
      );
      
      // 2. Cache the result
      await localDataSource.cachePrayerTimes(remoteModel);
      
      // 3. Return success
      return Right(remoteModel);
    } on RemoteException catch (e) {
      // 4. On API error, try cache
      final cached = await localDataSource.getCachedPrayerTimes();
      if (cached != null) {
        return Right(cached);  // Use cache as fallback
      }
      
      // 5. If both fail, map to domain failure
      return Left(_mapRemoteExceptionToFailure(e));
    }
  }
  
  Failure _mapRemoteExceptionToFailure(RemoteException e) {
    if (e.statusCode == null) {
      return NetworkFailure(message: e.message);
    }
    // ... handle other cases
  }
}
```

**Characteristics**:
- Implements abstract repository from Domain
- Combines remote and local data sources
- Handles errors and maps to domain failures
- Contains retry/fallback logic

## Layer 3: Presentation Layer

**Purpose**: Display UI and manage presentation state

**Responsibility**:
- Build and layout UI widgets
- Manage presentation state with Riverpod
- React to user interactions
- Display domain data to user

**Location**: `lib/features/[feature]/presentation/`

### Components

#### 3.1 Providers (Riverpod State Management)
Manage state and provide access to use cases.

```dart
// Provide dependencies
final getPrayerTimesUseCaseProvider = 
    Provider<GetPrayerTimesUseCase>((ref) {
  final repository = ref.watch(prayerTimesRepositoryProvider);
  return GetPrayerTimesUseCase(repository: repository);
});

// Provide async data
final prayerTimesProvider = 
    FutureProvider.family<PrayerTimesEntity, PrayerTimesParams>
        ((ref, params) async {
  final useCase = ref.watch(getPrayerTimesUseCaseProvider);
  final result = await useCase(
    latitude: params.latitude,
    longitude: params.longitude,
    method: params.method,
  );
  
  return result.fold(
    (failure) => throw Exception(failure.message),
    (prayerTimes) => prayerTimes,
  );
});

// Provide mutable state
final themeModeProvider = 
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(prefs: _prefs);
});
```

**Provider Types**:
- `Provider`: Computed/derived values
- `FutureProvider`: Async operations with loading/error states
- `StateNotifierProvider`: Mutable state with custom logic

#### 3.2 Pages (Full-Screen Widgets)
Complete screens of the app.

```dart
class PrayerTimesPage extends ConsumerWidget {
  const PrayerTimesPage({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch provider for reactive updates
    final prayerTimesAsync = ref.watch(
      prayerTimesProvider(params),
    );
    
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Times')),
      body: prayerTimesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (prayerTimes) => _buildPrayerList(prayerTimes),
      ),
    );
  }
  
  Widget _buildPrayerList(PrayerTimesEntity prayerTimes) {
    // Build UI with data
  }
}
```

**Characteristics**:
- Full-screen widget
- Use `ConsumerWidget` to access Riverpod
- Watch providers for reactive state
- Handle loading/error/success states

#### 3.3 Widgets (Reusable Components)
Small, reusable UI components.

```dart
class PrayerTimeCard extends StatelessWidget {
  final PrayerEntity prayer;
  
  const PrayerTimeCard({required this.prayer});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(prayer.name, style: Theme.of(context).textTheme.titleLarge),
            Text(prayer.time),
          ],
        ),
      ),
    );
  }
}
```

**Characteristics**:
- Receive data via constructor parameters
- Don't contain business logic
- Reusable across multiple screens
- Stateless when possible

## Error Handling: Either Pattern

Using `dartz` package's `Either<Failure, Success>` for functional error handling:

```dart
// Either<Left, Right>
// Left = Failure/Error
// Right = Success

Future<Either<Failure, PrayerTimesEntity>> getPrayerTimes(...) async {
  try {
    final data = await fetchFromAPI();
    return Right(data);  // Success
  } catch (e) {
    return Left(NetworkFailure(...));  // Failure
  }
}

// Usage
final result = await useCase.call(...);
result.fold(
  (failure) => print('Error: ${failure.message}'),  // Handle failure
  (success) => print('Success: $success'),          // Handle success
);
```

**Failure Hierarchy**:
```
Failure (abstract)
├── NetworkFailure
├── ServerFailure
├── DataFailure
├── CacheFailure
├── NotFoundFailure
└── UnknownFailure
```

## Data Flow Example: Fetching Prayer Times

```
User taps "Get Prayer Times" button
         ↓
UI (Presentation Layer)
  - PrayerTimesPage.build()
  - Calls: ref.watch(prayerTimesProvider(params))
         ↓
Riverpod Provider (Presentation Layer)
  - prayerTimesProvider
  - Calls: useCase(latitude, longitude, method)
         ↓
Use Case (Domain Layer)
  - GetPrayerTimesUseCase
  - Calls: repository.getPrayerTimes(...)
         ↓
Repository (Data Layer)
  - Implements: PrayerTimesRepository
  - Tries: remoteDataSource.getPrayerTimes()
         ↓
Remote Data Source (Data Layer)
  - Makes HTTP request to Aladhan API
  - Parses response to PrayerTimesModel
  - Returns model
         ↓
Repository catches success:
  - Caches model via localDataSource
  - Returns Right(model) (success)
         ↓
Repository caches data:
  - Stores to Hive box
         ↓
Provider receives Right(model):
  - Returns model to UI
         ↓
UI receives data:
  - Builds prayer list
  - User sees prayer times
```

## Dependency Injection via Riverpod

```dart
// 1. Low-level dependencies
final dioProvider = Provider((ref) => Dio());

// 2. Data sources depend on low-level
final remoteDataSourceProvider = Provider((ref) {
  final dio = ref.watch(dioProvider);
  return PrayerTimesRemoteDataSource(dio: dio);
});

// 3. Repository depends on data sources
final repositoryProvider = Provider((ref) {
  final remote = ref.watch(remoteDataSourceProvider);
  final local = ref.watch(localDataSourceProvider);
  return PrayerTimesRepositoryImpl(
    remoteDataSource: remote,
    localDataSource: local,
  );
});

// 4. Use case depends on repository
final useCaseProvider = Provider((ref) {
  final repository = ref.watch(repositoryProvider);
  return GetPrayerTimesUseCase(repository: repository);
});

// 5. Feature provider depends on use case
final featureProvider = FutureProvider((ref) async {
  final useCase = ref.watch(useCaseProvider);
  return await useCase.call(...);
});
```

## Best Practices

### ✅ Domain Layer
- Keep entities simple and immutable
- No Flutter/external imports
- Define repository interfaces
- Implement use cases
- Use `Either` for error handling

### ✅ Data Layer
- Implement repository from domain
- Keep models tied to API format
- Handle network errors gracefully
- Implement caching strategy
- Transform API data to entities

### ✅ Presentation Layer
- Widgets are "dumb" (receive data via params)
- Riverpod providers manage state
- Use `ConsumerWidget` for Riverpod access
- Handle async states (loading/error/data)
- Keep logic minimal in UI

### ❌ Anti-Patterns to Avoid
- Importing Domain from Data (circular)
- Business logic in Presentation
- Models scattered across layers
- Too much logic in widgets
- Mixing concerns in repositories

## Testing

### Unit Tests (Domain & Data)
```dart
// Domain layer - no mocks needed
test('GetPrayerTimesUseCase returns prayer times', () async {
  final mockRepository = MockPrayerTimesRepository();
  final useCase = GetPrayerTimesUseCase(repository: mockRepository);
  
  final result = await useCase(...);
  
  expect(result, isA<Right>());
});

// Data layer - mock data sources
test('Repository uses cache on API error', () async {
  final mockRemote = MockRemoteDataSource();
  final mockLocal = MockLocalDataSource();
  final repository = PrayerTimesRepositoryImpl(
    remoteDataSource: mockRemote,
    localDataSource: mockLocal,
  );
  
  mockRemote.throwException();
  mockLocal.returnCachedData();
  
  final result = await repository.getPrayerTimes(...);
  
  expect(result, isA<Right>());
});
```

### Widget Tests (Presentation)
```dart
testWidgets('Shows loading then data', (WidgetTester tester) async {
  await tester.pumpWidget(TestApp(
    prayerTimesProvider: mockAsyncProvider,
  ));
  
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  
  await tester.pump();
  
  expect(find.byType(PrayerTimeCard), findsWidgets);
});
```

---

**Remember**: Clean Architecture is about making code flexible, maintainable, and testable by respecting layer boundaries and managing dependencies correctly.
