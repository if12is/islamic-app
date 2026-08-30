import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/theme/app_theme.dart';
import 'package:islamic_app/core/theme/design_tokens.dart';
import 'package:islamic_app/core/services/seasonal_theme.dart';

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Colour contrast', () {
    for (final (name, tokens) in [
      ('light', AppTokens.light),
      ('dark', AppTokens.dark),
    ]) {
      test('$name: body text on every surface is readable', () {
        for (final (surfaceName, surface) in [
          ('ground', tokens.ground),
          ('groundAlt', tokens.groundAlt),
          ('surface', tokens.surface),
          ('surfaceRaised', tokens.surfaceRaised),
        ]) {
          expect(
            _contrast(tokens.ink, surface),
            greaterThan(7),
            reason: 'ink on $surfaceName',
          );
          expect(
            _contrast(tokens.inkMuted, surface),
            greaterThan(4.5),
            reason: 'inkMuted on $surfaceName',
          );
        }
      });

      test('$name: text on the gold card is the ink, not white', () {
        // The whole reason onGold exists. White on gold reads at roughly 2:1
        // and disappears in daylight, so the ink has to survive the darkest
        // end of the gradient as well as the lightest.
        for (final stop in tokens.heroGradient) {
          expect(
            _contrast(tokens.onGold, stop),
            greaterThan(4.5),
            reason: 'onGold on $stop',
          );
        }
        expect(
          _contrast(Colors.white, tokens.heroGradient.first),
          lessThan(4.5),
          reason: 'white would be unreadable here',
        );
      });

      test('$name: captions are readable, not decorative', () {
        // inkFaint sets every caption, every subtitle and every unit label —
        // 102 places. It was #7A8A80 in the light theme and failed 4.5:1 on
        // all four surfaces, bottoming out at 2.96 on groundAlt: text the
        // same weight as its background, which is what a reader called out.
        for (final (surfaceName, surface) in [
          ('ground', tokens.ground),
          ('groundAlt', tokens.groundAlt),
          ('surface', tokens.surface),
          ('surfaceRaised', tokens.surfaceRaised),
        ]) {
          expect(
            _contrast(tokens.inkFaint, surface),
            greaterThanOrEqualTo(4.5),
            reason: 'inkFaint on $surfaceName',
          );
        }
      });

      test('$name: gold has one value to fill with and one to write with', () {
        // The accent that carries the identity is a 3:1 job — it fills the
        // hero card and draws the ornament. A gold *word* is a 4.5:1 job, and
        // in the light theme the accent cannot do both: it reads 2.97 on
        // groundAlt. So there are two, and the writing one has to clear 4.5
        // everywhere or the split bought nothing.
        for (final (surfaceName, surface) in [
          ('ground', tokens.ground),
          ('groundAlt', tokens.groundAlt),
          ('surface', tokens.surface),
          ('surfaceRaised', tokens.surfaceRaised),
        ]) {
          expect(
            _contrast(tokens.goldInk, surface),
            greaterThanOrEqualTo(4.5),
            reason: 'goldInk on $surfaceName',
          );
          expect(
            _contrast(tokens.gold, surface),
            greaterThanOrEqualTo(3),
            reason: 'gold on $surfaceName',
          );
        }
      });

      test('$name: the brand reads against the ground', () {
        expect(_contrast(tokens.brand, tokens.ground), greaterThan(3));
      });
    }
  });

  group('Seasonal dressing', () {
    test('changes the accent but never the identity', () {
      for (final event in SeasonalEvent.values) {
        for (final base in [AppTokens.light, AppTokens.dark]) {
          final dressed = SeasonalTheme.dress(base, event);

          expect(dressed.brand, base.brand, reason: '$event kept the brand');
          expect(dressed.ground, base.ground, reason: '$event kept the ground');
          expect(dressed.ink, base.ink, reason: '$event kept the ink');

          if (event != SeasonalEvent.none) {
            expect(
              dressed.gold,
              isNot(base.gold),
              reason: '$event should change the accent',
            );
          }
        }
      }
    });

    test('every season keeps its hero text readable', () {
      for (final event in SeasonalEvent.values) {
        for (final base in [AppTokens.light, AppTokens.dark]) {
          final dressed = SeasonalTheme.dress(base, event);
          for (final stop in dressed.heroGradient) {
            expect(
              _contrast(dressed.onGold, stop),
              greaterThan(3),
              reason: '$event hero stop $stop',
            );
          }
        }
      }
    });
  });

  group('Themes are built from tokens', () {
    test('both themes carry the token set as an extension', () {
      for (final tokens in [AppTokens.light, AppTokens.dark]) {
        final theme = AppTheme.from(tokens);
        expect(theme.extension<AppTokens>(), tokens);
        expect(theme.scaffoldBackgroundColor, tokens.ground);
        expect(theme.colorScheme.primary, tokens.brand);
      }
    });

    test('a dressed theme reaches the widgets', () {
      final theme = AppTheme.from(
        SeasonalTheme.dress(AppTokens.dark, SeasonalEvent.eidFitr),
      );
      expect(theme.extension<AppTokens>()!.gold, isNot(AppTokens.dark.gold));
      expect(theme.colorScheme.primary, AppTokens.dark.brand);
    });
  });

  group('No colour literals outside the token file', () {
    test('screens ask the tokens instead of inventing a colour', () {
      final offenders = <String>[];
      final allowed = {
        'lib/core/theme/design_tokens.dart',
        'lib/core/services/seasonal_theme.dart',
        // The reading themes are a deliberate, separate palette: paper, sepia
        // and night are reading surfaces, not app chrome.
        'lib/features/quran/presentation/providers/reader_settings_provider.dart',
        // The share card and the printable poster render to an image, not to a
        // themed screen, so they carry their own fixed palette.
        'lib/features/quran/presentation/widgets/ayah_share_card.dart',
        'lib/features/quran/presentation/widgets/ayah_actions_sheet.dart',
        // The video frame is exported to a file that outlives this build's
        // theme. Tying it to the tokens would mean a card someone shared last
        // year quietly restyles itself the next time the palette is tuned.
        'lib/features/quran/presentation/widgets/ayah_video_frame.dart',
        // The tajweed colours are a code to be learned, not decoration. Red
        // has to still mean six counts after the app's palette is next tuned,
        // so they are deliberately not tied to the tokens.
        'lib/features/quran/domain/tajweed_palette.dart',
        'lib/features/prayer_times/presentation/widgets/imsakiya_poster.dart',
        // The monthly sheet is rendered to a PNG that gets shared and printed.
        // A printed page has no dark mode, and a sheet someone pinned to a
        // wall should not depend on which theme the app was in that day.
        'lib/features/prayer_times/presentation/widgets/monthly_timetable_poster.dart',
        'lib/core/theme/design_colors.dart',
      };

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final path = entity.path.replaceAll(r'\', '/');
        if (allowed.contains(path)) {
          continue;
        }
        final source = entity.readAsStringSync();
        final matches = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)').allMatches(source);
        if (matches.isNotEmpty) {
          offenders.add('$path (${matches.length})');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These files declare colours directly. Move the value into '
            'design_tokens.dart and read it with context.tokens:\n'
            '${offenders.join('\n')}',
      );
    });
  });
}
