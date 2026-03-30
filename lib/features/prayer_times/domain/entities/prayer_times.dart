class PrayerTimesEntity {
  final Map<String, String> timings;
  final String dateReadable;
  final String hijriDate;

  PrayerTimesEntity({
    required this.timings,
    required this.dateReadable,
    required this.hijriDate,
  });
}
