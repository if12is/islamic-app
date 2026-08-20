import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/adhan_preview_player.dart';
import 'package:islamic_app/core/services/notification_service.dart';

/// A bundled adhan without a Flutter asset cannot be heard before it is
/// chosen, which is how the picker used to fail closed.
void main() {
  test('every bundled adhan has a preview file', () {
    for (final sound in NotificationService.adhanSounds) {
      if (sound.rawResource == null) {
        continue;
      }
      expect(
        AdhanPreviewPlayer.assets[sound.id],
        'assets/audio/${sound.rawResource}.mp3',
        reason: sound.id,
      );
    }
  });
}
