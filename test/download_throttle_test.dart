import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/update_installer.dart';

void main() {
  group('Reporting how far the download has got', () {
    test('a percent the bar has already drawn is dropped', () {
      final throttle = DownloadThrottle();

      expect(throttle.accept(4), isTrue);
      expect(throttle.accept(4), isFalse);
      expect(throttle.accept(4), isFalse);
      expect(throttle.accept(5), isTrue);
    });

    test('an 86 MB package reports a hundred times, not eleven thousand', () {
      // The plugin fires on every 8 KiB segment it reads. Each event used to
      // cross the platform channel, replace the provider's state and rebuild
      // the dialog — so the phone spent its main thread redrawing a progress
      // bar rather than showing the download. This is the whole fix, measured.
      const bytes = 86 * 1024 * 1024;
      const segment = 8 * 1024;
      final throttle = DownloadThrottle();

      var raw = 0;
      var reported = 0;
      for (var sent = 0; sent <= bytes; sent += segment) {
        raw++;
        if (throttle.accept(sent * 100 ~/ bytes)) {
          reported++;
        }
      }

      expect(raw, greaterThan(11000));
      expect(reported, lessThanOrEqualTo(101));
    });

    test('an unknown size is always passed on', () {
      // Null is not a repeat of anything — it is the state before a
      // Content-Length arrives, and the dialog draws it differently.
      final throttle = DownloadThrottle();

      expect(throttle.accept(null), isTrue);
      expect(throttle.accept(null), isTrue);
      expect(throttle.accept(0), isTrue);
    });

    test('every step of a full download survives', () {
      // Dropping repeats must not drop progress: all 101 positions still
      // arrive, in order.
      final throttle = DownloadThrottle();
      final seen = <int>[];

      for (var percent = 0; percent <= 100; percent++) {
        for (var repeat = 0; repeat < 40; repeat++) {
          if (throttle.accept(percent)) {
            seen.add(percent);
          }
        }
      }

      expect(seen, List<int>.generate(101, (index) => index));
    });
  });
}
