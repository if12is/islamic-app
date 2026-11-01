import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/theme/app_theme.dart';
import 'package:islamic_app/core/theme/design_tokens.dart';
import 'package:islamic_app/features/azkar/domain/azkar_share_copy.dart';
import 'package:islamic_app/features/azkar/presentation/pages/azkar_share_page.dart';

void main() {
  testWidgets('the share page fits a narrow phone in both designs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.from(AppTokens.light),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
        home: const AzkarSharePage(period: AzkarSharePeriod.morning),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('أذكار الصباح'), findsWidgets);

    await tester.tap(find.text('أخضر'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ليلي'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ورقي'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
