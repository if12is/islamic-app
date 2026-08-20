import 'dart:convert';

/// A plan to finish the Mushaf in a set number of days.
///
/// The plan stores only the intent (when it started and how long it should
/// take); progress is measured from the reading log, so a day spent reading
/// counts whether or not the user remembered to "mark" anything.
class KhatmahPlan {
  const KhatmahPlan({
    required this.startDate,
    required this.days,
    this.completedAt,
  });

  /// Total pages in the standard Mushaf.
  static const int totalPages = 604;

  final DateTime startDate;

  /// How many days the reader gave themselves.
  final int days;

  final DateTime? completedAt;

  bool get isComplete => completedAt != null;

  /// Even split, rounded up — the plain daily portion.
  int get pagesPerDay => (totalPages / days).ceil();

  DateTime get endDate =>
      DateTime(startDate.year, startDate.month, startDate.day + days - 1);

  /// 1 on the first day of the plan.
  int dayNumber(DateTime today) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final now = DateTime(today.year, today.month, today.day);
    return now.difference(start).inDays + 1;
  }

  int daysRemaining(DateTime today) {
    final remaining = days - dayNumber(today) + 1;
    return remaining < 0 ? 0 : remaining;
  }

  /// Where the reader should be by the end of today if they never slipped.
  int expectedPages(DateTime today) {
    final elapsed = dayNumber(today).clamp(0, days);
    return (pagesPerDay * elapsed).clamp(0, totalPages).toInt();
  }

  /// Today's portion, re-spread over the days that are left.
  ///
  /// Falling behind makes tomorrow slightly bigger instead of leaving an
  /// impossible pile at the end; being ahead makes it smaller.
  int todayTarget(DateTime today, int pagesRead) {
    final remainingPages = totalPages - pagesRead;
    if (remainingPages <= 0) {
      return 0;
    }

    final remainingDays = daysRemaining(today);
    if (remainingDays <= 1) {
      return remainingPages;
    }
    return (remainingPages / remainingDays).ceil();
  }

  /// Positive when ahead of schedule, negative when behind.
  int pagesAhead(DateTime today, int pagesRead) =>
      pagesRead - expectedPages(today);

  double progress(int pagesRead) =>
      (pagesRead / totalPages).clamp(0.0, 1.0).toDouble();

  KhatmahPlan copyWith({
    DateTime? startDate,
    int? days,
    DateTime? completedAt,
  }) {
    return KhatmahPlan(
      startDate: startDate ?? this.startDate,
      days: days ?? this.days,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso8601String(),
    'days': days,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  factory KhatmahPlan.fromJson(Map<dynamic, dynamic> json) {
    final start = DateTime.tryParse(json['startDate'] as String? ?? '');
    final days = (json['days'] as num?)?.toInt() ?? 30;
    return KhatmahPlan(
      startDate: start ?? DateTime.now(),
      days: days.clamp(1, 365),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
    );
  }

  static KhatmahPlan? decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? KhatmahPlan.fromJson(decoded) : null;
    } catch (_) {
      return null;
    }
  }
}
