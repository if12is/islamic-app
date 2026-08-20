import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/theme/app_theme.dart';
import 'package:islamic_app/core/theme/design_tokens.dart';
import 'package:islamic_app/core/widgets/app_cards.dart';
import 'package:islamic_app/core/widgets/app_section.dart';
import 'package:islamic_app/core/widgets/arc_gauge.dart';
import 'package:islamic_app/core/widgets/ayah_block.dart';
import 'package:islamic_app/core/widgets/story_rail.dart';

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

    testWidgets('the arc gauge, in both directions', (tester) async {
      for (final direction in TextDirection.values) {
        await pumpTight(
          tester,
          host(
            const Center(
              child: ArcGauge(
                progress: 0.62,
                headline: '٥:٤٨',
                headlineSuffix: 'م',
                caption: 'المغرب · ٤٢ د',
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

    testWidgets('the shortcuts rail', (tester) async {
      await pumpTight(
        tester,
        host(
          StoryRail(
            items: [
              for (final label in [
                'آخر قراءة',
                'الورد اليومي',
                'اتجاه القبلة',
                'عداد التسبيح',
                'التقويم الهجري',
              ])
                StoryItem(icon: Icons.star, label: label, onTap: () {}),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
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
