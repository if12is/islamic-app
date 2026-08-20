import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/azkar_data_service.dart';
import '../../../azkar/data/azkar_progress_store.dart';
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
  });

  final String id;
  final String titleKey;
  final int done;
  final int target;

  /// The azkar chapter this task opens, when it has one.
  final AzkarCategory? category;

  bool get isComplete => target > 0 && done >= target;

  double get progress =>
      target <= 0 ? 0 : (done / target).clamp(0.0, 1.0).toDouble();
}

/// The day's portion across the Quran, the azkar, and the tasbeeh.
class DailyWird {
  const DailyWird({required this.tasks});

  final List<WirdTask> tasks;

  int get completed => tasks.where((task) => task.isComplete).length;

  int get total => tasks.length;

  bool get isComplete => total > 0 && completed == total;

  double get progress {
    if (tasks.isEmpty) {
      return 0;
    }
    final sum = tasks.fold<double>(0, (value, task) => value + task.progress);
    return sum / tasks.length;
  }

  static const DailyWird empty = DailyWird(tasks: []);
}

/// Pages a day when no khatmah plan is running — a gentle default.
const int _defaultDailyPages = 4;

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
        done: isMorning ? progress.completedCount : progress.totalCount,
        target: progress.totalCount,
        category: morning,
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
        done: isMorning ? 0 : progress.completedCount,
        target: progress.totalCount,
        category: evening,
      ),
    );
  }

  final tasbeeh = _findCategory(categories, 'tasbeeh', 'تسبيح');
  if (tasbeeh != null) {
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
  }

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
