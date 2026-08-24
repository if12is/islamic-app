import 'package:shared_preferences/shared_preferences.dart';

/// How a prayer was performed.
enum PrayerRecord {
  /// Not recorded either way yet.
  none,

  /// In congregation, at the mosque.
  mosque,

  /// In congregation, elsewhere — at home, at work.
  congregation,

  /// Alone, on time.
  alone,

  /// Made up after its time had passed.
  missed,
}

extension PrayerRecordX on PrayerRecord {
  /// Whether this counts as prayed at all.
  bool get isPrayed => this != PrayerRecord.none;

  /// Whether it was in its time. A make-up is still a prayer, and the log
  /// says so rather than scoring it as a failure.
  bool get isOnTime =>
      this == PrayerRecord.mosque ||
      this == PrayerRecord.congregation ||
      this == PrayerRecord.alone;

  bool get isCongregation =>
      this == PrayerRecord.mosque || this == PrayerRecord.congregation;
}

/// A day's five, as recorded.
class PrayerDay {
  const PrayerDay({required this.date, required this.records});

  final DateTime date;

  /// Keyed by the prayer id, e.g. `fajr`.
  final Map<String, PrayerRecord> records;

  PrayerRecord recordFor(String prayerId) =>
      records[prayerId] ?? PrayerRecord.none;

  int get prayed => records.values.where((r) => r.isPrayed).length;
  int get onTime => records.values.where((r) => r.isOnTime).length;
  int get inCongregation =>
      records.values.where((r) => r.isCongregation).length;

  bool get isComplete => onTime == PrayerLogStore.prayerIds.length;
}

/// A running total over a stretch of days.
class PrayerLogSummary {
  const PrayerLogSummary({
    required this.days,
    required this.prayed,
    required this.onTime,
    required this.inCongregation,
    required this.possible,
    required this.streak,
  });

  final int days;
  final int prayed;
  final int onTime;
  final int inCongregation;

  /// Five per day over the window.
  final int possible;

  /// Consecutive days ending today with all five on time.
  final int streak;

  double get onTimeShare => possible == 0 ? 0 : onTime / possible;
  double get congregationShare => onTime == 0 ? 0 : inCongregation / onTime;

  static const PrayerLogSummary empty = PrayerLogSummary(
    days: 0,
    prayed: 0,
    onTime: 0,
    inCongregation: 0,
    possible: 0,
    streak: 0,
  );
}

/// The prayer log: what was prayed, when, and how.
///
/// It records rather than judges. There is no target and no red — a day with
/// two recorded is a day with two recorded, and the summary reports shares
/// instead of ranking the user against anything.
///
/// Stored as one short string per day (`fajr:mosque,dhuhr:alone`) rather than
/// a box per prayer: a year is 365 small keys, which SharedPreferences handles
/// happily and which the backup carries as plain text.
class PrayerLogStore {
  PrayerLogStore._();

  static const String prefix = 'prayer_log_';

  /// The five, in order.
  static const List<String> prayerIds = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];

  static String dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static PrayerDay read(SharedPreferences prefs, DateTime date) {
    final raw = prefs.getString('$prefix${dayKey(date)}') ?? '';
    return PrayerDay(date: date, records: decode(raw));
  }

  static Future<void> set(
    SharedPreferences prefs,
    DateTime date,
    String prayerId,
    PrayerRecord record,
  ) async {
    final day = read(prefs, date);
    final records = Map<String, PrayerRecord>.from(day.records);

    if (record == PrayerRecord.none) {
      records.remove(prayerId);
    } else {
      records[prayerId] = record;
    }

    final key = '$prefix${dayKey(date)}';
    if (records.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, encode(records));
    }
  }

  /// Step a prayer through the options, so one tap is enough to log it.
  static PrayerRecord next(PrayerRecord current) => switch (current) {
    PrayerRecord.none => PrayerRecord.mosque,
    PrayerRecord.mosque => PrayerRecord.congregation,
    PrayerRecord.congregation => PrayerRecord.alone,
    PrayerRecord.alone => PrayerRecord.missed,
    PrayerRecord.missed => PrayerRecord.none,
  };

  /// The last [days] days, newest first.
  static List<PrayerDay> recent(
    SharedPreferences prefs, {
    int days = 30,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    return [
      for (var back = 0; back < days; back++)
        read(prefs, DateTime(today.year, today.month, today.day - back)),
    ];
  }

  static PrayerLogSummary summarise(
    SharedPreferences prefs, {
    int days = 30,
    DateTime? now,
  }) {
    final window = recent(prefs, days: days, now: now);
    if (window.isEmpty) {
      return PrayerLogSummary.empty;
    }

    var prayed = 0;
    var onTime = 0;
    var congregation = 0;
    for (final day in window) {
      prayed += day.prayed;
      onTime += day.onTime;
      congregation += day.inCongregation;
    }

    return PrayerLogSummary(
      days: days,
      prayed: prayed,
      onTime: onTime,
      inCongregation: congregation,
      possible: days * prayerIds.length,
      streak: streakOf(window),
    );
  }

  /// Consecutive complete days, counting back from today.
  ///
  /// Today is skipped when nothing is recorded yet: the day is not over, and
  /// zeroing a streak at dawn would punish someone for waking up.
  static int streakOf(List<PrayerDay> newestFirst) {
    var streak = 0;
    for (var i = 0; i < newestFirst.length; i++) {
      final day = newestFirst[i];
      if (day.isComplete) {
        streak++;
      } else if (i == 0 && day.prayed == 0) {
        continue;
      } else {
        break;
      }
    }
    return streak;
  }

  static String encode(Map<String, PrayerRecord> records) => records.entries
      .map((entry) => '${entry.key}:${entry.value.name}')
      .join(',');

  static Map<String, PrayerRecord> decode(String raw) {
    if (raw.isEmpty) {
      return const {};
    }
    final records = <String, PrayerRecord>{};
    for (final part in raw.split(',')) {
      final pieces = part.split(':');
      if (pieces.length != 2 || !prayerIds.contains(pieces[0])) {
        continue;
      }
      final record = PrayerRecord.values.where((r) => r.name == pieces[1]);
      if (record.isNotEmpty && record.first != PrayerRecord.none) {
        records[pieces[0]] = record.first;
      }
    }
    return records;
  }
}
