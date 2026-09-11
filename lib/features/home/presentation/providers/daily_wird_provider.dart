import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/azkar_data_service.dart';
import '../../../azkar/data/azkar_progress_store.dart';
import '../../../azkar/data/tasbeeh_link.dart';
import '../../../azkar/data/tasbeeh_store.dart';
import '../../../azkar/data/models/azkar_models.dart';
import '../../../quran/presentation/providers/reading_progress_provider.dart';

/// One line of the daily wird.
class WirdTask {
  const WirdTask({
    required this.id,
    required this.titleKey,
    required this.done,
    required this.target,
    this.category,
    this.dueNow = true,
  });

  final String id;
  final String titleKey;
  final int done;
  final int target;

  /// The azkar chapter this task opens, when it has one.
  final AzkarCategory? category;

  /// Whether this portion is due at this hour. Evening azkar in the morning
  /// are not late, they are simply not yet due.
  final bool dueNow;

  bool get isComplete => target > 0 && done >= target;

  double get progress =>
      target <= 0 ? 0 : (done / target).clamp(0.0, 1.0).toDouble();
}

/// The day's portion across the Quran, the azkar, and the tasbeeh.
class DailyWird {
  const DailyWird({required this.tasks});

  final List<WirdTask> tasks;

  /// Only what is due at this hour counts towards the day's ring; the evening
  /// azkar should not drag the morning's progress down.
  List<WirdTask> get dueTasks => tasks.where((task) => task.dueNow).toList();

  int get completed => dueTasks.where((task) => task.isComplete).length;

  int get total => dueTasks.length;

  bool get isComplete => total > 0 && completed == total;

  double get progress {
    final due = dueTasks;
    if (due.isEmpty) {
      return 0;
    }
    final sum = due.fold<double>(0, (value, task) => value + task.progress);
    return sum / due.length;
  }

  static const DailyWird empty = DailyWird(tasks: []);
}

/// Pages a day when no khatmah plan is running — a gentle default.
const int _defaultDailyPages = 4;

/// How many phrases the misbaha holds, for a dataset with no tasbeeh chapter.
const int _misbahaPhrases = 6;

/// Builds today's wird from the reading log and the azkar progress.
final dailyWirdProvider = FutureProvider<DailyWird>((ref) async {
  // Any count written anywhere — a chapter's screen, the misbaha — moves the
  // card, rather than it waiting for someone to reopen the tab.
  void reread() => ref.invalidateSelf();
  AzkarProgressStore.revision.addListener(reread);
  ref.onDispose(() => AzkarProgressStore.revision.removeListener(reread));

  final summary = await ref.watch(readingProgressProvider.future);
  final plan = ref.watch(khatmahPlanProvider);

  final quranTarget =
      plan == null || plan.isComplete
          ? _defaultDailyPages
          : plan.todayTarget(DateTime.now(), summary.planPagesRead);

  final tasks = <WirdTask>[
    WirdTask(
      id: 'quran',
      titleKey: 'wird_quran',
      done: summary.today.pageCount,
      target: quranTarget == 0 ? _defaultDailyPages : quranTarget,
    ),
  ];

  final categories = await _azkarCategories(ref);
  final now = DateTime.now();
  final isMorning = now.hour < 12;

  final morning = _findCategory(categories, 'morning', 'صباح');
  if (morning != null) {
    final progress = await AzkarProgressStore.progressFor(morning);
    tasks.add(
      WirdTask(
        id: 'morning',
        titleKey: 'wird_morning_azkar',
        // Morning azkar stay due until midnight. They used to drop off the
        // card at noon, which read as "the window closed" and — with the
        // old AM/PM session key — wiped the count when Dhuhr arrived.
        done: progress.completedCount,
        target: progress.totalCount,
        category: morning,
        dueNow: true,
      ),
    );
  }

  final evening = _findCategory(categories, 'evening', 'مساء');
  if (evening != null) {
    final progress = await AzkarProgressStore.progressFor(evening);
    tasks.add(
      WirdTask(
        id: 'evening',
        titleKey: 'wird_evening_azkar',
        done: progress.completedCount,
        target: progress.totalCount,
        category: evening,
        dueNow: !isMorning,
      ),
    );
  }

  // The tasbeeh line counts the chapter it opens. It used to count the
  // misbaha's six phrases while opening a list of seven, so finishing every
  // line of that list still read "0/6". The misbaha feeds this chapter now
  // for the phrases the two share (see TasbeehLink), so the beads still count.
  //
  // Matched on the id alone: a name search for "تسبيح" lands on the travel
  // chapter, "التكبير و التسبيح في سير السفر", which comes first.
  final tasbeeh = _findById(categories, TasbeehLink.wirdCategoryId);
  if (tasbeeh != null && tasbeeh.azkar.isNotEmpty) {
    final progress = await AzkarProgressStore.progressFor(tasbeeh);
    tasks.add(
      WirdTask(
        id: 'tasbeeh',
        titleKey: 'wird_tasbeeh',
        done: progress.completedCount,
        target: progress.totalCount,
        category: tasbeeh,
      ),
    );
  } else {
    final prefs = await SharedPreferences.getInstance();
    tasks.add(
      WirdTask(
        id: 'tasbeeh',
        titleKey: 'wird_tasbeeh',
        done: TasbeehStore.roundsCompleted(prefs, _misbahaPhrases),
        target: _misbahaPhrases,
      ),
    );
  }

  return DailyWird(tasks: tasks);
});

/// The Hisn, parsed once. The card re-reads its counts on every change, and
/// three hundred supplications do not need decoding again each time.
Future<List<AzkarCategory>>? _categoriesCache;

Future<List<AzkarCategory>> _azkarCategories(Ref ref) async {
  final cached = _categoriesCache ??= _loadCategories();
  try {
    return await cached;
  } catch (_) {
    _categoriesCache = null;
    rethrow;
  }
}

AzkarCategory? _findById(List<AzkarCategory> categories, String id) {
  for (final category in categories) {
    if (category.id == id) {
      return category;
    }
  }
  return null;
}

Future<List<AzkarCategory>> _loadCategories() async {
  final data = await AzkarDataService().loadAzkarData();
  final raw = data['categories'] as List? ?? const [];

  return raw.whereType<Map>().map((entry) {
    final items = entry['azkar'] as List? ?? const [];
    return AzkarCategory(
      id: entry['id']?.toString() ?? '',
      nameAr: entry['nameAr']?.toString() ?? '',
      nameEn: entry['nameEn']?.toString() ?? '',
      azkar:
          items.whereType<Map>().map((item) {
            return ZekrItem(
              id: (item['id'] as num?)?.toInt() ?? 0,
              textAr: item['textAr']?.toString() ?? '',
              textEn: item['textEn']?.toString() ?? '',
              targetCount: (item['count'] as num?)?.toInt() ?? 1,
              virtue: item['virtue']?.toString() ?? '',
              reference: item['reference']?.toString() ?? '',
            );
          }).toList(),
    );
  }).toList();
}

/// Datasets label chapters differently, so match on id first, then on name.
AzkarCategory? _findCategory(
  List<AzkarCategory> categories,
  String id,
  String keyword,
) {
  for (final category in categories) {
    if (category.id == id) {
      return category;
    }
  }
  for (final category in categories) {
    if (category.nameAr.contains(keyword)) {
      return category;
    }
  }
  return null;
}
