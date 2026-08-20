import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/localization/app_localizations.dart';

/// Every `context.tr('…')` in the app must resolve.
///
/// A missing key does not crash — it renders the key itself, which is how
/// `prayer_times_today` ends up printed on a screen in production. Catching it
/// here costs nothing.
void main() {
  final english = AppLocalizations.keysFor('en');
  final arabic = AppLocalizations.keysFor('ar');

  test('both languages define the same keys', () {
    expect(
      english.difference(arabic),
      isEmpty,
      reason: 'defined in English but missing in Arabic',
    );
    expect(
      arabic.difference(english),
      isEmpty,
      reason: 'defined in Arabic but missing in English',
    );
  });

  test('every key the code asks for exists', () {
    final pattern = RegExp(r"""(?:context|\w+)\.tr\(\s*'([a-z0-9_]+)'""");
    final missing = <String, Set<String>>{};

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final match in pattern.allMatches(source)) {
        final key = match.group(1)!;
        if (!english.contains(key)) {
          missing.putIfAbsent(entity.path, () => <String>{}).add(key);
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'These keys are used but never defined:\n'
          '${missing.entries.map((e) => '${e.key}: ${e.value.join(', ')}').join('\n')}',
    );
  });
}
