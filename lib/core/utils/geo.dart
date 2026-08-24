import 'dart:math' as math;

/// Distances and bearings on the sphere.
///
/// Three separate features now need the same two calculations — naming the
/// nearest city, deciding whether someone has travelled far enough to be a
/// traveller, and sorting mosques by how far away they are — so the arithmetic
/// lives in one place rather than being written three times with three chances
/// to get a sign wrong.
class Geo {
  Geo._();

  /// Mean Earth radius. Good to a few metres per kilometre, which is far
  /// finer than a GPS fix and far finer than anything shown on screen.
  static const double earthRadiusKm = 6371.0088;

  /// Great-circle distance in kilometres.
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    final dLat = radians(lat2 - lat1);
    final dLon = radians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radians(lat1)) *
            math.cos(radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double distanceMetres(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) => distanceKm(lat1, lon1, lat2, lon2) * 1000;

  /// Initial bearing from the first point to the second, clockwise from north.
  ///
  /// This is the direction to set off in, not the direction of the straight
  /// line on a flat map — over the few kilometres this is used for they are
  /// the same to within a fraction of a degree.
  static double bearingDegrees(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final phi1 = radians(lat1);
    final phi2 = radians(lat2);
    final dLon = radians(lon2 - lon1);

    final y = math.sin(dLon) * math.cos(phi2);
    final x =
        math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLon);

    return (degrees(math.atan2(y, x)) + 360) % 360;
  }

  /// One of the eight compass points, as an index into a list starting north.
  ///
  /// Sixteen points would be more precise and less useful: "north-northeast"
  /// is not something anyone acts on while walking.
  static int compassOctant(double bearing) {
    final normalized = (bearing % 360 + 360) % 360;
    return ((normalized + 22.5) ~/ 45) % 8;
  }

  static double radians(double value) => value * math.pi / 180;

  static double degrees(double value) => value * 180 / math.pi;
}
