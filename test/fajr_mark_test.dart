import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/theme/app_theme.dart';
import 'package:islamic_app/core/theme/design_tokens.dart';
import 'package:islamic_app/core/widgets/fajr_mark.dart';

/// The geometry as the approved design states it, written out separately so a
/// change to the painter has to be a deliberate change to these numbers too.
/// Construction "1A — the valley": a circle and a six-point band on a
/// 120-unit square.
const List<List<double>> _designBook = [
  [12, 60],
  [60, 74],
  [108, 60],
  [108, 78],
  [60, 92],
  [12, 78],
];

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.from(AppTokens.light),
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('The mark matches the approved drawing', () {
    test('the sun is where the design puts it', () {
      expect(FajrMarkGeometry.sunCentre, const Offset(60, 58));
      expect(FajrMarkGeometry.sunRadius, 26);
      expect(FajrMarkGeometry.units, 120);
    });

    test('the book is the six points, in order', () {
      expect(FajrMarkGeometry.bookPoints.length, _designBook.length);
      for (var i = 0; i < _designBook.length; i++) {
        expect(
          FajrMarkGeometry.bookPoints[i],
          Offset(_designBook[i][0], _designBook[i][1]),
          reason: 'point $i',
        );
      }
    });

    test('the sun is cut by the book, not floating above it', () {
      // The whole idea is that the book is the horizon and the sun clears it.
      // Lift the disc free of the band and there is no dawn — the design sheet
      // lists exactly that as a wrong use.
      final sunBottom =
          FajrMarkGeometry.sunCentre.dy + FajrMarkGeometry.sunRadius;
      final bookTop = FajrMarkGeometry.bookPoints
          .map((point) => point.dy)
          .reduce((a, b) => a < b ? a : b);
      expect(sunBottom, greaterThan(bookTop));
    });

    test('the top edge dips at the gutter', () {
      // The dip is what makes the band read as an open book rather than a
      // straight rule, and it is where the sun rises from.
      final left = FajrMarkGeometry.bookPoints[0].dy;
      final gutter = FajrMarkGeometry.bookPoints[1].dy;
      final right = FajrMarkGeometry.bookPoints[2].dy;
      expect(gutter, greaterThan(left));
      expect(left, right);
      expect(FajrMarkGeometry.bookPoints[1].dx, FajrMarkGeometry.units / 2);
    });

    test('the band is a constant weight', () {
      // Top and bottom edges are parallel: each lower point sits the same
      // distance below the upper one it answers to.
      final drops = [
        FajrMarkGeometry.bookPoints[5].dy - FajrMarkGeometry.bookPoints[0].dy,
        FajrMarkGeometry.bookPoints[4].dy - FajrMarkGeometry.bookPoints[1].dy,
        FajrMarkGeometry.bookPoints[3].dy - FajrMarkGeometry.bookPoints[2].dy,
      ];
      expect(drops.toSet(), hasLength(1), reason: 'the band changes weight');
      expect(drops.first, 18);
    });

    test('it is symmetric about the vertical axis', () {
      const mid = FajrMarkGeometry.units / 2;
      expect(FajrMarkGeometry.sunCentre.dx, mid);
      for (final pair in [
        [0, 2],
        [5, 3],
      ]) {
        final left = FajrMarkGeometry.bookPoints[pair[0]];
        final right = FajrMarkGeometry.bookPoints[pair[1]];
        expect(mid - left.dx, right.dx - mid);
        expect(left.dy, right.dy);
      }
    });

    test('the kerf is wide enough to survive a status bar', () {
      // Android flattens the notification icon to one colour. Without a gap
      // the disc and the band merge into a lump at 24 px.
      expect(FajrMarkGeometry.kerfWidth, 8);
    });
  });

  group('The widget draws', () {
    testWidgets('at the size it was given', (tester) async {
      await tester.pumpWidget(_wrap(const FajrMark(size: 64)));
      expect(tester.getSize(find.byType(FajrMark)), const Size(64, 64));
    });

    testWidgets('in colour and in one flat colour, without throwing', (
      tester,
    ) async {
      // The monochrome path clears the kerf inside a saved layer; a mistake
      // there punches a hole through whatever is behind the widget.
      await tester.pumpWidget(
        _wrap(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FajrMark(size: 48),
              FajrMark(size: 24, monochrome: true),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the lockup drops the Latin line before the Arabic', (
      tester,
    ) async {
      // A wordmark too small to read is noise, so it goes rather than shrinks.
      await tester.pumpWidget(_wrap(const FajrLockup(markSize: 96)));
      expect(find.text('الفجر'), findsOneWidget);
      expect(find.text('FAJR'), findsOneWidget);

      await tester.pumpWidget(_wrap(const FajrLockup(markSize: 48)));
      expect(find.text('الفجر'), findsOneWidget);
      expect(find.text('FAJR'), findsNothing);

      await tester.pumpWidget(_wrap(const FajrLockup(markSize: 24)));
      expect(find.text('الفجر'), findsNothing);
    });
  });

  group('The assets on disk', () {
    test('every icon the build needs is present', () {
      for (final path in [
        'icon.png',
        'assets/brand/icon-foreground.png',
        'assets/brand/icon-monochrome.png',
        'android/app/src/main/res/drawable/ic_stat_fajr.xml',
        'android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
      }
    });

    test('the status-bar icon is a stencil, not the launcher icon', () {
      // Android keeps only the alpha of a small icon and fills the rest white.
      // Pointing it at the full-bleed launcher mipmap drew a solid white block
      // in the status bar for every prayer reminder.
      final source =
          File(
            'lib/core/services/notification_service.dart',
          ).readAsStringSync();
      expect(source, contains("'@drawable/ic_stat_fajr'"));
      expect(source, isNot(contains('@mipmap/launcher_icon')));
    });

    test('the notification vector carries the kerf', () {
      final xml =
          File(
            'android/app/src/main/res/drawable/ic_stat_fajr.xml',
          ).readAsStringSync();
      // The clip is what holds the sun off the book once both are white.
      expect(xml, contains('clip-path'));
      expect(xml, contains('#FFFFFFFF'));
    });

    test('the launch window is the app\'s ground in both themes', () {
      // It was white, and neither theme's ground is white, so every cold start
      // flashed.
      for (final path in [
        'android/app/src/main/res/values/launch_colors.xml',
        'android/app/src/main/res/values-night/launch_colors.xml',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('launch_background'),
          reason: path,
        );
      }
      for (final path in [
        'android/app/src/main/res/drawable/launch_background.xml',
        'android/app/src/main/res/drawable-v21/launch_background.xml',
      ]) {
        final xml = File(path).readAsStringSync();
        expect(xml, contains('@color/launch_background'), reason: path);
        expect(xml, isNot(contains('@android:color/white')), reason: path);
      }
    });
  });
}
