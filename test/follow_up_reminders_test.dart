import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/friday_progress.dart';
import 'package:islamic_app/core/services/notification_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('A notification button survives the app starting up', () {
    test('a log button carries its answer in the payload', () {
      expect(
        NotificationRouter.resolve('log:fajr:2026-09-11', 'log_mosque'),
        'log:fajr:2026-09-11:mosque',
      );
      expect(
        NotificationRouter.resolve('log:isha:2026-09-11', 'log_missed'),
        'log:isha:2026-09-11:missed',
      );
    });

    test('a tap on the body asks rather than answers', () {
      expect(
        NotificationRouter.resolve('log:fajr:2026-09-11', null),
        'log:fajr:2026-09-11',
      );
    });

    test('"I\'ve read it" becomes its own action', () {
      expect(
        NotificationRouter.resolve('quran:surah:18', 'kahf_done'),
        'friday:kahf_done',
      );
      expect(
        NotificationRouter.resolve('quran:surah:18', 'open_kahf'),
        'quran:surah:18',
      );
    });

    test('listen still starts the recitation', () {
      expect(
        NotificationRouter.resolve('quran:verse:2:255', 'listen_ayah'),
        'quran:verse:2:255:play',
      );
    });
  });

  group('Friday', () {
    test('Al-Kahf counts as read once most of its pages are', () {
      final pages = FridayProgress.kahfPages();
      expect(pages.length, greaterThanOrEqualTo(10));
      expect(pages.contains(293), isTrue, reason: 'it opens on page 293');

      final sorted = pages.toList()..sort();
      expect(FridayProgress.kahfCovered(sorted.take(3).toSet()), isFalse);
      // Skipping a page or two while scrolling is still reading the surah.
      expect(FridayProgress.kahfCovered(sorted.skip(2).toSet()), isTrue);
      // Other pages read that day are not Al-Kahf.
      expect(FridayProgress.kahfCovered({1, 2, 3, 4, 5, 6, 7, 8, 9}), isFalse);
    });

    test('marking Al-Kahf read holds for that day only', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final friday = DateTime(2026, 9, 11);

      await FridayProgress.markKahfRead(prefs, friday);
      expect(FridayProgress.isKahfRead(prefs, friday), isTrue);
      expect(
        FridayProgress.isKahfRead(prefs, friday.add(const Duration(days: 7))),
        isFalse,
      );
    });
  });
}
