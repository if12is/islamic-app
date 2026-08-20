/// How well a review went.
enum HifzGrade {
  /// Forgotten — start the interval over.
  again,

  /// Recalled with effort — advance one step.
  good,

  /// Effortless — skip a step.
  easy,
}

/// A passage the reader is memorising, with its review schedule.
///
/// Spacing follows a simple boxed SM-2: each success moves the passage to a
/// longer interval, a lapse sends it back to the start. Simple beats clever
/// here — what matters is that a passage comes back before it fades.
class HifzItem {
  const HifzItem({
    required this.surahNumber,
    required this.fromAyah,
    required this.toAyah,
    required this.addedAt,
    required this.dueDate,
    this.box = 0,
    this.reviews = 0,
    this.lapses = 0,
  });

  /// Days between reviews for each box.
  static const List<int> intervals = [1, 2, 4, 7, 15, 30, 60];

  final int surahNumber;
  final int fromAyah;
  final int toAyah;
  final DateTime addedAt;
  final DateTime dueDate;

  /// Index into [intervals].
  final int box;

  final int reviews;
  final int lapses;

  String get key => '$surahNumber:$fromAyah-$toAyah';

  int get verseCount => toAyah - fromAyah + 1;

  bool isDue(DateTime now) => !_dateOnly(dueDate).isAfter(_dateOnly(now));

  /// How firmly it is held: 0 at the start, 1 at the longest interval.
  double get strength => (box / (intervals.length - 1)).clamp(0.0, 1.0);

  /// Apply a grade and schedule the next review.
  HifzItem review(HifzGrade grade, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());

    final nextBox = switch (grade) {
      HifzGrade.again => 0,
      HifzGrade.good => (box + 1).clamp(0, intervals.length - 1),
      HifzGrade.easy => (box + 2).clamp(0, intervals.length - 1),
    };

    return copyWith(
      box: nextBox,
      reviews: reviews + 1,
      lapses: grade == HifzGrade.again ? lapses + 1 : lapses,
      dueDate: DateTime(
        today.year,
        today.month,
        today.day + intervals[nextBox],
      ),
    );
  }

  HifzItem copyWith({int? box, DateTime? dueDate, int? reviews, int? lapses}) {
    return HifzItem(
      surahNumber: surahNumber,
      fromAyah: fromAyah,
      toAyah: toAyah,
      addedAt: addedAt,
      dueDate: dueDate ?? this.dueDate,
      box: box ?? this.box,
      reviews: reviews ?? this.reviews,
      lapses: lapses ?? this.lapses,
    );
  }

  Map<String, dynamic> toJson() => {
    'surahNumber': surahNumber,
    'fromAyah': fromAyah,
    'toAyah': toAyah,
    'addedAt': addedAt.toIso8601String(),
    'dueDate': dueDate.toIso8601String(),
    'box': box,
    'reviews': reviews,
    'lapses': lapses,
  };

  factory HifzItem.fromJson(Map<dynamic, dynamic> json) {
    final now = DateTime.now();
    return HifzItem(
      surahNumber: (json['surahNumber'] as num?)?.toInt() ?? 1,
      fromAyah: (json['fromAyah'] as num?)?.toInt() ?? 1,
      toAyah: (json['toAyah'] as num?)?.toInt() ?? 1,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? now,
      dueDate: DateTime.tryParse(json['dueDate'] as String? ?? '') ?? now,
      box: (json['box'] as num?)?.toInt() ?? 0,
      reviews: (json['reviews'] as num?)?.toInt() ?? 0,
      lapses: (json['lapses'] as num?)?.toInt() ?? 0,
    );
  }

  /// A freshly added passage is due the same day.
  factory HifzItem.fresh({
    required int surahNumber,
    required int fromAyah,
    required int toAyah,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    return HifzItem(
      surahNumber: surahNumber,
      fromAyah: fromAyah,
      toAyah: toAyah,
      addedAt: today,
      dueDate: today,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
