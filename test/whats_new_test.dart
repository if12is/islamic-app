import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/update_service.dart';

void main() {
  group('What is new, in the reader\'s language', () {
    const body = '''
Rolling development APK. This release is replaced on every push to `master`.

- Version: `1.4.0+3518719` (versionCode `3518719`)
- Signed with the project key: `true`

<!-- whats-new {"ar":["سجل القراءة","تذكير بعد كل صلاة"],"en":["Reading history","A reminder after each prayer"]} -->
''';

    test('the list is read out of the release body', () {
      final release = UpdateService.parseRelease({
        'tag_name': 'apk-latest',
        'name': 'Latest development APK (1.4.0+3518719)',
        'body': body,
        'assets': [
          {
            'name': 'islamic-app-1.4.0-build3518719-arm64-v8a.apk',
            'browser_download_url': 'https://example.invalid/app.apk',
            'size': 86800000,
          },
        ],
      })!;

      expect(release.whatsNewIn('ar'), ['سجل القراءة', 'تذكير بعد كل صلاة']);
      expect(release.whatsNewIn('en').first, 'Reading history');
    });

    test('never the other language, and never the developer notes', () {
      final onlyArabic = UpdateService.parseWhatsNew(
        '<!-- whats-new {"ar":["سطر"]} -->',
      );
      expect(onlyArabic['en'], isNull);
      expect(UpdateService.parseWhatsNew(body)['ar'], isNot(contains('true')));
    });

    test('a body without the list, or a broken one, yields nothing', () {
      expect(UpdateService.parseWhatsNew('Just notes.'), isEmpty);
      expect(
        UpdateService.parseWhatsNew('<!-- whats-new {"ar": [oops -->'),
        isEmpty,
      );
    });

    test('a long list is cut to a dialog\'s worth', () {
      final lines = List.generate(20, (i) => '"line $i"').join(',');
      final parsed = UpdateService.parseWhatsNew(
        '<!-- whats-new {"en":[$lines]} -->',
      );
      expect(parsed['en'], hasLength(UpdateService.whatsNewMaxLines));
    });
  });

  group('whats_new.json, which CI puts in every release', () {
    final file = File('whats_new.json');

    test('is valid and has both languages', () {
      final decoded = jsonDecode(file.readAsStringSync()) as Map;
      for (final language in ['ar', 'en']) {
        final lines = decoded[language];
        expect(lines, isA<List>(), reason: language);
        expect((lines as List), isNotEmpty, reason: language);
        expect(lines.length, lessThanOrEqualTo(UpdateService.whatsNewMaxLines));
        for (final line in lines) {
          expect(line, isA<String>());
          expect(
            (line as String).length,
            lessThanOrEqualTo(UpdateService.whatsNewLineLimit),
            reason: 'keep each line short: "$line"',
          );
        }
      }
    });

    test('says nothing a reader could not use', () {
      // No version codes, commit hashes, backticks or Latin in the Arabic
      // list — the things that made the old dialog unreadable.
      final decoded = jsonDecode(file.readAsStringSync()) as Map;
      for (final line in (decoded['ar'] as List).cast<String>()) {
        expect(line, isNot(matches(RegExp(r'[A-Za-z`]'))), reason: line);
        expect(line, isNot(matches(RegExp(r'\d{3,}'))), reason: line);
      }
      for (final line in (decoded['en'] as List).cast<String>()) {
        expect(line, isNot(contains('`')), reason: line);
        expect(line, isNot(matches(RegExp(r'\d{4,}'))), reason: line);
      }
    });

    test('the workflow puts it where the app looks for it', () {
      final workflow =
          File('.github/workflows/android-apk.yml').readAsStringSync();
      expect(workflow, contains('whats_new.json'));
      expect(workflow, contains(r'<!-- whats-new ${WHATS_NEW} -->'));
    });
  });
}
