import 'package:shared_preferences/shared_preferences.dart';

import '../../features/prayer_times/domain/travel.dart';

/// Where home is, and whether the user has said they are away from it.
class TravelSettings {
  const TravelSettings({
    this.homeLatitude,
    this.homeLongitude,
    this.homeLabel = '',
    this.travelling = false,
    this.thresholdKm = TravelDistance.defaultThresholdKm,
    this.startedAt,
    this.askedLatitude,
    this.askedLongitude,
  });

  final double? homeLatitude;
  final double? homeLongitude;
  final String homeLabel;

  /// Set by the user, never by a sensor.
  ///
  /// Distance can be measured; the intention to travel and the intention to
  /// stay cannot, and both decide the ruling. So the app measures, says what
  /// it measured, and leaves the switch to the person it belongs to.
  final bool travelling;

  final double thresholdKm;

  /// When travel was switched on, so the screen can mention the four-day
  /// question rather than letting a journey quietly last a month.
  final DateTime? startedAt;

  /// The last place a "you seem to have moved" question was raised about.
  final double? askedLatitude;
  final double? askedLongitude;

  bool get hasHome => homeLatitude != null && homeLongitude != null;

  /// Whole days since travel began, or null when it has not.
  int? get daysAway {
    final start = startedAt;
    if (start == null) {
      return null;
    }
    return DateTime.now().difference(start).inDays;
  }

  TravelSettings copyWith({
    double? homeLatitude,
    double? homeLongitude,
    String? homeLabel,
    bool? travelling,
    double? thresholdKm,
    DateTime? startedAt,
    double? askedLatitude,
    double? askedLongitude,
    bool clearStartedAt = false,
  }) {
    return TravelSettings(
      homeLatitude: homeLatitude ?? this.homeLatitude,
      homeLongitude: homeLongitude ?? this.homeLongitude,
      homeLabel: homeLabel ?? this.homeLabel,
      travelling: travelling ?? this.travelling,
      thresholdKm: thresholdKm ?? this.thresholdKm,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      askedLatitude: askedLatitude ?? this.askedLatitude,
      askedLongitude: askedLongitude ?? this.askedLongitude,
    );
  }
}

/// Reads and writes the travel settings.
class TravelStore {
  TravelStore._();

  static const String homeLatitudeKey = 'travel_home_lat';
  static const String homeLongitudeKey = 'travel_home_lon';
  static const String homeLabelKey = 'travel_home_label';
  static const String travellingKey = 'travel_on';
  static const String thresholdKey = 'travel_threshold_km';
  static const String startedAtKey = 'travel_started_at';
  static const String askedLatitudeKey = 'travel_asked_lat';
  static const String askedLongitudeKey = 'travel_asked_lon';

  static TravelSettings read(SharedPreferences prefs) {
    final startedAt = prefs.getInt(startedAtKey);

    return TravelSettings(
      homeLatitude: prefs.getDouble(homeLatitudeKey),
      homeLongitude: prefs.getDouble(homeLongitudeKey),
      homeLabel: prefs.getString(homeLabelKey) ?? '',
      travelling: prefs.getBool(travellingKey) ?? false,
      thresholdKm: TravelDistance.sanitize(
        prefs.getDouble(thresholdKey) ?? TravelDistance.defaultThresholdKm,
      ),
      startedAt:
          startedAt == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(startedAt),
      askedLatitude: prefs.getDouble(askedLatitudeKey),
      askedLongitude: prefs.getDouble(askedLongitudeKey),
    );
  }

  static Future<void> setHome(
    SharedPreferences prefs, {
    required double latitude,
    required double longitude,
    required String label,
  }) async {
    await prefs.setDouble(homeLatitudeKey, latitude);
    await prefs.setDouble(homeLongitudeKey, longitude);
    await prefs.setString(homeLabelKey, label);
  }

  /// Adopt the current place as home the first time there is one to adopt.
  ///
  /// Without this the feature would sit inert until someone found the button,
  /// and the one thing it needs — a place to measure from — is something the
  /// app already knows. It only ever fills a blank: an existing home is never
  /// overwritten by a fix taken mid-journey, which would quietly make the
  /// traveller a resident of wherever they happened to open the app.
  static Future<bool> adoptHomeIfUnset(
    SharedPreferences prefs, {
    required double latitude,
    required double longitude,
    required String label,
  }) async {
    if (prefs.getDouble(homeLatitudeKey) != null) {
      return false;
    }
    await setHome(
      prefs,
      latitude: latitude,
      longitude: longitude,
      label: label,
    );
    return true;
  }

  static Future<void> setTravelling(
    SharedPreferences prefs,
    bool value, {
    DateTime? now,
  }) async {
    await prefs.setBool(travellingKey, value);
    if (value) {
      await prefs.setInt(
        startedAtKey,
        (now ?? DateTime.now()).millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(startedAtKey);
    }
  }

  static Future<void> setThreshold(
    SharedPreferences prefs,
    double kilometres,
  ) => prefs.setDouble(thresholdKey, TravelDistance.sanitize(kilometres));

  /// Remember that this place has been asked about, so it is not asked again.
  static Future<void> markAsked(
    SharedPreferences prefs, {
    required double latitude,
    required double longitude,
  }) async {
    await prefs.setDouble(askedLatitudeKey, latitude);
    await prefs.setDouble(askedLongitudeKey, longitude);
  }
}
