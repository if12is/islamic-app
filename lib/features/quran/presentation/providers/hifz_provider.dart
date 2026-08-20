import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hifz_store.dart';
import '../../domain/entities/hifz_item.dart';

final hifzStoreProvider = Provider<HifzStore>((ref) => HifzStore());

/// The memorisation list and its review queue.
class HifzNotifier extends AsyncNotifier<List<HifzItem>> {
  HifzStore get _store => ref.read(hifzStoreProvider);

  @override
  Future<List<HifzItem>> build() => _store.all();

  Future<void> refresh() async {
    state = AsyncData(await _store.all());
  }

  /// Add a passage. Re-adding an existing one leaves its schedule alone.
  Future<void> add({
    required int surahNumber,
    required int fromAyah,
    required int toAyah,
  }) async {
    final item = HifzItem.fresh(
      surahNumber: surahNumber,
      fromAyah: fromAyah,
      toAyah: toAyah,
    );

    if (await _store.contains(item.key)) {
      return;
    }
    await _store.save(item);
    await refresh();
  }

  Future<void> remove(HifzItem item) async {
    await _store.remove(item.key);
    await refresh();
  }

  /// Grade a review and reschedule it.
  Future<void> grade(HifzItem item, HifzGrade grade) async {
    await _store.save(item.review(grade));
    await refresh();
  }

  List<HifzItem> get dueToday {
    final items = state.value ?? const <HifzItem>[];
    final now = DateTime.now();
    return items.where((item) => item.isDue(now)).toList();
  }
}

final hifzProvider = AsyncNotifierProvider<HifzNotifier, List<HifzItem>>(
  HifzNotifier.new,
);

/// Passages due for review today.
final hifzDueProvider = Provider<List<HifzItem>>((ref) {
  final items = ref.watch(hifzProvider).value ?? const <HifzItem>[];
  final now = DateTime.now();
  return items.where((item) => item.isDue(now)).toList();
});
