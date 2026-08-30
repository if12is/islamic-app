import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/app_providers.dart';
import '../../data/custom_wird_store.dart';
import '../../domain/custom_wird.dart';

class CustomWirdController extends Notifier<CustomWird> {
  @override
  CustomWird build() => CustomWirdStore.read(appPreferences);

  Future<void> _saveItems(List<CustomWirdItem> items) async {
    await CustomWirdStore.writeItems(appPreferences, items);
    state = state.copyWith(items: items);
  }

  Future<void> add(CustomWirdItem item) =>
      _saveItems(CustomWirdStore.withItem(state.items, item));

  Future<void> remove(String id) async {
    await _saveItems(CustomWirdStore.withoutId(state.items, id));
    // The count goes with the line. Leaving it behind means re-adding the
    // same surah tomorrow inherits a tick from a wird it was never part of.
    final counts = {...state.doneToday}..remove(id);
    await CustomWirdStore.writeProgress(appPreferences, counts);
    state = state.copyWith(doneToday: counts);
  }

  Future<void> reorder(int from, int to) =>
      _saveItems(CustomWirdStore.reordered(state.items, from, to));

  /// Count one repetition, or uncount the last one.
  Future<void> mark(CustomWirdItem item, {bool undo = false}) async {
    final current = state.doneFor(item.id);
    final next =
        undo
            ? (current - 1).clamp(0, item.target)
            : (current + 1).clamp(0, item.target);

    final counts = {...state.doneToday, item.id: next};
    await CustomWirdStore.writeProgress(appPreferences, counts);
    state = state.copyWith(doneToday: counts);
  }

  /// Tick a whole line at once — what a tap means for something read rather
  /// than counted.
  Future<void> toggleComplete(CustomWirdItem item) async {
    final done = state.isComplete(item) ? 0 : item.target;
    final counts = {...state.doneToday, item.id: done};
    await CustomWirdStore.writeProgress(appPreferences, counts);
    state = state.copyWith(doneToday: counts);
  }

  /// Re-read from disk, so a day that turned over while the app was open does
  /// not keep yesterday's ticks on screen.
  void refresh() {
    state = CustomWirdStore.read(appPreferences);
  }
}

final customWirdProvider = NotifierProvider<CustomWirdController, CustomWird>(
  CustomWirdController.new,
);

/// Whether a given thing is already in the reader's wird.
///
/// The add button reads this so it can say "added" rather than offering to add
/// something twice — the commonest way a list like this fills up with
/// duplicates is a button that never changes.
final inWirdProvider = Provider.family<bool, (WirdKind, String)>((ref, target) {
  final wird = ref.watch(customWirdProvider);
  return wird.contains(target.$1, target.$2);
});
