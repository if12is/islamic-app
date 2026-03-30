import '../../domain/entities/prayer_times_entity.dart';

/// Data model for Prayer Times.
/// 
/// This model extends the [PrayerTimesEntity] and handles JSON serialization/deserialization.
/// It's responsible for mapping between API responses and domain entities.
class PrayerTimesModel extends PrayerTimesEntity {
  const PrayerTimesModel({
    required List<PrayerEntity> prayers,
    required HijriDateEntity hijriDate,
    required String gregorianDate,
    required String location,
    required double latitude,
    required double longitude,
  }) : super(
    prayers: prayers,
    hijriDate: hijriDate,
    gregorianDate: gregorianDate,
    location: location,
    latitude: latitude,
    longitude: longitude,
  );

  /// Create PrayerTimesModel from API response.
  /// 
  /// Parses the Aladhan API response and maps it to our model.
  /// This handles the default Aladhan API response format.
  factory PrayerTimesModel.fromAladhanResponse({
    required Map<String, dynamic> apiResponse,
    required String location,
    required double latitude,
    required double longitude,
  }) {
    try {
      final data = apiResponse['data'] as Map<String, dynamic>? ?? {};
      final timings = data['timings'] as Map<String, dynamic>? ?? {};
      final dateInfo = data['date'] as Map<String, dynamic>? ?? {};
      final gregorian = dateInfo['gregorian'] as Map<String, dynamic>? ?? {};
      final hijri = dateInfo['hijri'] as Map<String, dynamic>? ?? {};

      // Parse prayer times (Aladhan includes times with timezone, clean them up)
      final prayers = <PrayerEntity>[
        _createPrayerEntity('Fajr', timings['Fajr']),
        _createPrayerEntity('Sunrise', timings['Sunrise']),
        _createPrayerEntity('Dhuhr', timings['Dhuhr']),
        _createPrayerEntity('Asr', timings['Asr']),
        _createPrayerEntity('Maghrib', timings['Maghrib']),
        _createPrayerEntity('Isha', timings['Isha']),
      ];

      // Parse Hijri date
      final hijriMonthData = hijri['month'] as Map<String, dynamic>? ?? {};
      final hijriDateEntity = HijriDateEntity(
        day: hijri['date'] as int? ?? 1,
        month: hijri['month']['number'] as int? ?? 1,
        year: hijri['year'] as int? ?? 1,
        monthName: hijriMonthData['en'] as String? ?? '',
        monthArabic: hijriMonthData['ar'] as String? ?? '',
      );

      // Parse Gregorian date
      final gregorianDate = gregorian['date'] as String? ?? '';

      return PrayerTimesModel(
        prayers: prayers,
        hijriDate: hijriDateEntity,
        gregorianDate: gregorianDate,
        location: location,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      throw Exception('Failed to parse prayer times: $e');
    }
  }

  /// Helper method to create a PrayerEntity from prayer time string.
  /// 
  /// Aladhan API returns times like "05:14 (EET)", this extracts just the time.
  static PrayerEntity _createPrayerEntity(String prayerName, dynamic timeValue) {
    String cleanTime = '';
    if (timeValue is String) {
      // Extract time from format "HH:mm (TZ)"
      cleanTime = timeValue.split(' ').first;
    }
    return PrayerEntity(name: prayerName, time: cleanTime);
  }

  /// Convert to JSON for caching purposes.
  Map<String, dynamic> toJson() => {
    'prayers': prayers
        .map((p) => {
          'name': p.name,
          'time': p.time,
          'hasPassed': p.hasPassed,
        })
        .toList(),
    'hijriDate': {
      'day': hijriDate.day,
      'month': hijriDate.month,
      'year': hijriDate.year,
      'monthName': hijriDate.monthName,
      'monthArabic': hijriDate.monthArabic,
    },
    'gregorianDate': gregorianDate,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
  };

  /// Create instance from cached JSON.
  factory PrayerTimesModel.fromJson(Map<String, dynamic> json) {
    return PrayerTimesModel(
      prayers: (json['prayers'] as List?)
              ?.map((p) => PrayerEntity(
                    name: p['name'] as String,
                    time: p['time'] as String,
                    hasPassed: p['hasPassed'] as bool? ?? false,
                  ))
              .toList() ??
          [],
      hijriDate: _parseHijriDate(json['hijriDate']),
      gregorianDate: json['gregorianDate'] as String? ?? '',
      location: json['location'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Helper to parse Hijri date from JSON.
  static HijriDateEntity _parseHijriDate(dynamic hijriJson) {
    if (hijriJson is! Map<String, dynamic>) {
      return const HijriDateEntity(
        day: 1,
        month: 1,
        year: 1,
        monthName: '',
        monthArabic: '',
      );
    }
    return HijriDateEntity(
      day: hijriJson['day'] as int? ?? 1,
      month: hijriJson['month'] as int? ?? 1,
      year: hijriJson['year'] as int? ?? 1,
      monthName: hijriJson['monthName'] as String? ?? '',
      monthArabic: hijriJson['monthArabic'] as String? ?? '',
    );
  }
}

