import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/localization/app_localizations.dart';
import 'package:islamic_app/core/theme/app_theme.dart';
import 'package:islamic_app/core/theme/design_tokens.dart';
import 'package:islamic_app/features/broadcasts/domain/broadcast.dart';
import 'package:islamic_app/features/broadcasts/presentation/pages/broadcasts_page.dart';
import 'package:islamic_app/features/broadcasts/presentation/providers/radio_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      broadcastsProvider.overrideWith(
        (ref) async => const [
          Broadcast(
            id: 'radio:109',
            name: 'تلاوات خاشعة',
            url: 'https://qurango.net/radio/tarateel',
            kind: BroadcastKind.radio,
          ),
        ],
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.from(AppTokens.light),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('the recordings shelf lists both collections and the live row', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const BroadcastsPage()));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.album_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text(AppLocalizations.translate('ar', 'recordings_rare_section')),
      findsOneWidget,
    );
    expect(
      find.text(
        AppLocalizations.translate('ar', 'recordings_taraweeh_section'),
      ),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizations.translate('ar', 'recordings_live_section')),
      findsOneWidget,
    );

    expect(find.text('محمد رفعت'), findsWidgets);
    expect(find.text('أئمة المسجد الحرام'), findsWidgets);
  });
}
