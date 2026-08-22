import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // just_audio_background attaches its media notification to the first player
  // created and supports no others. Three separate AudioPlayer instances used
  // to exist, so which screen got the notification — and whether the Quran
  // could play at all after previewing an adhan — depended on the order the
  // user happened to open things in.
  group('Only one AudioPlayer', () {
    test('is constructed anywhere outside AppAudio', () {
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        if (entity.path.endsWith('core/services/app_audio.dart')) {
          continue;
        }
        final source = entity.readAsStringSync();
        if (source.contains('AudioPlayer()')) {
          offenders.add(entity.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'AudioPlayer() must only be constructed in AppAudio; found in '
            '${offenders.join(', ')}',
      );
    });
  });
}
