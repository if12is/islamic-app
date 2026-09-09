import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/localization/app_localizations.dart';
import 'package:islamic_app/core/theme/app_theme.dart';
import 'package:islamic_app/core/theme/design_tokens.dart';
import 'package:islamic_app/core/widgets/app_cards.dart';
import 'package:islamic_app/core/widgets/app_section.dart';

/// Reads every Dart file under lib/.
Iterable<(String path, String source)> _sources() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield (entity.path.replaceAll(r'\', '/'), entity.readAsStringSync());
    }
  }
}

/// Whether a `tooltip:` appears inside the argument list that starts at
/// [start], by walking the brackets rather than counting lines.
bool _hasTooltip(String source, int start) {
  var depth = 0;
  for (var i = start; i < source.length; i++) {
    final char = source[i];
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) {
        return source.substring(start, i).contains('tooltip:');
      }
    }
  }
  return false;
}

void main() {
  group('Every icon-only control says what it does', () {
    // An icon with no name reads as "button" to a screen reader and as a
    // guess to everyone else. Tooltip is what supplies both the long-press
    // label and the semantics, so requiring it covers both at once.
    test('IconButton carries a tooltip', () {
      final offenders = <String>[];

      for (final (path, source) in _sources()) {
        // The look-behind keeps GhostIconButton out of this one; it has its
        // own test below.
        for (final match in RegExp(
          r'(?<![A-Za-z])IconButton\(',
        ).allMatches(source)) {
          if (!_hasTooltip(source, match.end - 1)) {
            final line =
                '\n'.allMatches(source.substring(0, match.start)).length + 1;
            offenders.add('$path:$line');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These icon buttons have no tooltip, so they are unnamed for a '
            'screen reader:\n${offenders.join('\n')}',
      );
    });

    test('GhostIconButton carries a tooltip', () {
      final offenders = <String>[];

      for (final (path, source) in _sources()) {
        // The declaration itself, in app_section.dart, is not a use.
        if (path.endsWith('core/widgets/app_section.dart')) {
          continue;
        }
        for (final match in RegExp(r'GhostIconButton\(').allMatches(source)) {
          if (!_hasTooltip(source, match.end - 1)) {
            final line =
                '\n'.allMatches(source.substring(0, match.start)).length + 1;
            offenders.add('$path:$line');
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('Numbers are written in the reader\'s own script', () {
    test('one digit table, not one per screen', () {
      // Six screens had grown a private copy of this conversion — `_digits`,
      // `_localizeDigits`, `_toArabicDigits`, `_formatNumber`,
      // `_localizedNumber`, and a second `_digits` — and several places had
      // simply been missed: the daily wird counted "0/31" and the adhkar card
      // "0 / 30" in an Arabic interface. Six copies is six chances to forget
      // the seventh call site.
      const table = "'٠'";
      final offenders = <String>[];

      for (final (path, source) in _sources()) {
        if (path == 'lib/core/utils/arabic_numerals.dart') {
          continue;
        }
        if (source.contains(table)) {
          offenders.add(path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These files carry their own Arabic-Indic digit table. Use '
            'localizeDigits / toArabicDigits from core/utils/arabic_numerals '
            'instead:\n${offenders.join('\n')}',
      );
    });
  });

  group('A row is announced as one thing', () {
    testWidgets('the number, name and meta merge; the button stays apart', (
      tester,
    ) async {
      // Left alone, a screen reader walks the row in painting order and reads
      // "1", "al-Fatiha", "Meccan, 7 verses" as three unrelated items, leaving
      // the listener to assemble a surah out of fragments. The controls are
      // the exception: a play button has to stay its own thing to reach.
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.from(AppTokens.light),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: AppListRow(
                badge: '١',
                title: 'الفاتحة',
                meta: 'مكية · ٧ آية',
                onTap: () {},
                trailing: IconButton(
                  tooltip: 'تشغيل',
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow),
                ),
              ),
            ),
          ),
        ),
      );

      final row = tester.getSemantics(find.text('الفاتحة'));
      expect(row.label, contains('١'));
      expect(row.label, contains('الفاتحة'));
      expect(row.label, contains('مكية'));
      expect(
        row.label,
        isNot(contains('تشغيل')),
        reason: 'the play button was folded into the row and cannot be pressed',
      );

      // And it is still there, as a node of its own that can be pressed.
      expect(
        tester.getSemantics(find.byType(IconButton)),
        isSemantics(isButton: true, hasTapAction: true, isEnabled: true),
      );

      handle.dispose();
    });
  });

  group('Text is allowed to grow', () {
    // Someone who has turned their system font up has done it because they
    // need to. Pinning the scale back to 1 overrides that decision.
    test('nothing pins the text scale except what renders to a file', () {
      final allowed = {
        // The share poster is composed at a fixed pixel size; the viewer's
        // font setting must not change what lands in the image.
        'lib/features/quran/presentation/widgets/weekly_report_card.dart',
        // These two are the size control itself. Each button is drawn at the
        // size it sets, so it can be judged by looking rather than by trying
        // — and scaling a sample by the very setting it is a sample of would
        // make the row resize under the finger choosing from it.
        'lib/features/settings/presentation/widgets/app_text_scale_card.dart',
        'lib/features/onboarding/presentation/pages/onboarding_page.dart',
      };
      final offenders = <String>[];

      for (final (path, source) in _sources()) {
        if (allowed.contains(path)) {
          continue;
        }
        if (source.contains('textScaleFactor:') ||
            source.contains('withNoTextScaling') ||
            source.contains('TextScaler.noScaling')) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('Controls survive a large font setting', () {
    /// Android lets someone push the system font to double size. The existing
    /// overflow suite checks 1.3×, which is the comfortable end; this checks
    /// the setting a person with low vision actually uses.
    Future<void> pumpAtDoubleSize(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            theme: AppTheme.from(AppTokens.light),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('a list row does not overflow at 2× type', (tester) async {
      await pumpAtDoubleSize(
        tester,
        const AppListRow(
          badge: '١',
          title: 'سورة الفاتحة',
          meta: 'مكية · ٧ آيات',
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a section header does not overflow at 2× type', (
      tester,
    ) async {
      await pumpAtDoubleSize(
        tester,
        const SectionHeader(
          title: 'أذكار المسلم',
          subtitle: '١٣٦ باباً',
          trailingLabel: 'عرض الكل',
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Every tooltip resolves to real words', () {
    test('the keys the new controls use are defined', () {
      final english = AppLocalizations.keysFor('en');
      for (final key in [
        'clear',
        'previous',
        'previous_month',
        'next_month',
        'back',
        'settings',
        'play',
        'pause',
        'now_playing',
        'back_ten',
        'forward_ten',
        'repeat_surah',
      ]) {
        expect(english, contains(key), reason: '$key is used as a tooltip');
      }
    });
  });
}
