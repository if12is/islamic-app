import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/localization/app_localizations.dart';
import 'package:islamic_app/core/models/adhan_sound.dart';
import 'package:islamic_app/core/services/adhan_library.dart';
import 'package:islamic_app/core/theme/app_theme.dart';
import 'package:islamic_app/core/theme/design_tokens.dart';
import 'package:islamic_app/features/settings/presentation/pages/adhan_library_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _ar(String key) => AppLocalizations.translate('ar', key);

Widget _wrap() {
  return MaterialApp(
    theme: AppTheme.from(AppTokens.light),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: AdhanLibraryPage(
      current: AdhanSoundSelection.system,
      onSelected: (_) async {},
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap());
  await tester.pump();
  await tester.pump();
}

int _count(bool Function(AdhanVoice) test) =>
    AdhanLibrary.voices.where(test).length;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AdhanLibrary.resetForTest();
  });

  testWidgets('region headings render for every region with voices', (
    tester,
  ) async {
    await _open(tester);

    for (final region in AdhanRegion.values) {
      if (AdhanLibrary.voices.any((v) => v.region == region)) {
        // A place line can read the same as its heading («مصر»), so at least
        // one rather than exactly one.
        expect(find.text(_ar('adhan_region_${region.name}')), findsWidgets);
      }
    }
    expect(find.text(_ar('adhan_library_note')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Fajr filter lists only Fajr voices', (tester) async {
    await _open(tester);
    await tester.tap(find.text(_ar('adhan_filter_fajr')));
    await tester.pump();

    expect(
      find.text(_ar('adhan_choose')),
      findsNWidgets(_count((v) => v.fajr)),
    );
    // Fajr chips appear once per Fajr row and nowhere else.
    expect(
      find.text(_ar('adhan_chip_fajr')),
      findsNWidgets(_count((v) => v.fajr)),
    );
  });

  testWidgets('the rare filter lists only rare voices', (tester) async {
    await _open(tester);
    await tester.tap(find.text(_ar('adhan_filter_rare')));
    await tester.pump();

    expect(
      find.text(_ar('adhan_choose')),
      findsNWidgets(_count((v) => v.rare)),
    );
    expect(
      find.text(_ar('adhan_chip_rare')),
      findsNWidgets(_count((v) => v.rare)),
    );
  });
}
