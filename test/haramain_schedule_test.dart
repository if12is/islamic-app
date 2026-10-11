import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/secure_http_client.dart';
import 'package:islamic_app/features/haramain/data/haramain_discovery.dart';
import 'package:islamic_app/features/haramain/data/haramain_name_matcher.dart';
import 'package:islamic_app/features/haramain/data/haramain_refresh_policy.dart';
import 'package:islamic_app/features/haramain/data/haramain_schedule_parser.dart';
import 'package:islamic_app/features/haramain/data/haramain_schedule_repository.dart';
import 'package:islamic_app/features/haramain/data/haramain_week_codec.dart';
import 'package:islamic_app/features/haramain/domain/haramain_roster.dart';
import 'package:islamic_app/features/haramain/domain/haramain_week.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Article bodies captured from https://www.al-madina.com/ampArticle/<id> on
// 2026-10-11, the text inside <div class="abody"> with <br> as newlines.
// Spacing, bullets, doubled titles and typos are exactly as published.

/// 1007788, published Sat 3 Oct 2026. Has «عبدالرحمنالسديس» (lost space) and
/// «اسامة» (no hamza), and «للمدة».
const _week1007788 =
    r'''أعلنت رئاسة الشؤون الدينية بالمسجد الحرام والمسجد النبوي الجدول الأسبوعي لأصحاب المعالي والفضيلة أئمة الحرمين الشريفين، للمدة من يوم الأحد 23 ربيع الآخر إلى يوم السبت 29 ربيع الآخر 1448هـ، وذلك ضمن جهودها في تنظيم شؤون الإمامة وتيسير معرفة جداول الصلوات للمصلين والقاصدين.
أولًا: أئمة المسجد الحرام:
* صلاة الفجر: فضيلة الشيخ د. الوليد الشمسان .
* صلاة الظهر: فضيلة الشيخ د. اسامة خياط.
* صلاة العصر: معالي الشيخ د. صالح بن حميد .
* صلاة المغرب: فضيلة الشيخ أ.د. ماهر المعيقلي
* صلاة العشاء: معالي الشيخ أ.د عبدالرحمنالسديس
ثانيًا: أئمة المسجد النبوي:
* صلاة الفجر: فضيلة الشيخ صالح المغامسي .
* صلاة الظهر: فضيلة الشيخ د. عبدالباري الثبيتي .
* صلاة العصر: فضيلة الشيخ د. عبدالمحسن القاسم .
* صلاة المغرب: فضيلة الشيخ د. أحمد الحذيفي .
* صلاة العشاء: فضيلة الشيخ د. عبدالله البعيجان .
ويأتي إعلان الجدول في إطار جهود رئاسة الشؤون الدينية لتنظيم شؤون الإمامة في المسجد الحرام والمسجد النبوي، وتيسير اطلاع القاصدين على أئمة الصلوات خلال الأسبوع.''';

/// 1000401: «•» bullets, a stray «ط» line inside the Nabawi block, a week
/// that crosses from Safar into Rabi' I.
const _week1000401 =
    r'''أعلنت رئاسة الشؤون الدينية بالمسجد الحرام والمسجد النبوي الجدول الأسبوعي لأصحاب الفضيلة أئمة الحرمين الشريفين للفترة من يوم الأحد 26 صفر إلى يوم السبت 2 ربيع الأول 1448هـ، وذلك ضمن جهودها المستمرة لتنظيم شؤون الإمامة وتيسير متابعة جداول الصلوات لعموم المصلين والزوار.
أولًا: جدول أئمة المسجد الحرام:
• صلاة الفجر: فضيلة الشيخ الدكتور بندر بليلة
• صلاة الظهر: فضيلة الشيخ أ.د ياسر الدوسري
• صلاة العصر: فضيلة الشيخ الدكتور بندر بليلة
• صلاة المغرب: فضيلة الشيخ أ.د ياسر الدوسري
• صلاة العشاء: فضيلة الشيخ أ.د ياسر الدوسري

ثانيًا: جدول أئمة المسجد النبوي:
• صلاة الفجر: فضيلة الشيخ الدكتور خالد المهنا
• صلاة الظهر: فضيلة الشيخ الدكتور أحمد الحذيفي
• صلاة العصر: فضيلة الشيخ أ.د محمد برهجي
• صلاة المغرب: فضيلة الشيخ الدكتور عبدالباري الثبيتي
ط
• صلاة العشاء: فضيلة الشيخ أ.د محمد برهجي
ويأتي اعتماد هذا الجدول في إطار تنظيم شؤون الإمامة بالمسجد الحرام والمسجد النبوي، بما يتيح للمصلين أداء عباداتهم في أجواء روحانية مفعمة بالطمأنينة، وبقيادة أئمةٍ من أهل العلم والخبرة.''';

/// 999369: «غزواي» for «غزاوي», doubled «الشيخ الشيخ الدكتور», a week that
/// ends on 25 Safar.
const _week999369 =
    r'''أعلنت رئاسة الشؤون الدينية بالمسجد الحرام والمسجد النبوي الجدول الأسبوعي لأصحاب الفضيلة أئمة الحرمين الشريفين للفترة من يوم الأحد 19 صفر إلى يوم السبت 25 صفر 1448هـ، وذلك ضمن جهودها المستمرة لتنظيم شؤون الإمامة وتيسير متابعة جداول الصلوات لعموم المصلين والزوار.
أولًا: جدول أئمة المسجد الحرام:
* صلاة الفجر: فضيلة الشيخ بدر التركي
* صلاة الظهر: فضيلة الشيخ الشيخ الدكتور الوليد الشمسان
* صلاة العصر: فضيلة الشيخ بدر التركي
* صلاة المغرب: فضيلة الشيخ أ.د فيصل غزواي
* صلاة العشاء: فضيلة الشيخ الشيخ الدكتور الوليد الشمسان
ثانيًا: أئمة المسجد النبوي:
* صلاة الفجر: فضيلة الشيخ أ.د محمد برهجي
* صلاة الظهر: فضيلة الشيخ الدكتور عبدالله البعيجان
* صلاة العصر: فضيلة الشيخ الدكتور علي الحذيفي
* صلاة المغرب: فضيلة الشيخ الدكتور خالد المهنا
* صلاة العشاء: فضيلة الشيخ الدكتور عبدالله البعيجان
ويأتي اعتماد هذا الجدول في إطار تنظيم شؤون الإمامة بالمسجد الحرام والمسجد النبوي.''';

/// 1005040: «أ.د.» with trailing dots, and the family name «آل الشيخ», whose
/// last word is also a title.
const _week1005040 =
    r'''أعلنت رئاسة الشؤون الدينية بالمسجد الحرام والمسجد النبوي الجدول الأسبوعي لأصحاب الفضيلة أئمة الحرمين الشريفين، للفترة من يوم الأحد 2 ربيع الآخر إلى يوم السبت 8 ربيع الآخر 1448هـ، ضمن جهودها في تنظيم شؤون الإمامة وتيسير معرفة جداول الصلوات للمصلين والقاصدين.
أولًا: أئمة المسجد الحرام:
* صلاة الفجر: فضيلة الشيخ أ.د. ياسر الدوسري
* صلاة الظهر: فضيلة الشيخ بدر التركي
* صلاة العصر: فضيلة الشيخ أ.د. ياسر الدوسري
* صلاة المغرب: فضيلة الشيخ أ.د. فيصل غزاوي
* صلاة العشاء: فضيلة الشيخ بدر التركي

ثانيًا: أئمة المسجد النبوي:
* صلاة الفجر: فضيلة الشيخ أ.د. محمد برهجي
* صلاة الظهر: فضيلة الشيخ د. عبدالله البعيجان
* صلاة العصر: فضيلة الشيخ د. علي الحذيفي
* صلاة المغرب: فضيلة الشيخ د. حسين آل الشيخ
* صلاة العشاء: فضيلة الشيخ د. عبدالباري الثبيتي
ويأتي إعلان الجدول في إطار تنظيم شؤون الإمامة.''';

final _parser = HaramainScheduleParser();
final _fetchedAt = DateTime.utc(2026, 10, 11, 8);

HaramainWeek _parse(String text) {
  final week = _parser.parse(
    text,
    sourceUrl: 'https://www.al-madina.com/article/1007788/x',
    fetchedAt: _fetchedAt,
  );
  expect(week, isNotNull);
  return week!;
}

/// The announcement with the [occurrence]th line containing [contains]
/// removed, to build a block that is one prayer short.
String _withoutLine(String text, String contains, {int occurrence = 0}) {
  final lines = text.split('\n');
  var seen = 0;
  final out = <String>[];
  for (final line in lines) {
    if (line.contains(contains)) {
      if (seen == occurrence) {
        seen++;
        continue;
      }
      seen++;
    }
    out.add(line);
  }
  return out.join('\n');
}

HaramainWeek _sampleWeek({DateTime? endsOn}) {
  final w = _parse(_week1007788);
  return HaramainWeek(
    startHijri: w.startHijri,
    endHijri: w.endHijri,
    hijriYear: w.hijriYear,
    endsOn: endsOn ?? w.endsOn,
    fetchedAt: w.fetchedAt,
    sourceUrl: w.sourceUrl,
    haram: w.haram,
    nabawi: w.nabawi,
  );
}

void main() {
  group('parser on real announcements', () {
    test('week of 23-29 Rabi II 1448', () {
      final week = _parse(_week1007788);
      expect(week.startHijri, '23 ربيع الآخر');
      expect(week.endHijri, '29 ربيع الآخر');
      expect(week.hijriYear, 1448);
      expect(week.endsOn, DateTime.utc(2026, 10, 10));
      expect(week.endsOn.weekday, DateTime.saturday);
      expect(week.haram[HaramainPrayer.fajr]!.displayName, 'الوليد الشمسان');
      expect(week.haram[HaramainPrayer.maghrib]!.displayName, 'ماهر المعيقلي');
      expect(
        week.nabawi[HaramainPrayer.dhuhr]!.displayName,
        'عبدالباري الثبيتي',
      );
      expect(week.sourceUrl, contains('1007788'));
    });

    test('typos: a lost space and a missing hamza still find the roster', () {
      final week = _parse(_week1007788);
      final isha = week.haram[HaramainPrayer.isha]!;
      expect(isha.rosterId, 'haram_sudais');
      expect(isha.displayName, 'عبدالرحمن السديس');
      final dhuhr = week.haram[HaramainPrayer.dhuhr]!;
      expect(dhuhr.rosterId, 'haram_khayyat');
      expect(dhuhr.displayName, 'أسامة خياط');
    });

    test('a shortened name resolves to the right Hudhaify', () {
      // «أحمد الحذيفي» is Ahmad bin Ali; «علي الحذيفي» is a different man.
      final ahmad = _parse(_week1007788).nabawi[HaramainPrayer.maghrib]!;
      expect(ahmad.rosterId, 'nabawi_ahmad_hudhaify');
      expect(ahmad.displayName, 'أحمد بن علي الحذيفي');
      final ali = _parse(_week999369).nabawi[HaramainPrayer.asr]!;
      expect(ali.rosterId, 'nabawi_ali_hudhaify');
    });

    test('bullets, a stray line and a week crossing months', () {
      final week = _parse(_week1000401);
      expect(week.startHijri, '26 صفر');
      expect(week.endHijri, '2 ربيع الأول');
      expect(week.endsOn.weekday, DateTime.saturday);
      expect(week.haram[HaramainPrayer.fajr]!.displayName, 'بندر بليلة');
      final asr = week.nabawi[HaramainPrayer.asr]!;
      expect(asr.rosterId, 'nabawi_burhaji');
      expect(asr.displayName, 'محمد البرهجي');
      expect(week.nabawi[HaramainPrayer.isha]!.rosterId, 'nabawi_burhaji');
    });

    test('a swapped pair of letters and doubled titles', () {
      final week = _parse(_week999369);
      final maghrib = week.haram[HaramainPrayer.maghrib]!;
      expect(maghrib.rosterId, 'haram_ghazzawi');
      expect(week.haram[HaramainPrayer.dhuhr]!.displayName, 'الوليد الشمسان');
    });

    test('«آل الشيخ» keeps its last word', () {
      final maghrib = _parse(_week1005040).nabawi[HaramainPrayer.maghrib]!;
      expect(maghrib.rosterId, 'nabawi_aal_alsheikh');
      expect(maghrib.displayName, 'حسين آل الشيخ');
    });

    test('a Nabawi block without the word «صلاة» is read the same', () {
      // Derived from 1007788: the Nabawi lines lose «صلاة».
      final lines = _week1007788.split('\n');
      final from = lines.indexWhere((l) => l.startsWith('ثانيًا'));
      final bare = [
        for (var i = 0; i < lines.length; i++)
          i > from && i <= from + 5
              ? lines[i].replaceFirst('صلاة ', '')
              : lines[i],
      ].join('\n');
      final week = _parse(bare);
      expect(week.nabawi.length, 5);
      expect(week.nabawi[HaramainPrayer.isha]!.displayName, 'عبدالله البعيجان');
    });

    test('the AMP body is cut out of the page and its tags removed', () {
      final html =
          '<html><div class="x">no</div><div class="abody">'
          '${_week1007788.replaceAll('\n', '<br>')}'
          '</div><section class="rel"></section></html>';
      final text = HaramainScheduleParser.extractBodyText(html);
      expect(text, isNotNull);
      expect(_parse(text!).hijriYear, 1448);
      expect(HaramainScheduleParser.extractBodyText('<html></html>'), isNull);
    });
  });

  group('validation', () {
    test('four lines in the Haram block gives nothing', () {
      expect(
        _parser.parse(
          _withoutLine(_week1007788, 'ماهر المعيقلي'),
          sourceUrl: 'u',
          fetchedAt: _fetchedAt,
        ),
        isNull,
      );
    });

    test('four lines in the Nabawi block gives nothing', () {
      expect(
        _parser.parse(
          _withoutLine(_week1007788, 'البعيجان'),
          sourceUrl: 'u',
          fetchedAt: _fetchedAt,
        ),
        isNull,
      );
    });

    test('a prayer listed twice gives nothing', () {
      final doubled = _week1007788.replaceFirst(
        'صلاة العصر: معالي الشيخ د. صالح بن حميد .',
        'صلاة الظهر: معالي الشيخ د. صالح بن حميد .',
      );
      expect(
        _parser.parse(doubled, sourceUrl: 'u', fetchedAt: _fetchedAt),
        isNull,
      );
    });

    test('no date range gives nothing', () {
      final undated = _week1007788.replaceFirst(
        RegExp('للمدة.*?1448هـ'),
        'هذا الأسبوع',
      );
      expect(
        _parser.parse(undated, sourceUrl: 'u', fetchedAt: _fetchedAt),
        isNull,
      );
    });

    test('unrelated text gives nothing', () {
      expect(
        _parser.parse('خبر آخر تمامًا', sourceUrl: 'u', fetchedAt: _fetchedAt),
        isNull,
      );
    });
  });

  group('roster matching', () {
    final matcher = HaramainNameMatcher();

    test('«عبدالرحمنالسديس» and «اسامة خياط»', () {
      expect(
        matcher.match('عبدالرحمنالسديس', HaramainMosque.haram)?.id,
        'haram_sudais',
      );
      expect(
        matcher.match('اسامة خياط', HaramainMosque.haram)?.id,
        'haram_khayyat',
      );
    });

    test('a name from the other mosque is not forced onto this one', () {
      expect(matcher.match('صالح المغامسي', HaramainMosque.haram), isNull);
      expect(
        matcher.match('صالح المغامسي', HaramainMosque.nabawi)?.id,
        'nabawi_maghamsi',
      );
    });

    test('an unknown imam keeps the source spelling', () {
      final entry = matcher.entryFor(
        ' فضيلة الشيخ د. فلان الفلاني .',
        HaramainMosque.haram,
      );
      expect(entry.rosterId, isNull);
      expect(entry.displayName, 'فلان الفلاني');
      expect(entry.rawName, 'فلان الفلاني');
    });

    test('edit distance counts a swap as one slip', () {
      expect(editDistance('غزواي', 'غزاوي'), 1);
      expect(editDistance('abc', 'abc'), 0);
      expect(editDistance('abc', 'abd'), 1);
    });

    test('roster ids are unique and every name matches itself', () {
      expect(
        {for (final i in haramainRoster) i.id}.length,
        haramainRoster.length,
      );
      for (final imam in haramainRoster) {
        expect(
          matcher.match(imam.nameAr, imam.mosque)?.id,
          imam.id,
          reason: imam.nameAr,
        );
      }
    });
  });

  group('discovery', () {
    // Shapes copied from the live sitemaps: the news sitemap carries a title,
    // the monthly one only the slug in the URL.
    const news = '''
<urlset>
  <url>
    <loc>https://www.al-madina.com/article/1008700/%D9%85%D8%AD%D9%84%D9%8A%D8%A7%D8%AA/x</loc>
    <news:news><news:title>إمام وخطيب المسجد الحرام يوصي الالتزام بالضوابط</news:title></news:news>
  </url>
  <url>
    <loc>https://www.al-madina.com/article/1008801/%D9%85%D8%AD%D9%84%D9%8A%D8%A7%D8%AA/y</loc>
    <news:news><news:title><![CDATA[إعلان الجدول الأسبوعي لأئمة الحرمين الشريفين]]></news:title></news:news>
  </url>
</urlset>''';

    test('the news sitemap is filtered by title', () {
      final post = HaramainDiscovery.newest(news);
      expect(post?.id, 1008801);
      expect(post?.ampUrl, 'https://www.al-madina.com/ampArticle/1008801');
    });

    test('the monthly sitemap is filtered by slug, newest id wins', () {
      // The live file percent-encodes the slug; a broken escape elsewhere in
      // the file must not stop the rest from being read.
      final encoded = Uri.encodeFull(
        'https://www.al-madina.com/article/1006838/محليات/'
        'إعلان-الجدول-الأسبوعي-لأئمة-الحرمين-الشريفين',
      );
      final monthly =
          '<urlset>'
          '<url><loc>$encoded</loc></url>'
          '<url><loc>https://www.al-madina.com/article/1000001/x/%E0%A4%A</loc></url>'
          '<url><loc>https://www.al-madina.com/article/1007788/محليات/'
          'إعلان-الجدول-الأسبوعي-لأئمة-الحرمين-الشريفين</loc></url>'
          '<url><loc>https://www.al-madina.com/article/1007900/محليات/خبر-آخر</loc></url>'
          '</urlset>';
      expect(HaramainDiscovery.newest(monthly)?.id, 1007788);
      expect(
        HaramainDiscovery.newest(
          '<urlset><url><loc>$encoded</loc></url></urlset>',
        )?.id,
        1006838,
      );
    });

    test('other headlines are not mistaken for it', () {
      expect(
        HaramainDiscovery.isWeeklyTitle('إمام وخطيب المسجد الحرام'),
        isFalse,
      );
      expect(
        HaramainDiscovery.isWeeklyTitle(
          'رئاسة الشؤون الدينية بالحرمين الشريفين تعلن الجدول الأسبوعي لأئمة الحرمين الشريفين',
        ),
        isTrue,
      );
      expect(HaramainDiscovery.newest('<urlset></urlset>'), isNull);
    });
  });

  group('refresh rules', () {
    // The week of the fixture ends on Saturday 10 Oct 2026.
    late final HaramainWeek week;
    setUpAll(() => week = _sampleWeek());
    bool should(DateTime now, Duration? checkedAgo, {HaramainWeek? cached}) {
      return HaramainRefreshPolicy.shouldFetch(
        cached: cached ?? week,
        lastCheckedAt: checkedAgo == null ? null : now.subtract(checkedAgo),
        now: now,
      );
    }

    test('nothing cached always fetches', () {
      expect(
        HaramainRefreshPolicy.shouldFetch(
          cached: null,
          lastCheckedAt: DateTime.utc(2026, 10, 7),
          now: DateTime.utc(2026, 10, 7),
        ),
        isTrue,
      );
    });

    test(
      'Saturday 22:00 Makkah: every 30 minutes while the week ends today',
      () {
        final now = DateTime.utc(2026, 10, 10, 19); // 22:00 in Makkah
        expect(makkahNow(now).weekday, DateTime.saturday);
        expect(should(now, const Duration(minutes: 40)), isTrue);
        expect(should(now, const Duration(minutes: 10)), isFalse);
      },
    );

    test('Saturday before 21:00 Makkah is still the quiet rule', () {
      final now = DateTime.utc(2026, 10, 10, 17); // 20:00 in Makkah
      expect(should(now, const Duration(hours: 1)), isFalse);
    });

    test('Saturday night with the next week already cached does not poll', () {
      final next = _sampleWeek(endsOn: DateTime.utc(2026, 10, 17));
      final now = DateTime.utc(2026, 10, 10, 19);
      expect(should(now, const Duration(minutes: 40), cached: next), isFalse);
    });

    test('Wednesday: at most every 6 hours', () {
      final now = DateTime.utc(2026, 10, 7, 9);
      expect(should(now, const Duration(hours: 1)), isFalse);
      expect(should(now, const Duration(hours: 5, minutes: 59)), isFalse);
      expect(should(now, const Duration(hours: 6)), isTrue);
      expect(should(now, null), isTrue);
    });

    test('an expired week fetches, but not twice within 30 minutes', () {
      final now = DateTime.utc(2026, 10, 11, 9);
      expect(week.hasEndedAt(now), isTrue);
      expect(should(now, const Duration(hours: 2)), isTrue);
      expect(should(now, const Duration(minutes: 10)), isFalse);
    });

    test('a week that was never reposted stops costing data after Sunday', () {
      // Some weeks never appear at all. Past Sunday, an expired week is
      // looked for at the quiet rate, not on every opening of the page.
      final tuesday = DateTime.utc(2026, 10, 13, 9);
      expect(week.hasEndedAt(tuesday), isTrue);
      expect(should(tuesday, const Duration(hours: 1)), isFalse);
      expect(should(tuesday, const Duration(hours: 6)), isTrue);
    });

    test('the week is over only once Makkah reaches Sunday', () {
      expect(week.hasEndedAt(DateTime.utc(2026, 10, 10, 20, 59)), isFalse);
      expect(week.hasEndedAt(DateTime.utc(2026, 10, 10, 21)), isTrue);
    });
  });

  group('cache', () {
    test('JSON round-trips a week', () {
      final week = _sampleWeek();
      final back = HaramainWeekCodec.decode(HaramainWeekCodec.encode(week));
      expect(back, isNotNull);
      expect(back!.startHijri, week.startHijri);
      expect(back.endHijri, week.endHijri);
      expect(back.hijriYear, week.hijriYear);
      expect(back.endsOn, week.endsOn);
      expect(back.fetchedAt, week.fetchedAt);
      expect(back.sourceUrl, week.sourceUrl);
      for (final prayer in HaramainPrayer.values) {
        expect(
          back.haram[prayer]!.displayName,
          week.haram[prayer]!.displayName,
        );
        expect(back.haram[prayer]!.rosterId, week.haram[prayer]!.rosterId);
        expect(back.nabawi[prayer]!.rawName, week.nabawi[prayer]!.rawName);
      }
    });

    test('damaged JSON reads as nothing cached', () {
      expect(HaramainWeekCodec.decode(null), isNull);
      expect(HaramainWeekCodec.decode('not json'), isNull);
      expect(HaramainWeekCodec.decode('{"v":1}'), isNull);
      final encoded = HaramainWeekCodec.encode(_sampleWeek());
      expect(
        HaramainWeekCodec.decode(encoded.replaceFirst('"isha"', '"other"')),
        isNull,
      );
    });
  });

  group('repository', () {
    const newsUrl = 'https://www.al-madina.com/sitemaps/newsSitemap.xml';
    const ampUrl = 'https://www.al-madina.com/ampArticle/1008801';
    final html =
        '<div class="abody">${_week1007788.replaceAll('\n', '<br>')}</div>';
    const news = '''
<urlset><url>
  <loc>https://www.al-madina.com/article/1008801/x/y</loc>
  <news:news><news:title>إعلان الجدول الأسبوعي لأئمة الحرمين الشريفين</news:title></news:news>
</url></urlset>''';

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('fetches, parses and stores the first week', () async {
      final asked = <String>[];
      final repository = HaramainScheduleRepository(
        clock: () => DateTime.utc(2026, 10, 10, 19, 30),
        fetchText: (url) async {
          asked.add(url);
          return url == newsUrl ? news : html;
        },
      );

      final result = await repository.refresh();
      expect(result.failed, isFalse);
      // Shahd Now is asked first; here it answers nothing usable, so the
      // search goes on to Al-Madina.
      expect(asked.first, startsWith('https://shahdnow.sa/wp-json/'));
      expect(asked.skip(1), [newsUrl, ampUrl]);
      expect(result.week!.sourceUrl, contains('1008801'));

      final cached = await repository.loadCached();
      expect(cached!.haram[HaramainPrayer.isha]!.rosterId, 'haram_sudais');
    });

    test('a failed fetch keeps the last good week', () async {
      final first = HaramainScheduleRepository(
        clock: () => DateTime.utc(2026, 10, 10, 19, 30),
        fetchText: (url) async => url == newsUrl ? news : html,
      );
      await first.refresh();

      final offline = HaramainScheduleRepository(
        clock: () => DateTime.utc(2026, 10, 11, 9),
        fetchText: (url) async => throw StateError('offline'),
      );
      final result = await offline.refresh();
      expect(result.failed, isTrue);
      expect(result.week, isNotNull);
      expect((await offline.loadCached())!.sourceUrl, contains('1008801'));
    });

    test('an unreadable page keeps the last good week', () async {
      final first = HaramainScheduleRepository(
        clock: () => DateTime.utc(2026, 10, 3, 19, 30),
        fetchText: (url) async => url == newsUrl ? news : html,
      );
      await first.refresh();

      final newer = news.replaceAll('1008801', '1009900');
      final broken = HaramainScheduleRepository(
        clock: () => DateTime.utc(2026, 10, 11, 9),
        fetchText: (url) async => url == newsUrl ? newer : '<html></html>',
      );
      final result = await broken.refresh();
      expect(result.failed, isTrue);
      expect(result.week!.sourceUrl, contains('1008801'));
    });

    test('does not ask again inside the refresh window', () async {
      var calls = 0;
      final clock = DateTime.utc(2026, 10, 7, 9);
      final repository = HaramainScheduleRepository(
        clock: () => clock,
        fetchText: (url) async {
          calls++;
          return url == newsUrl ? news : html;
        },
      );
      await repository.refresh();
      final afterFirst = calls;
      final second = await repository.refresh();
      expect(calls, afterFirst);
      expect(second.attempted, isFalse);
      expect(second.week, isNotNull);

      await repository.refresh(force: true);
      expect(calls, greaterThan(afterFirst));
    });
  });

  test('the source host is on the secure client allowlist', () {
    expect(SecureHttpClient.allowedHosts, contains('www.al-madina.com'));
  });
}
