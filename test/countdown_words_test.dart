import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/utils/arabic_numerals.dart';
import 'package:islamic_app/core/utils/duration_words.dart';

/// Renders in one locale and hands back a context that resolves to it.
Future<BuildContext> contextIn(WidgetTester tester, String language) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  group('How long is left', () {
    testWidgets('an hour or more carries its unit', (tester) async {
      // The defect this exists for: above an hour the old code emitted
      // "2:59" — no unit, and the exact shape of a time of day, sitting in a
      // gauge beside three real times of day. People read it as five to three.
      final context = await contextIn(tester, 'ar');
      final text = remainingInWords(
        context,
        const Duration(hours: 2, minutes: 59),
      );

      expect(text, isNot(contains(':')));
      expect(text, contains('دقيقة'));
      expect(text, contains('ساعتان'));
    });

    testWidgets('under an hour says only the minutes', (tester) async {
      final context = await contextIn(tester, 'ar');
      expect(
        remainingInWords(context, const Duration(minutes: 42)),
        '٤٢ دقيقة',
      );
    });

    testWidgets('a whole number of hours drops the minutes', (tester) async {
      final context = await contextIn(tester, 'ar');
      expect(remainingInWords(context, const Duration(hours: 3)), '٣ ساعات');
    });

    testWidgets('nothing left comes back empty', (tester) async {
      // The caller turns this into "it is time"; the helper does not guess.
      final context = await contextIn(tester, 'ar');
      expect(remainingInWords(context, const Duration(seconds: -1)), '');
    });

    testWidgets('zero is zero minutes, not nothing', (tester) async {
      final context = await contextIn(tester, 'ar');
      expect(remainingInWords(context, Duration.zero), '٠ دقيقة');
    });
  });

  group('Arabic counts in four forms', () {
    testWidgets('one takes the singular with no numeral', (tester) async {
      final context = await contextIn(tester, 'ar');
      expect(remainingInWords(context, const Duration(hours: 1)), 'ساعة');
      expect(remainingInWords(context, const Duration(minutes: 1)), 'دقيقة');
    });

    testWidgets('two takes the dual, which carries its own count', (
      tester,
    ) async {
      // "ساعتان" already means two; printing "٢ ساعتان" is the tell of a
      // template rather than a sentence.
      final context = await contextIn(tester, 'ar');
      expect(remainingInWords(context, const Duration(hours: 2)), 'ساعتان');
      expect(remainingInWords(context, const Duration(minutes: 2)), 'دقيقتان');
    });

    testWidgets('three to ten take the plural of paucity', (tester) async {
      final context = await contextIn(tester, 'ar');
      expect(remainingInWords(context, const Duration(minutes: 9)), '٩ دقائق');
      expect(remainingInWords(context, const Duration(hours: 6)), '٦ ساعات');
    });

    testWidgets('eleven and up go back to the singular', (tester) async {
      final context = await contextIn(tester, 'ar');
      expect(
        remainingInWords(context, const Duration(minutes: 25)),
        '٢٥ دقيقة',
      );
    });

    testWidgets('the conjunction joins the two parts', (tester) async {
      final context = await contextIn(tester, 'ar');
      expect(
        remainingInWords(context, const Duration(hours: 1, minutes: 5)),
        'ساعة و٥ دقائق',
      );
    });
  });

  group('In English', () {
    testWidgets('the units are written out too', (tester) async {
      final context = await contextIn(tester, 'en');
      final text = remainingInWords(
        context,
        const Duration(hours: 2, minutes: 59),
      );

      expect(text, isNot(contains(':')));
      expect(text, contains('hr'));
      expect(text, contains('min'));
    });

    testWidgets('digits stay Western', (tester) async {
      final context = await contextIn(tester, 'en');
      expect(remainingInWords(context, const Duration(minutes: 42)), '42 min');
    });
  });

  group('Localising digits', () {
    testWidgets('Arabic gets Arabic-Indic numerals', (tester) async {
      final context = await contextIn(tester, 'ar');
      expect(localizeDigits(context, '2026'), '٢٠٢٦');
    });

    testWidgets('English is left alone', (tester) async {
      final context = await contextIn(tester, 'en');
      expect(localizeDigits(context, '2026'), '2026');
    });
  });
}
