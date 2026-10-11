import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/secure_http_client.dart';
import 'package:islamic_app/features/haramain/data/haramain_refresh_policy.dart';
import 'package:islamic_app/features/haramain/data/haramain_schedule_parser.dart';
import 'package:islamic_app/features/haramain/data/haramain_schedule_repository.dart';
import 'package:islamic_app/features/haramain/domain/haramain_week.dart';
import 'package:shared_preferences/shared_preferences.dart';

// test/fixtures/shahdnow_haramain_posts.json is the real answer of
//   https://shahdnow.sa/wp-json/wp/v2/posts?search=الجدول الأسبوعي لأئمة الحرمين
//   &per_page=3&_fields=id,date_gmt,link,title,content
// captured on 2026-10-11: weeks 30 Rabi' II - 6 Jumada I (a month boundary),
// 23-29 Rabi' II and 16-22 Rabi' II (one month named once), newest first.

const _newsUrl = 'https://www.al-madina.com/sitemaps/newsSitemap.xml';

final List<Map<String, dynamic>> _posts =
    (jsonDecode(
              File(
                'test/fixtures/shahdnow_haramain_posts.json',
              ).readAsStringSync(),
            )
            as List)
        .cast<Map<String, dynamic>>();

bool _isShahd(String url) => url.startsWith('https://shahdnow.sa/wp-json/');

/// What the repository asks Shahd Now for, answered with [posts].
String _shahdBody([List<Map<String, dynamic>>? posts]) =>
    jsonEncode(posts ?? _posts);

HaramainWeek _parsePost(Map<String, dynamic> post) {
  final week = HaramainScheduleParser().parse(
    HaramainScheduleParser.extractWordPressText(
      post['content']['rendered'] as String,
    ),
    sourceUrl: post['link'] as String,
    fetchedAt: DateTime.utc(2026, 10, 11),
  );
  expect(week, isNotNull, reason: 'post ${post['id']} should parse');
  return week!;
}

/// Al-Madina's AMP page for the week of 23-29 Rabi' II (the one that was
/// current before this week, and never followed by a post there).
const _madinaHtml = '''
<div class="abody">أعلنت رئاسة الشؤون الدينية الجدول الأسبوعي لأئمة الحرمين الشريفين، للمدة من يوم الأحد 23 ربيع الآخر إلى يوم السبت 29 ربيع الآخر 1448هـ.<br>
أولًا: أئمة المسجد الحرام:<br>
* صلاة الفجر: فضيلة الشيخ د. الوليد الشمسان .<br>
* صلاة الظهر: فضيلة الشيخ د. اسامة خياط.<br>
* صلاة العصر: معالي الشيخ د. صالح بن حميد .<br>
* صلاة المغرب: فضيلة الشيخ أ.د. ماهر المعيقلي<br>
* صلاة العشاء: معالي الشيخ أ.د عبدالرحمنالسديس<br>
ثانيًا: أئمة المسجد النبوي:<br>
* صلاة الفجر: فضيلة الشيخ صالح المغامسي .<br>
* صلاة الظهر: فضيلة الشيخ د. عبدالباري الثبيتي .<br>
* صلاة العصر: فضيلة الشيخ د. عبدالمحسن القاسم .<br>
* صلاة المغرب: فضيلة الشيخ د. أحمد الحذيفي .<br>
* صلاة العشاء: فضيلة الشيخ د. عبدالله البعيجان .</div>''';

const _madinaNews = '''
<urlset><url>
  <loc>https://www.al-madina.com/article/1008801/x/y</loc>
  <news:news><news:title>إعلان الجدول الأسبوعي لأئمة الحرمين الشريفين</news:title></news:news>
</url></urlset>''';

void main() {
  group('Shahd Now text extraction', () {
    test('paragraphs, breaks and list items become lines; entities decode', () {
      final text = HaramainScheduleParser.extractWordPressText(
        '<p>a &amp; b</p><p><img src="x.jpg" alt="" /></p><p>&nbsp;</p>'
        '<ul><li>c&#8211;d</li><li>e</li></ul>f<br />g&#x41;',
      );
      final lines = text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty);
      expect(lines, ['a & b', 'c–d', 'e', 'f', 'gA']);
      expect(text, isNot(contains('<')));
    });
  });

  group('parser on real Shahd Now posts', () {
    test('this week crosses a month and ends on a Saturday', () {
      final week = _parsePost(_posts[0]);
      expect(week.startHijri, '30 ربيع الآخر');
      expect(week.endHijri, '6 جمادى الأولى');
      expect(week.hijriYear, 1448);
      expect(week.endsOn, DateTime.utc(2026, 10, 17));
      expect(week.endsOn.weekday, DateTime.saturday);
      // Derived from the end: day 30 of a 29-day month cannot be converted.
      expect(week.startsOn, DateTime.utc(2026, 10, 11));
      expect(week.startsOn.weekday, DateTime.sunday);
      expect(week.sourceUrl, 'https://shahdnow.sa/363520/');

      expect(week.haram[HaramainPrayer.fajr]!.displayName, 'بدر التركي');
      expect(week.haram[HaramainPrayer.dhuhr]!.displayName, 'ياسر الدوسري');
      expect(week.haram[HaramainPrayer.maghrib]!.displayName, 'فيصل غزاوي');
      expect(week.haram[HaramainPrayer.isha]!.displayName, 'عبدالله الجهني');
      expect(week.nabawi[HaramainPrayer.fajr]!.displayName, 'محمد البرهجي');
      expect(
        week.nabawi[HaramainPrayer.asr]!.displayName,
        'علي بن عبدالرحمن الحذيفي',
      );
      expect(week.nabawi[HaramainPrayer.isha]!.displayName, 'عبدالله القرافي');
      expect(week.haram.length, 5);
      expect(week.nabawi.length, 5);
    });

    test('a single-month week names the month once', () {
      final week = _parsePost(_posts[1]);
      expect(week.startHijri, '23 ربيع الآخر');
      expect(week.endHijri, '29 ربيع الآخر');
      expect(week.endsOn, DateTime.utc(2026, 10, 10));
      expect(week.startsOn, DateTime.utc(2026, 10, 4));
      expect(week.haram[HaramainPrayer.fajr]!.displayName, 'الوليد الشمسان');
      expect(week.haram[HaramainPrayer.isha]!.rosterId, 'haram_sudais');
      expect(week.nabawi[HaramainPrayer.isha]!.displayName, 'عبدالله البعيجان');
    });

    test('the oldest of the three', () {
      final week = _parsePost(_posts[2]);
      expect(week.startHijri, '16 ربيع الآخر');
      expect(week.endsOn, DateTime.utc(2026, 10, 3));
      expect(week.haram[HaramainPrayer.isha]!.displayName, 'بدر التركي');
      expect(
        week.nabawi[HaramainPrayer.asr]!.displayName,
        'علي بن عبدالرحمن الحذيفي',
      );
    });
  });

  group('repository with two sources', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    /// Stores last week from Al-Madina, as the app did before this week.
    Future<void> seedMadinaWeek() async {
      final repository = HaramainScheduleRepository(
        clock: () => DateTime.utc(2026, 10, 10, 19, 30),
        fetchText: (url) async {
          if (_isShahd(url)) {
            throw StateError('offline');
          }
          return url == _newsUrl ? _madinaNews : _madinaHtml;
        },
      );
      final seeded = await repository.refresh();
      expect(seeded.week!.sourceUrl, contains('al-madina.com'));
    }

    // Sunday 07:53 Makkah, when this week's post actually appeared.
    final sunday = DateTime.utc(2026, 10, 11, 4, 55);

    test('Shahd Now supplies the week Al-Madina never posted', () async {
      await seedMadinaWeek();

      final asked = <String>[];
      final repository = HaramainScheduleRepository(
        clock: () => sunday,
        fetchText: (url) async {
          asked.add(url);
          if (_isShahd(url)) {
            return _shahdBody();
          }
          return url == _newsUrl ? _madinaNews : _madinaHtml;
        },
      );

      final result = await repository.refresh();
      expect(result.failed, isFalse);
      expect(result.week!.sourceUrl, 'https://shahdnow.sa/363520/');
      expect(result.week!.endsOn, DateTime.utc(2026, 10, 17));
      expect(asked, hasLength(1), reason: 'a newer week ends the search');
      expect(
        (await repository.loadCached())!
            .haram[HaramainPrayer.fajr]!
            .displayName,
        'بدر التركي',
      );
    });

    test(
      'the refresh rules ask on Sunday morning after the week ended',
      () async {
        await seedMadinaWeek();
        final cached = (await HaramainScheduleRepository().loadCached())!;
        expect(
          HaramainRefreshPolicy.shouldFetch(
            cached: cached,
            lastCheckedAt: sunday.subtract(const Duration(minutes: 31)),
            now: sunday,
          ),
          isTrue,
        );
        expect(
          HaramainRefreshPolicy.shouldFetch(
            cached: cached,
            lastCheckedAt: sunday.subtract(const Duration(minutes: 10)),
            now: sunday,
          ),
          isFalse,
        );
      },
    );

    test('falls back to Al-Madina when Shahd Now throws', () async {
      final repository = HaramainScheduleRepository(
        clock: () => sunday,
        fetchText: (url) async {
          if (_isShahd(url)) {
            throw StateError('down');
          }
          return url == _newsUrl ? _madinaNews : _madinaHtml;
        },
      );

      final result = await repository.refresh();
      expect(result.failed, isFalse);
      expect(result.week!.sourceUrl, contains('al-madina.com'));
      expect(result.week!.endsOn, DateTime.utc(2026, 10, 10));
    });

    test('falls back to Al-Madina when Shahd Now sends nonsense', () async {
      final repository = HaramainScheduleRepository(
        clock: () => sunday,
        fetchText: (url) async {
          if (_isShahd(url)) {
            return '<html>maintenance</html>';
          }
          return url == _newsUrl ? _madinaNews : _madinaHtml;
        },
      );

      final result = await repository.refresh();
      expect(result.week!.sourceUrl, contains('al-madina.com'));
    });

    test('the newer week wins, not the source tried first', () async {
      // Shahd Now only has the older weeks here; Al-Madina's is newer.
      final repository = HaramainScheduleRepository(
        clock: () => sunday,
        fetchText: (url) async {
          if (_isShahd(url)) {
            return _shahdBody([_posts[2]]);
          }
          return url == _newsUrl ? _madinaNews : _madinaHtml;
        },
      );

      final result = await repository.refresh();
      expect(result.week!.sourceUrl, contains('al-madina.com'));
      expect(result.week!.endsOn, DateTime.utc(2026, 10, 10));
    });

    test('keeps the cached week when both sources fail', () async {
      await seedMadinaWeek();

      final repository = HaramainScheduleRepository(
        clock: () => sunday,
        fetchText: (url) async => throw StateError('offline'),
      );
      final result = await repository.refresh();
      expect(result.failed, isTrue);
      expect(result.week!.sourceUrl, contains('al-madina.com'));
      expect(
        (await repository.loadCached())!.endsOn,
        DateTime.utc(2026, 10, 10),
      );
    });

    test('an older week from Shahd Now confirms the cached one', () async {
      final first = HaramainScheduleRepository(
        clock: () => DateTime.utc(2026, 10, 11, 4, 55),
        fetchText: (url) async {
          if (_isShahd(url)) {
            return _shahdBody();
          }
          throw StateError('not needed');
        },
      );
      await first.refresh();

      final later = HaramainScheduleRepository(
        clock: () => DateTime.utc(2026, 10, 12, 4, 55),
        fetchText: (url) async {
          if (_isShahd(url)) {
            return _shahdBody([_posts[1], _posts[2]]);
          }
          return url == _newsUrl ? _madinaNews : _madinaHtml;
        },
      );
      final result = await later.refresh(force: true);
      expect(result.failed, isFalse);
      expect(result.week!.sourceUrl, 'https://shahdnow.sa/363520/');
      expect(result.week!.fetchedAt, DateTime.utc(2026, 10, 12, 4, 55));
    });
  });

  test('Shahd Now is on the secure client allowlist', () {
    expect(SecureHttpClient.allowedHosts, contains('shahdnow.sa'));
  });
}
