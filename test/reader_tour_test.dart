import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/reader_tour_store.dart';
import 'package:islamic_app/features/quran/presentation/widgets/reader_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('When the walkthrough runs', () {
    test('a reader who has never seen it gets it', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(ReaderTourStore.shouldShow(prefs), isTrue);
    });

    test('it does not come back the same day', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 9, 9);
      await ReaderTourStore.markShown(prefs, now: now);

      expect(ReaderTourStore.shouldShow(prefs, now: now), isFalse);
      expect(
        ReaderTourStore.shouldShow(
          prefs,
          now: now.add(const Duration(days: 7)),
        ),
        isFalse,
      );
    });

    test(
      'it comes back after a month, for a feature since forgotten',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime(2026, 9, 9);
        await ReaderTourStore.markShown(prefs, now: now);

        expect(
          ReaderTourStore.shouldShow(
            prefs,
            now: now.add(ReaderTourStore.repeatAfter),
          ),
          isTrue,
        );
      },
    );

    test('"I know these" ends it for good', () async {
      // Anything that reappears with no way to stop it teaches people to
      // dismiss it unread, which is the opposite of what it is for.
      final prefs = await SharedPreferences.getInstance();
      await ReaderTourStore.dismissForever(prefs);

      expect(ReaderTourStore.shouldShow(prefs), isFalse);
      expect(ReaderTourStore.shouldShow(prefs, now: DateTime(2030)), isFalse);
    });

    test('dismissing outranks being due', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 9, 9);
      await ReaderTourStore.markShown(prefs, now: now);
      await ReaderTourStore.dismissForever(prefs);

      expect(
        ReaderTourStore.shouldShow(
          prefs,
          now: now.add(const Duration(days: 90)),
        ),
        isFalse,
      );
    });

    test('a clock that went backwards is not read as due', () async {
      // A device whose date was wrong and got corrected would otherwise show
      // the tour again on the very next open.
      final prefs = await SharedPreferences.getInstance();
      await ReaderTourStore.markShown(prefs, now: DateTime(2026, 9, 9));

      expect(
        ReaderTourStore.shouldShow(prefs, now: DateTime(2026, 1, 1)),
        isFalse,
      );
    });

    test('asking for it back brings it back', () async {
      final prefs = await SharedPreferences.getInstance();
      await ReaderTourStore.dismissForever(prefs);
      await ReaderTourStore.reset(prefs);

      expect(ReaderTourStore.shouldShow(prefs), isTrue);
    });
  });

  group('What it covers', () {
    test('every step names a real feature of the page', () {
      // The list is the promise: five things the page can do that it never
      // said out loud.
      expect(ReaderTour.steps.length, greaterThanOrEqualTo(5));
      for (final step in ReaderTour.steps) {
        expect(step.titleKey, startsWith('tour_'));
        expect(step.bodyKey, startsWith('tour_'));
      }
    });

    test('no step is listed twice', () {
      final keys = ReaderTour.steps.map((step) => step.titleKey).toList();
      expect(keys.toSet().length, keys.length);
    });
  });
}
