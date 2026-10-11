import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/localization/app_localizations.dart';
import 'package:islamic_app/core/theme/app_theme.dart';
import 'package:islamic_app/core/theme/design_tokens.dart';
import 'package:islamic_app/features/haramain/domain/haramain_week.dart';
import 'package:islamic_app/features/haramain/presentation/pages/haramain_imams_page.dart';
import 'package:islamic_app/features/haramain/presentation/providers/haramain_provider.dart';

class _FixedController extends HaramainController {
  _FixedController(this.initial);

  final HaramainState initial;
  int retries = 0;

  @override
  HaramainState build() => initial;

  @override
  Future<void> retry() async => retries++;
}

Map<HaramainPrayer, ImamEntry> _block(List<String> names) {
  return {
    for (var i = 0; i < 5; i++)
      HaramainPrayer.values[i]: ImamEntry(
        rawName: names[i],
        displayName: names[i],
      ),
  };
}

final _week = HaramainWeek(
  startHijri: '23 ربيع الآخر',
  endHijri: '29 ربيع الآخر',
  hijriYear: 1448,
  endsOn: DateTime.utc(2099, 1, 2),
  fetchedAt: DateTime.utc(2026, 10, 10, 19, 30),
  sourceUrl: 'https://www.al-madina.com/article/1007788/x',
  haram: _block([
    'الوليد الشمسان',
    'أسامة خياط',
    'صالح بن حميد',
    'ماهر المعيقلي',
    'عبدالرحمن السديس',
  ]),
  nabawi: _block([
    'صالح المغامسي',
    'عبدالباري الثبيتي',
    'عبدالمحسن القاسم',
    'أحمد بن علي الحذيفي',
    'عبدالله البعيجان',
  ]),
);

Widget _app(_FixedController controller) {
  return ProviderScope(
    overrides: [haramainProvider.overrideWith(() => controller)],
    child: MaterialApp(
      theme: AppTheme.from(AppTokens.light),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HaramainImamsPage(),
    ),
  );
}

void main() {
  testWidgets('shows both mosques, five rows each, and the source line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_FixedController(HaramainState(week: _week))));
    await tester.pump();

    expect(find.text('المسجد الحرام'), findsOneWidget);
    expect(find.text('المسجد النبوي'), findsOneWidget);
    expect(find.text('ماهر المعيقلي'), findsOneWidget);
    expect(find.text('عبدالله البعيجان'), findsOneWidget);
    expect(find.text('المصدر: صحيفة المدينة'), findsOneWidget);
    // Digits follow the interface language.
    expect(find.textContaining('٢٣ ربيع الآخر'), findsOneWidget);
    expect(find.textContaining('١٤٤٨'), findsOneWidget);
    // The week has not ended, so no stale note.
    expect(find.text('الجدول الجديد يصدر مساء السبت'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an ended week says when the next one comes out', (tester) async {
    final ended = HaramainWeek(
      startHijri: _week.startHijri,
      endHijri: _week.endHijri,
      hijriYear: _week.hijriYear,
      endsOn: DateTime.utc(2020, 1, 4),
      fetchedAt: _week.fetchedAt,
      sourceUrl: _week.sourceUrl,
      haram: _week.haram,
      nabawi: _week.nabawi,
    );
    await tester.pumpWidget(_app(_FixedController(HaramainState(week: ended))));
    await tester.pump();

    expect(find.text('الجدول الجديد يصدر مساء السبت'), findsOneWidget);
    expect(find.text('ماهر المعيقلي'), findsOneWidget);
  });

  testWidgets('with nothing cached and no network, offers a retry', (
    tester,
  ) async {
    final controller = _FixedController(const HaramainState(failed: true));
    await tester.pumpWidget(_app(controller));
    await tester.pump();

    expect(
      find.text(AppLocalizations.translate('ar', 'haramain_unavailable')),
      findsOneWidget,
    );
    await tester.tap(find.text(AppLocalizations.translate('ar', 'retry')));
    expect(controller.retries, 1);
  });
}
