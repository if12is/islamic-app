import '../../../core/services/prayer_calculation_service.dart';
import '../../../core/utils/geo.dart';

/// How a prayer is performed while travelling.
enum TravelPrayerChange {
  /// Four rak'ahs become two.
  shortened,

  /// The count does not change — Fajr is already two, Maghrib stays three.
  unchanged,
}

/// The two prayers that may be joined, and which one they join with.
class JoinPair {
  const JoinPair(this.first, this.second);

  final String first;
  final String second;

  bool contains(String prayerId) => prayerId == first || prayerId == second;

  String? partnerOf(String prayerId) {
    if (prayerId == first) return second;
    if (prayerId == second) return first;
    return null;
  }
}

/// What shortening and joining actually mean, prayer by prayer.
///
/// This is a description of a well-known ruling, not a fatwa: the counts below
/// are not disputed, while *whether someone is a traveller* is a question of
/// distance and intention that the app deliberately leaves to the user.
class TravelRuling {
  TravelRuling._();

  /// Only the four-rak'ah prayers shorten. Fajr is two either way, and Maghrib
  /// is three — it is the witr of the day and is not halved.
  static const List<String> shortened = [
    PrayerIds.dhuhr,
    PrayerIds.asr,
    PrayerIds.isha,
  ];

  /// Joining is between the two pairs, and Fajr joins with nothing.
  static const List<JoinPair> joinPairs = [
    JoinPair(PrayerIds.dhuhr, PrayerIds.asr),
    JoinPair(PrayerIds.maghrib, PrayerIds.isha),
  ];

  /// Rak'ahs at home.
  static int rakaatAtHome(String prayerId) => switch (prayerId) {
    PrayerIds.fajr => 2,
    PrayerIds.maghrib => 3,
    PrayerIds.dhuhr || PrayerIds.asr || PrayerIds.isha => 4,
    _ => 0,
  };

  /// Rak'ahs when shortening.
  static int rakaatTravelling(String prayerId) =>
      shortened.contains(prayerId) ? 2 : rakaatAtHome(prayerId);

  static TravelPrayerChange changeFor(String prayerId) =>
      shortened.contains(prayerId)
          ? TravelPrayerChange.shortened
          : TravelPrayerChange.unchanged;

  /// The prayer this one may be joined with, or null when there is none.
  static String? joinPartner(String prayerId) {
    for (final pair in joinPairs) {
      final partner = pair.partnerOf(prayerId);
      if (partner != null) {
        return partner;
      }
    }
    return null;
  }

  /// The earlier of a joinable pair, which is where a join brought forward
  /// (jam' taqdim) is prayed.
  static bool isFirstOfPair(String prayerId) =>
      joinPairs.any((pair) => pair.first == prayerId);
}

/// Distances at which a journey is customarily treated as travel.
///
/// The commonly cited measure is four burud — sixteen farsakh — which modern
/// conversions put at roughly 83 km, though 88.7 km is also given, and some
/// contemporary scholars go by whether the journey is called travel at all
/// rather than by a number. The default here is the most widely quoted figure
/// and the screen lets it be changed, because picking one number and hiding
/// the disagreement would be presenting a choice as a fact.
class TravelDistance {
  TravelDistance._();

  static const double defaultThresholdKm = 83;

  static const List<double> choices = [60, 83, 88.7, 120];

  static const double minKm = 40;
  static const double maxKm = 200;

  static double sanitize(double value) =>
      value.isNaN ? defaultThresholdKm : value.clamp(minKm, maxKm);
}

/// Where the traveller is relative to where they live.
class TravelAssessment {
  const TravelAssessment({
    required this.distanceKm,
    required this.thresholdKm,
    required this.hasHome,
  });

  /// Straight-line distance from home. The ruling speaks of the distance
  /// travelled by road, which is always longer — so this under-reports rather
  /// than over-reports, and never calls someone a traveller too early.
  final double distanceKm;

  final double thresholdKm;

  /// False until a home has been set, in which case nothing can be judged.
  final bool hasHome;

  bool get beyondThreshold => hasHome && distanceKm >= thresholdKm;

  /// How much further to go before the threshold is reached.
  double get remainingKm =>
      beyondThreshold
          ? 0
          : (thresholdKm - distanceKm).clamp(0, double.infinity);

  static TravelAssessment from({
    required double? homeLatitude,
    required double? homeLongitude,
    required double currentLatitude,
    required double currentLongitude,
    double thresholdKm = TravelDistance.defaultThresholdKm,
  }) {
    if (homeLatitude == null || homeLongitude == null) {
      return TravelAssessment(
        distanceKm: 0,
        thresholdKm: TravelDistance.sanitize(thresholdKm),
        hasHome: false,
      );
    }

    return TravelAssessment(
      distanceKm: Geo.distanceKm(
        homeLatitude,
        homeLongitude,
        currentLatitude,
        currentLongitude,
      ),
      thresholdKm: TravelDistance.sanitize(thresholdKm),
      hasHome: true,
    );
  }
}

/// Whether to raise the question of a changed location, and never more than
/// once for the same place.
///
/// The nagging is the failure mode worth designing against. An app that asks
/// "have you moved?" every time a GPS fix wobbles is one people learn to
/// dismiss without reading, which is exactly when it matters that they read
/// it — so a place that has been asked about is not asked about again until
/// the user has gone somewhere genuinely different.
class CityChangeWatch {
  CityChangeWatch._();

  /// Below this, it is the same place: a fix drifting across a city, or a
  /// commute. Prayer times move by a minute or two over this distance.
  static const double significantKm = 40;

  /// How far from the last place we asked about before it is worth asking
  /// again. Smaller than [significantKm] so that continuing a journey does
  /// raise the question a second time, but large enough that standing still
  /// with a jittery fix does not.
  static const double askAgainKm = 25;

  static bool shouldAsk({
    required double? calculatingForLatitude,
    required double? calculatingForLongitude,
    required double currentLatitude,
    required double currentLongitude,
    double? lastAskedLatitude,
    double? lastAskedLongitude,
    double significantDistanceKm = significantKm,
  }) {
    if (calculatingForLatitude == null || calculatingForLongitude == null) {
      return false;
    }

    final moved = Geo.distanceKm(
      calculatingForLatitude,
      calculatingForLongitude,
      currentLatitude,
      currentLongitude,
    );
    if (moved < significantDistanceKm) {
      return false;
    }

    if (lastAskedLatitude != null && lastAskedLongitude != null) {
      final sinceAsked = Geo.distanceKm(
        lastAskedLatitude,
        lastAskedLongitude,
        currentLatitude,
        currentLongitude,
      );
      if (sinceAsked < askAgainKm) {
        return false;
      }
    }

    return true;
  }
}
