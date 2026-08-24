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

      test('$name: gold is readable as a foreground', () {
        // Gold is mostly used for icons and short labels on a surface, which
        // is a 3:1 job, not a 4.5:1 one.
        expect(_contrast(tokens.gold, tokens.surface), greaterThan(3));
        expect(_contrast(tokens.gold, tokens.ground), greaterThan(3));
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
        'lib/features/prayer_times/presentation/widgets/imsakiya_poster.dart',
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
