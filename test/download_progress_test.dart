import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/presentation/providers/downloads_provider.dart';

void main() {
  group('A download whose size the server never states', () {
    // The regression: progress was reported as received/total and skipped
    // entirely when total was -1, which is what a chunked response gives. The
    // bar sat at zero for the whole download and then jumped to finished.
    test('reports an indeterminate bar, not zero', () {
      const progress = DownloadProgress(received: 4200000, total: -1);

      expect(progress.ratio, isNull, reason: 'so the bar sweeps');
      expect(progress.receivedLabel, '4.2 MB');
      expect(progress.totalLabel, isNull);
    });

    test('a stated size still gives a real fraction', () {
      const progress = DownloadProgress(received: 5000000, total: 10000000);

      expect(progress.ratio, closeTo(0.5, 1e-9));
      expect(progress.totalLabel, '10.0 MB');
    });

    test('a server that overshoots its own total cannot exceed full', () {
      const progress = DownloadProgress(received: 11000000, total: 10000000);
      expect(progress.ratio, 1.0);
    });

    test('small downloads read in kilobytes', () {
      expect(
        const DownloadProgress(received: 51200, total: -1).receivedLabel,
        '51 KB',
      );
    });
  });

  group('The queue', () {
    test('knows what is waiting as well as what is running', () {
      const state = DownloadsState(
        progress: {'afasy/1': DownloadProgress(received: 10, total: 100)},
        queue: ['afasy/2', 'afasy/3'],
      );

      expect(state.isBusy('afasy', 1), isTrue, reason: 'downloading');
      expect(state.isBusy('afasy', 2), isTrue, reason: 'queued');
      expect(state.isQueued('afasy', 2), isTrue);
      expect(state.isQueued('afasy', 1), isFalse);
      expect(state.isBusy('afasy', 9), isFalse);
    });
  });
}
