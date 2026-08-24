import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/wird_habit_store.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../data/reading_progress_store.dart';
import '../../domain/entities/khatmah_plan.dart';

final readingProgressStoreProvider = Provider<ReadingProgressStore>(
  (ref) => ReadingProgressStore(),
);

/// Everything the stats screen and the wird card need about reading.
class ReadingSummary {
  const ReadingSummary({
    required this.totals,
    required this.days,
    required this.today,
    required this.planPagesRead,
  });

  final ReadingTotals totals;

  /// Every recorded day, oldest first — the heat map's data.
  final List<ReadingDay> days;

  final ReadingDay today;

  /// Distinct pages covered since the current plan started.
  final int planPagesRead;

  static final ReadingSummary empty = ReadingSummary(
    totals: ReadingTotals.empty,
    days: const [],
    today: ReadingDay.empty(DateTime(2000)),
    planPagesRead: 0,
  );
}

/// Reads and writes the reading log.
class ReadingProgressNotifier extends AsyncNotifier<ReadingSummary> {
  ReadingProgressStore get _store => ref.read(readingProgressStoreProvider);

  @override
  Future<ReadingSummary> build() async {
    // Rebuild whenever the plan changes: progress is measured from its start.
    final plan = ref.watch(khatmahPlanProvider);
    return _load(plan);
  }

  Future<ReadingSummary> _load(KhatmahPlan? plan) async {
    final totals = await _store.totals();
    final days = await _store.all();
    final today = await _store.day(DateTime.now());
    final planPages =
        plan == null ? 0 : await _store.pagesSince(plan.startDate);

    return ReadingSummary(
      totals: totals,
      days: days,
      today: today,
      planPagesRead: planPages,
    );
  }

  Future<void> refresh() async {
    state = AsyncData(await _load(ref.read(khatmahPlanProvider)));
  }

  /// Called by the reader as the user moves through the Mushaf.
  Future<void> recordPage(int page) async {
    await _store.recordPage(page);
    // Note the hour too, so an adaptive reminder has something to learn from.
    // It is one counter per hour and never leaves the device.
    unawaited(WirdHabitStore.noteSession(appPreferences));
    await refresh();
    await ref.read(khatmahPlanProvider.notifier).completeIfFinished();
  }

  /// Called when a reading session ends.
  Future<void> addMinutes(int minutes) async {
    await _store.addMinutes(minutes);
    await refresh();
  }
}

final readingProgressProvider =
    AsyncNotifierProvider<ReadingProgressNotifier, ReadingSummary>(
      ReadingProgressNotifier.new,
    );

/// The current khatmah plan, or null when none is running.
class KhatmahPlanNotifier extends Notifier<KhatmahPlan?> {
  @override
  KhatmahPlan? build() {
    return KhatmahPlan.decode(
      appPreferences.getString(AppConstants.khatmahPlanKey),
    );
  }

  Future<void> start(int days) async {
    final now = DateTime.now();
    await _write(
      KhatmahPlan(
        startDate: DateTime(now.year, now.month, now.day),
        days: days.clamp(1, 365),
      ),
    );
  }

  Future<void> cancel() async {
    state = null;
    await appPreferences.remove(AppConstants.khatmahPlanKey);
  }

  /// Mark the plan finished once the whole Mushaf has been covered.
  Future<void> completeIfFinished() async {
    final plan = state;
    if (plan == null || plan.isComplete) {
      return;
    }

    final pages = await ref
        .read(readingProgressStoreProvider)
        .pagesSince(plan.startDate);
    if (pages >= KhatmahPlan.totalPages) {
      await _write(plan.copyWith(completedAt: DateTime.now()));
    }
  }

  Future<void> _write(KhatmahPlan plan) async {
    state = plan;
    await appPreferences.setString(AppConstants.khatmahPlanKey, plan.encode());
  }
}

final khatmahPlanProvider = NotifierProvider<KhatmahPlanNotifier, KhatmahPlan?>(
  KhatmahPlanNotifier.new,
);
