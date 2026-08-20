import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bundled files have to actually be whole.
///
/// The Ramadan intro shipped truncated once — a third of the file, enough to
/// hold a valid header and nothing to decode — so the player opened it, showed
/// a blank frame and gave up. Nothing in the app noticed. A size floor per
/// asset catches that in a second.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const minimumBytes = <String, int>{
    'assets/video/ramadan_intro.mp4': 2000000,
    'assets/video/eid_adha_intro.mp4': 2000000,
    'assets/data/cities.json': 300000,
    'assets/data/azkar.json': 100000,
  };

  for (final entry in minimumBytes.entries) {
    test('${entry.key} is present and complete', () async {
      final data = await rootBundle.load(entry.key);

      expect(
        data.lengthInBytes,
        greaterThanOrEqualTo(entry.value),
        reason:
            '${entry.key} is ${data.lengthInBytes} bytes, which is smaller '
            'than a whole copy. It was probably truncated by a partial copy.',
      );
    });
  }

  for (final path in const [
    'assets/video/ramadan_intro.mp4',
    'assets/video/eid_adha_intro.mp4',
  ]) {
    test('$path is a playable MP4, not just a header', () async {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();

      // 'ftyp' at offset 4 is the MP4 signature.
      expect(String.fromCharCodes(bytes.sublist(4, 8)), 'ftyp');

      // The media data box has to exist, and the file has to continue past it.
      final marker = 'mdat'.codeUnits;
      var mdatAt = -1;
      for (var i = 0; i < bytes.length - 4; i++) {
        if (bytes[i] == marker[0] &&
            bytes[i + 1] == marker[1] &&
            bytes[i + 2] == marker[2] &&
            bytes[i + 3] == marker[3]) {
          mdatAt = i;
          break;
        }
      }

      expect(mdatAt, greaterThan(0), reason: 'no media data box');
      expect(
        bytes.length - mdatAt,
        greaterThan(1000000),
        reason: 'the media data box is cut short',
      );
    });
  }
}
