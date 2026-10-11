import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/haramain_schedule_repository.dart';
import '../../domain/haramain_week.dart';

/// What the imams page shows.
class HaramainState {
  const HaramainState({this.week, this.loading = false, this.failed = false});

  /// The best week we have, possibly last week's.
  final HaramainWeek? week;

  /// A refresh is running. The cached [week], if any, is shown meanwhile.
  final bool loading;

  /// The last refresh could not reach or read the source.
  final bool failed;

  HaramainState copyWith({HaramainWeek? week, bool? loading, bool? failed}) {
    return HaramainState(
      week: week ?? this.week,
      loading: loading ?? this.loading,
      failed: failed ?? this.failed,
    );
  }
}

final haramainRepositoryProvider = Provider<HaramainScheduleRepository>(
  (ref) => HaramainScheduleRepository(),
);

/// The stored week only: no network, so a card can read it for free.
final haramainCachedWeekProvider = FutureProvider<HaramainWeek?>(
  (ref) => ref.watch(haramainRepositoryProvider).loadCached(),
);

/// The stored week at once, then a background refresh when the rules allow.
class HaramainController extends Notifier<HaramainState> {
  @override
  HaramainState build() {
    Future<void>(_start);
    return const HaramainState(loading: true);
  }

  Future<void> _start() async {
    final repository = ref.read(haramainRepositoryProvider);
    final cached = await repository.loadCached();
    if (!ref.mounted) {
      return;
    }
    if (cached != null) {
      state = state.copyWith(week: cached);
    }
    await _refresh(force: false);
  }

  /// The retry button.
  Future<void> retry() async {
    state = state.copyWith(loading: true, failed: false);
    await _refresh(force: true);
  }

  Future<void> _refresh({required bool force}) async {
    final result = await ref
        .read(haramainRepositoryProvider)
        .refresh(force: force);
    if (!ref.mounted) {
      return;
    }
    state = HaramainState(week: result.week, failed: result.failed);
    // The shelf's teaser card reads the stored copy; tell it there is news.
    ref.invalidate(haramainCachedWeekProvider);
  }
}

final haramainProvider = NotifierProvider<HaramainController, HaramainState>(
  HaramainController.new,
);
