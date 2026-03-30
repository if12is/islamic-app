import 'package:equatable/equatable.dart';

/// Represents a single prayer time.
/// 
/// This entity contains the prayer name and its time for a given day.
class PrayerEntity extends Equatable {
  /// The name of the prayer (Fajr, Dhuhr, Asr, Maghrib, Isha)
  final String name;
  
  /// The time of the prayer in HH:mm format
  final String time;
  
  /// Whether this prayer has passed for the day
  final bool hasPassed;

  const PrayerEntity({
    required this.name,
    required this.time,
    this.hasPassed = false,
  });

  @override
  List<Object?> get props => [name, time, hasPassed];
}

/// Represents all prayer times for a given day.
/// 
/// This is the main entity returned by the Prayer Times use case.
class PrayerTimesEntity extends Equatable {
  /// List of all prayers for the day
  final List<PrayerEntity> prayers;
  
  /// The Hijri date information
  final HijriDateEntity hijriDate;
  
  /// The Gregorian date (YYYY-MM-DD format)
  final String gregorianDate;
  
  /// City or location name
  final String location;
  
  /// Latitude of the location
  final double latitude;
  
  /// Longitude of the location
  final double longitude;

  const PrayerTimesEntity({
    required this.prayers,
    required this.hijriDate,
    required this.gregorianDate,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [
    prayers,
    hijriDate,
    gregorianDate,
    location,
    latitude,
    longitude,
  ];
}

/// Represents the Hijri (Islamic) date.
/// 
/// The Islamic calendar is lunar-based and is fundamental to Islamic practices.
class HijriDateEntity extends Equatable {
  /// The Hijri day (1-30)
  final int day;
  
  /// The Hijri month (1-12)
  final int month;
  
  /// The Hijri year
  final int year;
  
  /// The name of the month in English
  final String monthName;
  
  /// The designation of the year (AH - After Hijra)
  final String monthArabic;

  const HijriDateEntity({
    required this.day,
    required this.month,
    required this.year,
    required this.monthName,
    required this.monthArabic,
  });

  @override
  List<Object?> get props => [day, month, year, monthName, monthArabic];
  
  /// Returns formatted Hijri date as "day monthName year AH"
  String get formattedDate => '$day $monthName $year هـ';
}
