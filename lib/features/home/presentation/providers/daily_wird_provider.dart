import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/azkar_data_service.dart';
import '../../../azkar/data/azkar_progress_store.dart';
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

/// How many phrases make up a full round of tasbeeh; matches the counter.
const int _tasbeehPhrases = 6;

/// Builds today's wird from the reading log and the azkar progress.
final dailyWirdProvider = FutureProvider<DailyWird>((ref) async {
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
        // This used to report the full total once the clock passed noon,
        // whatever the user had actually recited — so the card read 31/31
        // while the chapter itself held two or three ticks. Report what was
        // done; the hour decides whether it is still due, not whether it
        // counts as finished.
        done: progress.completedCount,
        target: progress.totalCount,
        category: morning,
        dueNow: isMorning,
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

  // The tasbeeh line reads the counter itself, so counting on the beads and
  // counting in the wird are the same act. They used to be two separate
  // stores, and thirty-three on one showed as nothing on the other.
  final prefs = await SharedPreferences.getInstance();
  final tasbeehDone = TasbeehStore.roundsCompleted(prefs, _tasbeehPhrases);
  tasks.add(
    WirdTask(
      id: 'tasbeeh',
      titleKey: 'wird_tasbeeh',
      done: tasbeehDone,
      target: _tasbeehPhrases,
      category: _findCategory(categories, 'tasbeeh', 'تسبيح'),
    ),
  );

  return DailyWird(tasks: tasks);
});

Future<List<AzkarCategory>> _azkarCategories(Ref ref) async {
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
