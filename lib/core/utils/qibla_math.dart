import 'dart:math' as math;

/// The maths behind the compass, kept out of the widget so it can be tested.
class QiblaMath {
  QiblaMath._();

  /// The Kaaba, to five decimals.
  static const double kaabaLatitude = 21.4225;
  static const double kaabaLongitude = 39.8262;

  /// Great-circle bearing from a point to the Kaaba, 0-360 clockwise from
  /// north. Not the straight line on a flat map — on a sphere those differ by
  /// tens of degrees at this distance.
  static double bearingTo({
    required double latitude,
    required double longitude,
  }) {
    final userLat = _radians(latitude);
    final deltaLon = _radians(kaabaLongitude - longitude);
    final kaabaLat = _radians(kaabaLatitude);

    final y = math.sin(deltaLon);
    final x =
        math.cos(userLat) * math.tan(kaabaLat) -
        math.sin(userLat) * math.cos(deltaLon);

    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Distance to the Kaaba in kilometres.
  static double distanceToKaabaKm({
    required double latitude,
    required double longitude,
  }) {
    const earthRadius = 6371.0;
    final dLat = _radians(kaabaLatitude - latitude);
    final dLon = _radians(kaabaLongitude - longitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(latitude)) *
            math.cos(_radians(kaabaLatitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  /// Within this many degrees counts as facing the qibla.
  static const double alignedThreshold = 5;

  /// Beyond this, the phone stays quiet instead of buzzing constantly.
  static const double hapticCutoff = 90;

  /// Degrees between where the phone points and the qibla, 0-180.
  static double difference(double heading, double bearing) {
    var diff = (heading - bearing).abs() % 360;
    if (diff > 180) {
      diff = 360 - diff;
    }
    return diff;
  }

  static bool isAligned(double difference) => difference <= alignedThreshold;

  /// Blend a new compass reading into the old one, the short way around the
  /// circle. Raw readings jitter by several degrees; a shivering needle is
  /// unusable.
  static double smooth(double current, double next, {double factor = 0.18}) {
    var delta = next - current;
    if (delta > 180) {
      delta -= 360;
    } else if (delta < -180) {
      delta += 360;
    }
    final blended = (current + delta * factor) % 360;
    return blended < 0 ? blended + 360 : blended;
  }

  /// How long to wait before the next haptic tap: slow when far, quick when
  /// close, and null once the phone is pointing away from the qibla entirely.
  static Duration? hapticInterval(double difference) {
    if (difference <= alignedThreshold || difference > hapticCutoff) {
      return null;
    }
    return Duration(
      milliseconds: (150 + (difference / hapticCutoff) * 1050).round(),
    );
  }
}
