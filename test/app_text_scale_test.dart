import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/constants/app_constants.dart';
import 'package:islamic_app/shared/providers/app_providers.dart';
import 'package:islamic_app/shared/providers/app_text_scale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the scale that actually reaches a widget under the scope.
Future<double> scaleUnderScope(
  WidgetTester tester, {
  double deviceScale = 1.0,
}) async {
  late double seen;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(deviceScale)),
          child: AppTextScaleScope(
            child: Builder(
              builder: (context) {
                seen = MediaQuery.of(context).textScaler.scale(1);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return seen;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeThemeProvider();
  });

  group('Choosing a size', () {
    test('a fresh install reads as normal', () {
      expect(AppTextScale.fromId(null), AppTextScale.normal);
      expect(AppTextScale.normal.factor, 1.0);
    });

    test('each step is larger than the last', () {
      expect(AppTextScale.large.factor, greaterThan(1.0));
      expect(
        AppTextScale.largest.factor,
        greaterThan(AppTextScale.large.factor),
      );
    });

    test('an id nobody wrote falls back rather than throwing', () {
      // A key left over from a build that named the sizes differently must
      // not take the app down on the first frame.
      expect(AppTextScale.fromId('enormous'), AppTextScale.normal);
      expect(AppTextScale.fromId(''), AppTextScale.normal);
    });

    test('the stored value is the name, not the position', () async {
      // Reordering the enum would otherwise silently resize every screen for
      // everyone who had already chosen.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(appTextScaleProvider.notifier)
          .set(AppTextScale.largest);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.appTextScaleKey), 'largest');
    });

    test('a choice survives a restart', () async {
      SharedPreferences.setMockInitialValues({'app_text_scale': 'large'});
      await initializeThemeProvider();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appTextScaleProvider), AppTextScale.large);
    });
  });

  group('What reaches the screen', () {
    testWidgets('normal leaves the device setting untouched', (tester) async {
      expect(await scaleUnderScope(tester), 1.0);
    });

    testWidgets('the device setting is multiplied, not replaced', (
      tester,
    ) async {
      // Someone who has already enlarged text system-wide has said what they
      // need. Overwriting that would be the app undoing their decision.
      SharedPreferences.setMockInitialValues({'app_text_scale': 'large'});
      await initializeThemeProvider();

      final combined = await scaleUnderScope(tester, deviceScale: 1.2);
      expect(combined, greaterThan(1.2));
    });

    testWidgets('it stops before the layouts do', (tester) async {
      // Past roughly twice the base size a nav label wraps to three lines,
      // which helps nobody. The cap is the promise that the screen still works.
      SharedPreferences.setMockInitialValues({'app_text_scale': 'largest'});
      await initializeThemeProvider();

      expect(await scaleUnderScope(tester, deviceScale: 2.0), 2.0);
    });

    testWidgets('it never shrinks text below the device setting', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'app_text_scale': 'normal'});
      await initializeThemeProvider();

      expect(await scaleUnderScope(tester, deviceScale: 0.8), 1.0);
    });
  });
}
