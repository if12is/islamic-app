import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/services/notification_scheduler.dart';
import '../../../../core/services/travel_store.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../domain/travel.dart';

class TravelController extends Notifier<TravelSettings> {
  @override
  TravelSettings build() => TravelStore.read(appPreferences);

  void _reload() {
    state = TravelStore.read(appPreferences);
  }

  Future<void> setTravelling(bool value) async {
    await TravelStore.setTravelling(appPreferences, value);
    _reload();
  }

  Future<void> setThreshold(double kilometres) async {
    await TravelStore.setThreshold(appPreferences, kilometres);
    _reload();
  }

  /// Make wherever the user is now the place they are measured from.
  Future<void> setHomeToCurrent() async {
    final coordinates = await ref.read(
      currentLocationCoordinatesProvider.future,
    );
    final label = await ref.read(locationLabelProvider.future);

    await TravelStore.setHome(
      appPreferences,
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      label: label,
    );
    _reload();
  }

  /// Fill in a home the first time there is a location to take one from.
  Future<void> adoptHomeIfUnset() async {
    if (state.hasHome) {
      return;
    }
    final coordinates = await ref.read(
      currentLocationCoordinatesProvider.future,
    );
    final label = await ref.read(locationLabelProvider.future);

    final adopted = await TravelStore.adoptHomeIfUnset(
      appPreferences,
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      label: label,
    );
    if (adopted) {
      _reload();
    }
  }

  /// Note that this place has been raised with the user, so it is not raised
  /// again while they stay there.
  Future<void> markAsked(double latitude, double longitude) async {
    await TravelStore.markAsked(
      appPreferences,
      latitude: latitude,
      longitude: longitude,
    );
    _reload();
  }

  /// Recalculate for where the user actually is, and re-arm the reminders.
  ///
  /// A pinned place is released as part of this: someone who pinned their home
  /// city months ago and has now flown somewhere else is asking for the times
  /// here, and leaving the pin on would silently ignore the answer they just
  /// gave.
  Future<void> adoptCurrentLocation() async {
    await LocationService.useAutomatic(appPreferences);
    await LocationService.clearLabel(appPreferences);
    ref.invalidate(currentLocationCoordinatesProvider);
    ref.invalidate(locationLabelProvider);
    await NotificationScheduler.refresh(preferences: appPreferences);
  }
}

final travelProvider = NotifierProvider<TravelController, TravelSettings>(
  TravelController.new,
);

/// How far the user is from home right now.
final travelAssessmentProvider = Provider<TravelAssessment>((ref) {
  final settings = ref.watch(travelProvider);
  final coordinates = ref.watch(currentLocationCoordinatesProvider).value;

  if (coordinates == null) {
    return TravelAssessment(
      distanceKm: 0,
      thresholdKm: settings.thresholdKm,
      hasHome: settings.hasHome,
    );
  }

  return TravelAssessment.from(
    homeLatitude: settings.homeLatitude,
    homeLongitude: settings.homeLongitude,
    currentLatitude: coordinates.latitude,
    currentLongitude: coordinates.longitude,
    thresholdKm: settings.thresholdKm,
  );
});

/// Where the device says it is, ignoring any pinned place.
///
/// [currentLocationCoordinatesProvider] answers with the pin when one is set,
/// which is right for calculating times and useless for noticing that the pin
/// has been left behind in another country. This asks the hardware directly,
/// and only ever uses the fix the OS already has — a cold GPS lock is not
/// worth waiting for to answer a question nobody asked yet.
final deviceCoordinatesProvider = FutureProvider<Position?>((ref) async {
  if (kIsWeb) {
    return null;
  }
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return null;
    }
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      // Never prompt from here. A permission dialog raised by a background
      // check is a dialog with no explanation attached to it.
      return null;
    }
    return await Geolocator.getLastKnownPosition();
  } catch (e) {
    AppLogger.warning('No device fix for the travel check: $e');
    return null;
  }
});

/// What, if anything, is worth saying about where the user is.
enum LocationNudge {
  none,

  /// A place was pinned by hand, and the phone is now a long way from it — so
  /// the times on screen are another city's.
  pinnedElsewhere,

  /// The times are right, but the distance from home has passed the threshold
  /// the user set, which is worth mentioning once.
  farFromHome,
}

/// Whether to raise the "you seem to have moved" question, and which one.
///
/// The comparison is against home and against the pin, never against the last
/// fix. A journey made in stages never trips a last-fix comparison: every leg
/// is short, so the app arrives in another country still convinced it has not
/// gone anywhere.
final locationNudgeProvider = Provider<LocationNudge>((ref) {
  final settings = ref.watch(travelProvider);
  final device = ref.watch(deviceCoordinatesProvider).value;
  if (device == null) {
    return LocationNudge.none;
  }

  final pinned = ref.watch(locationIsManualProvider);
  final calculatingFor = ref.watch(currentLocationCoordinatesProvider).value;

  // A pin left behind is the one that actually shows wrong times, so it is
  // asked about first and regardless of whether travel mode is on.
  if (pinned && calculatingFor != null) {
    final stale = CityChangeWatch.shouldAsk(
      calculatingForLatitude: calculatingFor.latitude,
      calculatingForLongitude: calculatingFor.longitude,
      currentLatitude: device.latitude,
      currentLongitude: device.longitude,
      lastAskedLatitude: settings.askedLatitude,
      lastAskedLongitude: settings.askedLongitude,
    );
    if (stale) {
      return LocationNudge.pinnedElsewhere;
    }
  }

  if (settings.travelling || !settings.hasHome) {
    return LocationNudge.none;
  }

  final away = TravelAssessment.from(
    homeLatitude: settings.homeLatitude,
    homeLongitude: settings.homeLongitude,
    currentLatitude: device.latitude,
    currentLongitude: device.longitude,
    thresholdKm: settings.thresholdKm,
  );
  if (!away.beyondThreshold) {
    return LocationNudge.none;
  }

  final worthAsking = CityChangeWatch.shouldAsk(
    calculatingForLatitude: settings.homeLatitude,
    calculatingForLongitude: settings.homeLongitude,
    currentLatitude: device.latitude,
    currentLongitude: device.longitude,
    lastAskedLatitude: settings.askedLatitude,
    lastAskedLongitude: settings.askedLongitude,
    significantDistanceKm: settings.thresholdKm,
  );

  return worthAsking ? LocationNudge.farFromHome : LocationNudge.none;
});
