import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/localization/app_localizations.dart';
import 'package:islamic_app/core/theme/app_theme.dart';
import 'package:islamic_app/core/theme/design_tokens.dart';
import 'package:islamic_app/core/utils/arabic_numerals.dart';
import 'package:islamic_app/features/settings/presentation/pages/notification_center_page.dart';
import 'package:islamic_app/shared/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _alarmsChannel = MethodChannel('islamic_app/alarms');
const _deliveryChannel = MethodChannel('islamic_app/adhan_sound');
const _timezoneChannel = MethodChannel('flutter_timezone');
const _notificationsChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

const _brandSamples = <String, String>{
  'Xiaomi': 'delivery_steps_xiaomi',
  'Redmi': 'delivery_steps_xiaomi',
  'POCO': 'delivery_steps_xiaomi',
  'HUAWEI': 'delivery_steps_huawei',
  'HONOR': 'delivery_steps_honor',
  'HiHonor': 'delivery_steps_honor',
  'OPPO': 'delivery_steps_oppo',
  'realme': 'delivery_steps_oppo',
  'vivo': 'delivery_steps_vivo',
  'iQOO': 'delivery_steps_vivo',
  'samsung': 'delivery_steps_samsung',
  'OnePlus': 'delivery_steps_oneplus',
  'TECNO': 'delivery_steps_tecno',
  'Infinix': 'delivery_steps_tecno',
  'itel': 'delivery_steps_tecno',
  'motorola': 'delivery_steps_motorola',
  'Nothing': 'delivery_steps_nothing',
  'asus': 'delivery_steps_asus',
  'Meizu': 'delivery_steps_meizu',
  'Google': 'delivery_steps_generic',
  '': 'delivery_steps_generic',
};

Map<Object?, Object?>? _diagnostics;

void _mockChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(_timezoneChannel, (call) async {
    if (call.method == 'getLocalTimezone') {
      return 'Africa/Cairo';
    }
    return null;
  });

  messenger.setMockMethodCallHandler(_notificationsChannel, (call) async {
    switch (call.method) {
      case 'initialize':
        return true;
      case 'pendingNotificationRequests':
      case 'getActiveNotifications':
        return <Map<String, Object?>>[];
      case 'areNotificationsEnabled':
      case 'canScheduleExactNotifications':
        return true;
      default:
        return null;
    }
  });

  messenger.setMockMethodCallHandler(_deliveryChannel, (call) async {
    switch (call.method) {
      case 'isIgnoringBatteryOptimizations':
        return true;
      case 'deviceManufacturer':
        return _diagnostics?['manufacturer'] ?? '';
      case 'requestIgnoreBatteryOptimizations':
      case 'openAppNotificationSettings':
      case 'openAutostartSettings':
        return true;
      default:
        return null;
    }
  });

  messenger.setMockMethodCallHandler(_alarmsChannel, (call) async {
    if (call.method == 'diagnostics') {
      return _diagnostics;
    }
    return null;
  });
}

void _clearChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_timezoneChannel, null);
  messenger.setMockMethodCallHandler(_notificationsChannel, null);
  messenger.setMockMethodCallHandler(_deliveryChannel, null);
  messenger.setMockMethodCallHandler(_alarmsChannel, null);
}

Widget _wrap() {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.from(AppTokens.light),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const NotificationCenterPage(),
    ),
  );
}

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

String _ar(String key) => AppLocalizations.translate('ar', key);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    await initializeThemeProvider();
    _diagnostics = null;
    _mockChannels();
  });

  tearDown(_clearChannels);

  test('every brand has how-to steps in Arabic and English', () {
    for (final key in deliveryBrandStepKeys) {
      for (final language in ['ar', 'en']) {
        final text = AppLocalizations.translate(language, key);
        expect(text, isNot(equals(key)), reason: '$language $key');
        final lines =
            text.split('\n').where((line) => line.trim().isNotEmpty).toList();
        expect(lines.length, inInclusiveRange(2, 4), reason: '$language $key');
        for (final line in lines) {
          expect(line.trim(), isNotEmpty, reason: '$language $key');
        }
      }

      final arabic = AppLocalizations.translate('ar', key);
      for (final jargon in [
        'bucket',
        'standby',
        'API',
        'Android',
        'Autostart',
        'Battery',
        'Settings',
      ]) {
        expect(
          arabic.toLowerCase(),
          isNot(contains(jargon.toLowerCase())),
          reason: '$key Arabic still has "$jargon"',
        );
      }
    }

    expect(
      deliveryBrandStepKeys.toSet(),
      containsAll([
        'delivery_steps_xiaomi',
        'delivery_steps_huawei',
        'delivery_steps_honor',
        'delivery_steps_oppo',
        'delivery_steps_vivo',
        'delivery_steps_samsung',
        'delivery_steps_oneplus',
        'delivery_steps_tecno',
        'delivery_steps_motorola',
        'delivery_steps_nothing',
        'delivery_steps_asus',
        'delivery_steps_meizu',
        'delivery_steps_generic',
      ]),
    );
  });

  test('the maker string picks the matching how-to', () {
    _brandSamples.forEach((manufacturer, key) {
      expect(deliveryStepsKeyFor(manufacturer), key, reason: manufacturer);
    });
  });

  testWidgets('the card keeps the old content when the engine is away', (
    tester,
  ) async {
    await _pumpPage(tester);

    expect(find.text(_ar('delivery_title')), findsOneWidget);
    expect(find.text(_ar('delivery_run')), findsOneWidget);
    expect(find.text(_ar('delivery_headline_ok')), findsNothing);
    expect(find.text(_ar('delivery_headline_missed')), findsNothing);
    expect(find.text(_ar('delivery_how_to')), findsNothing);

    await tester.ensureVisible(find.text(_ar('delivery_run')));
    await tester.tap(find.text(_ar('delivery_run')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(_ar('delivery_permission')), findsOneWidget);
    expect(find.text(_ar('delivery_test')), findsOneWidget);
    expect(find.text(_ar('delivery_headline_ok')), findsNothing);
    expect(find.text(_ar('delivery_headline_missed')), findsNothing);
    expect(find.text(_ar('delivery_how_to')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('misses, plan and Xiaomi steps are reported in plain Arabic', (
    tester,
  ) async {
    final missedAt = DateTime.now().subtract(const Duration(days: 2, hours: 3));
    final lastFired = DateTime.now().subtract(const Duration(hours: 5));
    final planEnds = DateTime.now().add(const Duration(days: 40));

    _diagnostics = {
      'planSize': 210,
      'planEndsAt': planEnds.millisecondsSinceEpoch,
      'lastFiredAt': lastFired.millisecondsSinceEpoch,
      'missed': jsonEncode([
        {'id': 1001, 'due': missedAt.millisecondsSinceEpoch},
      ]),
      'canScheduleExact': false,
      'backgroundRestricted': true,
      'powerSaveMode': true,
      'forceStopped': true,
      'standbyBucket': 40,
      'manufacturer': 'Xiaomi',
      'sdkInt': 35,
    };

    await _pumpPage(tester);
    await tester.ensureVisible(find.text(_ar('delivery_run')));
    await tester.tap(find.text(_ar('delivery_run')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(_ar('delivery_headline_missed')), findsOneWidget);
    expect(find.text(_ar('delivery_headline_ok')), findsNothing);
    expect(
      find.text(
        AppLocalizations.translate(
          'ar',
          'delivery_missed_week',
          replacements: {'count': localizeDigitsFor('ar', '1')},
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(_ar('delivery_last_fired').split('{').first),
      findsOneWidget,
    );
    expect(
      find.text(
        AppLocalizations.translate(
          'ar',
          'delivery_plan_size',
          replacements: {'count': localizeDigitsFor('ar', '210')},
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(_ar('delivery_plan_until').split('{').first),
      findsOneWidget,
    );
    expect(find.text(_ar('delivery_blocker_exact')), findsOneWidget);
    expect(find.text(_ar('delivery_blocker_background')), findsOneWidget);
    expect(find.text(_ar('delivery_blocker_throttled')), findsOneWidget);
    expect(find.text(_ar('delivery_blocker_force_stopped')), findsOneWidget);
    expect(find.text(_ar('delivery_blocker_power_save')), findsOneWidget);
    expect(find.text(_ar('delivery_how_to')), findsOneWidget);
    expect(find.textContaining('التشغيل التلقائي'), findsWidgets);
    expect(find.text(_ar('delivery_test')), findsOneWidget);
    expect(find.text(_ar('delivery_permission')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
