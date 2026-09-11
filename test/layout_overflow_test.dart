import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/theme/app_theme.dart';
import 'package:islamic_app/core/theme/design_tokens.dart';
import 'package:islamic_app/core/utils/duration_words.dart';
import 'package:islamic_app/core/widgets/app_cards.dart';
import 'package:islamic_app/core/widgets/app_section.dart';
import 'package:islamic_app/core/widgets/arc_gauge.dart';
import 'package:islamic_app/core/widgets/ayah_block.dart';
import 'package:islamic_app/core/widgets/shortcut_grid.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';
import 'package:islamic_app/features/quran/presentation/widgets/surah_cover_art.dart';

/// The yellow-and-black stripe is a bug, not a warning.
///
/// It comes from a fixed height that a font metric or a longer word outgrows,
/// which means it appears on someone else's phone and never on yours. These
/// tests squeeze each component into a narrow, short viewport with the longest
/// strings the app can produce, in both directions, and fail if anything
/// overflows by a single pixel.
void main() {
  Widget host(Widget child, {TextDirection direction = TextDirection.rtl}) {
    return MaterialApp(
      theme: AppTheme.from(AppTokens.light),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  /// A cramped phone: small width, large text.
  Future<void> pumpTight(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: child,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('Nothing overflows', () {
    testWidgets('the hero card, with a long title and a long subtitle', (
      tester,
    ) async {
      await pumpTight(
        tester,
        host(
          const HeroCard(
            label: 'آخر قراءة',
            title: 'سورة الصافات والذاريات والمرسلات',
            subtitle: 'الآية ١٤٢ من ٢٨٦ · صفحة ٢٢ · الجزء الثالث',
            actionLabel: 'استمر في التلاوة',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the hero card with a second way on', (tester) async {
      for (final direction in TextDirection.values) {
        await pumpTight(
          tester,
          host(
            direction: direction,
            HeroCard(
              label: 'آخر قراءة',
              title: 'سورة الصافات',
              subtitle: 'الآية ١٤٢ من ١٨٢ · صفحة ٤٥٠',
              actionLabel: 'استمر في التلاوة',
              secondaryLabel: 'مواضع القراءة السابقة',
              secondaryIcon: Icons.history,
              onSecondaryTap: () {},
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$direction');
      }
    });

    testWidgets('the player cover, small, with the longest names', (
      tester,
    ) async {
      // The cover gives up its room first on a short screen; the name, the
      // kind of surah and the verse count all have to fit inside the arch.
      for (final surah in [7, 18, 26, 114]) {
        await pumpTight(
          tester,
          host(
            Center(
              child: SurahCoverArt(
                size: 150,
                info: QuranLocalService.surahInfo(surah),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'surah $surah');
      }
    });

    testWidgets('the progress card', (tester) async {
      await pumpTight(
        tester,
        host(
          const ProgressCard(
            title: 'الورد اليومي المركّب',
            subtitle: 'قرآن وأذكار وتسبيح — كلها في مكان واحد',
            value: 0.4,
            trailingText: '١٢/٣٠',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the arc gauge shows the remaining time', (tester) async {
      await pumpTight(
        tester,
        host(
          const Center(
            child: ArcGauge(
              progress: 0.5,
              headline: 'ساعتان و٤٢ دقيقة',
              caption: 'حتى المغرب · ٥:٤٨ م',
              startLabel: 'العصر',
              endLabel: 'المغرب',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // The countdown is the headline now, not a pill at the foot of the arc,
      // and it is the one number the screen exists to show.
      expect(find.text('ساعتان و٤٢ دقيقة'), findsOneWidget);
    });

    testWidgets('the countdown stays inside the arc', (tester) async {
      // The headline is words now, and Arabic words are long: "ساعتان و٥٩
      // دقيقة" is three times the width of the "٥:٤٨" that used to sit here.
      // It has to shrink to fit rather than run out over the arc's stroke.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(
          const Center(
            child: ArcGauge(
              progress: 0.5,
              headline: 'ساعتان و٥٩ دقيقة',
              headlineParts: [
                DurationPart(unit: 'ساعتان'),
                DurationPart(value: '٥٩', unit: 'دقيقة'),
              ],
              caption: 'حتى العصر · ٤:٢٧ م',
              footnote: 'دمنهور، البحيرة، مصر',
              startLabel: 'الظهر',
              startTime: '١٢:٥٦ م',
              endLabel: 'العصر',
              endTime: '٤:٢٧ م',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // The digits must still be reading size after the fit. Set as one
      // string this line shrank to about 17px — smaller than the caption
      // under it, which is the opposite of what promoting it was for.
      final digits = tester.getRect(find.text('٥٩'));
      expect(
        digits.height,
        greaterThan(24),
        reason:
            'the countdown shrank to ${digits.height}px tall, which is '
            'smaller than the caption beneath it',
      );
    });

    testWidgets('the arc gauge, in both directions', (tester) async {
      for (final direction in TextDirection.values) {
        await pumpTight(
          tester,
          host(
            const Center(
              child: ArcGauge(
                progress: 0.62,
                headline: 'ساعة و٤٢ دقيقة',
                caption: 'حتى المغرب · ٥:٤٨ م',
                footnote: 'دمنهور، البحيرة، مصر',
                startLabel: 'العصر',
                startTime: '٣:٢٠ م',
                endLabel: 'المغرب',
                endTime: '٥:٤٨ م',
              ),
            ),
            direction: direction,
          ),
        );
        expect(tester.takeException(), isNull, reason: '$direction');
      }
    });

    testWidgets('a list row with everything filled in', (tester) async {
      await pumpTight(
        tester,
        host(
          const AppListRow(
            badge: '١١٤',
            title: 'سورة آل عمران',
            meta: 'مدنية · ٢٠٠ آية · الجزء الثالث',
            trailingText: 'ءَالِ عِمْرَان',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the shortcuts grid', (tester) async {
      await pumpTight(
        tester,
        host(
          ShortcutGrid(
            items: [
              for (final label in [
                'آخر قراءة',
                'الورد اليومي',
                'اتجاه القبلة',
                'عداد التسبيح',
                'التقويم الهجري',
                'تعرّف على التلاوة',
              ])
                ShortcutItem(icon: Icons.star, label: label, onTap: () {}),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // Nothing scrolls sideways and nothing is clipped, so every shortcut is
      // on screen — which is the whole reason the rail became a grid.
      expect(find.text('تعرّف على التلاوة'), findsOneWidget);
    });

    testWidgets('a section header carrying a pill selector', (tester) async {
      await pumpTight(
        tester,
        host(
          SectionHeader(
            title: 'فهرس السور',
            subtitle: '١١٤ سورة',
            trailing: PillSelector<int>(
              compact: true,
              value: 0,
              options: const [
                PillOption(value: 0, label: 'السور'),
                PillOption(value: 1, label: 'الأجزاء'),
                PillOption(value: 2, label: 'الأحزاب'),
                PillOption(value: 3, label: 'الصفحات'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a verse block with a translation', (tester) async {
      await pumpTight(
        tester,
        host(
          const AyahBlock(
            numberLabel: '٢:٢٥٥',
            arabic:
                'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ ۚ '
                'لَا تَأْخُذُهُۥ سِنَةٌ وَلَا نَوْمٌ',
            translation:
                'Allah — there is no deity except Him, the Ever-Living, '
                'the Sustainer of existence.',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('cards in a row share one height', (tester) async {
      await pumpTight(
        tester,
        host(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final label in [
                  'القبلة',
                  'التقويم الهجري',
                  'إعدادات الصلاة',
                ])
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, size: 22),
                          const SizedBox(height: AppSpacing.sm),
                          SizedBox(
                            height: 32,
                            child: Center(
                              child: Text(
                                label,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // A row of shortcuts where one card is taller than its neighbours reads
      // as a mistake, so the heights have to match exactly.
      final heights =
          tester
              .widgetList<AppCard>(find.byType(AppCard))
              .map((card) => tester.getSize(find.byWidget(card)).height)
              .toSet();
      expect(heights.length, 1, reason: 'cards ended up ragged: $heights');
    });

    testWidgets('a hint pill with a long instruction', (tester) async {
      await pumpTight(
        tester,
        host(
          const Center(
            child: HintPill(
              text: 'أدر الهاتف مئة وخمسة وثلاثين درجة جهة اليسار',
              icon: Icons.rotate_left,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
