/// What a reader has added to their own daily wird.
///
/// The app already builds a wird for everyone — a few pages, the morning and
/// evening azkar, a round of tasbeeh — and that default is the right thing to
/// meet a new reader with. But a wird is a personal commitment: one person
/// keeps al-Kahf every Friday, another a juz a day through Ramadan, another
/// the same du'a after every prayer. None of that is expressible in a list
/// nobody can add to.
library;

/// The kinds of thing a reader can commit to daily.
enum WirdKind {
  /// A named surah, read in full.
  surah,

  /// One of the thirty ajzaa.
  juz,

  /// A hizb — half a juz.
  hizb,

  /// A quarter of a hizb, which is the smallest unit the Mushaf marks.
  quarter,

  /// A chapter of the azkar.
  azkar,

  /// A phrase repeated a set number of times.
  tasbih,

  /// A du'a from the collection.
  dua,
}

/// One line the reader added to their wird.
class CustomWirdItem {
  const CustomWirdItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.target,
    this.reference,
  });

  /// Stable across restarts, and unique within the wird.
  final String id;

  final WirdKind kind;

  /// What the line is called, in the language it was added in.
  ///
  /// Stored rather than looked up: a surah name resolves from a number, but a
  /// tasbih phrase is whatever the reader chose, and a wird that forgot what
  /// its own lines said would be worse than useless.
  final String title;

  /// How many times a day. One, for anything read rather than counted.
  final int target;

  /// Where the line came from — a surah number, an azkar chapter id, a juz
  /// number. What it means depends on [kind]; it is what lets a tap on the
  /// line open the thing itself instead of a dead end.
  final String? reference;

  CustomWirdItem copyWith({String? title, int? target}) => CustomWirdItem(
    id: id,
    kind: kind,
    title: title ?? this.title,
    target: target ?? this.target,
    reference: reference,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'target': target,
    if (reference != null) 'reference': reference,
  };

  /// Null when the entry cannot be read, so one bad line does not take the
  /// whole wird with it.
  static CustomWirdItem? fromJson(Map<dynamic, dynamic> json) {
    final id = json['id']?.toString();
    final title = json['title']?.toString();
    if (id == null || id.isEmpty || title == null || title.isEmpty) {
      return null;
    }

    final kindName = json['kind']?.toString();
    final kind = WirdKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => WirdKind.azkar,
    );

    final rawTarget = json['target'];
    final target = rawTarget is num ? rawTarget.toInt() : 1;

    return CustomWirdItem(
      id: id,
      kind: kind,
      title: title,
      // A target of zero can never be completed, and a target in the thousands
      // is a typo rather than an intention.
      target: target.clamp(1, 1000),
      reference: json['reference']?.toString(),
    );
  }

  /// The id a line gets when it is added, so adding the same surah twice
  /// replaces rather than duplicates.
  static String idFor(WirdKind kind, String reference) =>
      '${kind.name}:$reference';
}

/// The reader's own wird, and what has been done of it today.
class CustomWird {
  const CustomWird({this.items = const [], this.doneToday = const {}});

  final List<CustomWirdItem> items;

  /// Item id to how many times it has been done today.
  final Map<String, int> doneToday;

  bool get isEmpty => items.isEmpty;

  int doneFor(String id) => doneToday[id] ?? 0;

  bool isComplete(CustomWirdItem item) => doneFor(item.id) >= item.target;

  int get completedCount => items.where(isComplete).length;

  bool contains(WirdKind kind, String reference) {
    final id = CustomWirdItem.idFor(kind, reference);
    return items.any((item) => item.id == id);
  }

  /// How far through the whole custom wird the day is, counting part-done
  /// lines for the part that is done.
  double get progress {
    if (items.isEmpty) {
      return 0;
    }
    final sum = items.fold<double>(0, (value, item) {
      final ratio = item.target <= 0 ? 0.0 : doneFor(item.id) / item.target;
      return value + ratio.clamp(0.0, 1.0);
    });
    return sum / items.length;
  }

  CustomWird copyWith({
    List<CustomWirdItem>? items,
    Map<String, int>? doneToday,
  }) => CustomWird(
    items: items ?? this.items,
    doneToday: doneToday ?? this.doneToday,
  );
}
