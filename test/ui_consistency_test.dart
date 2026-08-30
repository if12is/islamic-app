import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/theme/app_theme.dart';
import 'package:islamic_app/core/theme/design_tokens.dart';
import 'package:islamic_app/core/widgets/app_icon_tile.dart';

Widget _wrap(Widget child, {AppTokens? tokens}) => MaterialApp(
  theme: AppTheme.from(tokens ?? AppTokens.light),
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('One icon component, not a hundred', () {
    test('every role has a size, and they climb', () {
      // The app had icons at 15, 18, 19, 20, 21, 22, 24 and 26 chosen line by
      // line. A role picks the size so the choice is made once.
      var previousBox = -1.0;
      var previousGlyph = -1.0;
      for (final role in AppIconRole.values) {
        final box = AppIconTile.boxFor(role);
        final glyph = AppIconTile.glyphFor(role);
        expect(glyph, greaterThan(previousGlyph), reason: role.name);
        expect(box, greaterThanOrEqualTo(previousBox), reason: role.name);
        previousBox = box;
        previousGlyph = glyph;
      }
    });

    test('an inline icon has no container', () {
      // A tinted chip behind a glyph in the middle of a sentence is noise.
      expect(AppIconTile.boxFor(AppIconRole.inline), 0);
    });

    test('the glyph never outgrows its box', () {
      for (final role in AppIconRole.values) {
        final box = AppIconTile.boxFor(role);
        if (box == 0) {
          continue;
        }
        expect(
          AppIconTile.glyphFor(role),
          lessThan(box),
          reason: '${role.name} glyph does not fit',
        );
      }
    });

    testWidgets('it draws in every role and tone without throwing', (
      tester,
    ) async {
      for (final tokens in [AppTokens.light, AppTokens.dark]) {
        await tester.pumpWidget(
          _wrap(
            tokens: tokens,
            Wrap(
              children: [
                for (final role in AppIconRole.values)
                  for (final tone in AppIconTone.values)
                    AppIconTile(Icons.star, role: role, tone: tone),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the count badge and the icon share one wash', (tester) async {
      // The Azkar cards had the icon on a brand tint and the number on
      // groundAlt — two unrelated backgrounds a few pixels apart, which is
      // why the light theme looked assembled and the dark one looked designed.
      await tester.pumpWidget(
        _wrap(
          const Row(
            children: [
              AppIconTile(Icons.star, role: AppIconRole.card),
              AppIconCount(count: '30'),
            ],
          ),
        ),
      );

      final decorations =
          tester
              .widgetList<Container>(find.byType(Container))
              .map((c) => c.decoration)
              .whereType<BoxDecoration>()
              .map((d) => d.color)
              .whereType<Color>()
              .toList();

      expect(decorations.length, greaterThanOrEqualTo(2));
      expect(
        decorations.toSet(),
        hasLength(1),
        reason: 'the icon and its count are on different backgrounds',
      );
    });
  });

  group('The header does not spend itself on one destination', () {
    test('the hamburger that opened Settings is gone', () {
      // Settings was reachable three ways from every screen — a hamburger, an
      // avatar and a tab — while the wird, which is the thing the app exists
      // to keep, had none.
      final source = Directory('lib').listSync(recursive: true);
      final offenders = <String>[];
      for (final entity in source) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        if (entity.readAsStringSync().contains('ShellMenuButton')) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty);
    });

    test('the wird has the tab Settings used to have', () {
      final home =
          File(
            'lib/features/home/presentation/pages/home_page.dart',
          ).readAsStringSync();
      expect(home, contains('WirdPage()'));
      expect(home, contains("context.tr('wird_title')"));
    });

    test('every nav destination is labelled', () {
      // The bar showed a dot under the open tab and nothing else, which works
      // only for someone who has already learned what each glyph opens.
      final bar =
          File(
            'lib/features/home/presentation/widgets/glass_nav_bar.dart',
          ).readAsStringSync();
      expect(bar, contains('item.label'));
    });
  });

  group('Nothing pretends to be the reader', () {
    test('the profile does not print a stranger\'s name', () {
      // The empty state printed "أحمد عبدالله" and "القاهرة، مصر" as if they
      // were the reader's own details — a placeholder that reads as data.
      final strings =
          File(
            'lib/core/localization/app_localizations.dart',
          ).readAsStringSync();
      expect(strings, isNot(contains('أحمد عبدالله')));
      expect(strings, contains("'profile_name_prompt'"));
    });
  });

  group('The prayer list asks once', () {
    test('the row-level tick is gone', () {
      // The card above records mosque, congregation, alone or made up. The
      // row could only say "done", and asked the same question again with
      // less of an answer.
      final page =
          File(
            'lib/features/prayer_times/presentation/pages/prayer_times_page.dart',
          ).readAsStringSync();
      expect(page, isNot(contains("tooltip: context.tr('mark_prayed')")));
    });
  });
}
