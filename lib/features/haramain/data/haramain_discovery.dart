import 'haramain_name_matcher.dart';

/// A post found in a sitemap.
class HaramainPost {
  const HaramainPost({required this.id, required this.articleUrl});

  final int id;

  /// The reader-facing page, shown as the source link.
  final String articleUrl;

  /// The AMP rendering: server-rendered, small, and needs no JavaScript.
  /// Answers 200 directly; the bare domain would redirect, which the secure
  /// client does not follow, hence the fixed `www` host.
  String get ampUrl => 'https://www.al-madina.com/ampArticle/$id';
}

/// Finds the newest weekly-imams post in a sitemap.
///
/// The post's id is not predictable, and the site's RSS feed is not a feed at
/// all at /rss (it is an HTML page; the real one is /rss/feed and holds only
/// the last ~50 articles, a few hours' worth). The sitemaps are the reliable
/// index:
///  * newsSitemap.xml lists about two days of articles with their titles,
///    which covers Saturday night until Monday;
///  * the monthly sitemap lists every article of the month, with the title
///    only as the URL slug, and is about 1 MB — so it is the fallback for a
///    phone that was off all weekend, not the first thing asked.
class HaramainDiscovery {
  const HaramainDiscovery._();

  static final RegExp _urlBlock = RegExp(r'<url>(.*?)</url>', dotAll: true);
  static final RegExp _loc = RegExp(r'<loc>\s*([^<\s]+)\s*</loc>');
  static final RegExp _title = RegExp(
    r'<news:title>\s*(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?\s*</news:title>',
    dotAll: true,
  );
  static final RegExp _articleId = RegExp(r'/article/(\d+)(?:/|$)');

  /// Whether a headline or URL slug is the weekly announcement. The wording
  /// of the headline varies from week to week («إعلان الجدول…», «الشؤون
  /// الدينية تعلن الجدول…») but always names the imams and the table.
  static bool isWeeklyTitle(String text) {
    final flat = normalizeArabic(text);
    return flat.contains('ائمه الحرمين') &&
        (flat.contains('الجدول') || flat.contains('جدول'));
  }

  /// The highest-id matching post in [sitemapXml], or null.
  static HaramainPost? newest(String sitemapXml) {
    HaramainPost? best;
    for (final block in _urlBlock.allMatches(sitemapXml)) {
      final inner = block.group(1)!;
      final loc = _loc.firstMatch(inner)?.group(1);
      if (loc == null) {
        continue;
      }
      final id = _articleId.firstMatch(loc)?.group(1);
      if (id == null) {
        continue;
      }
      var decoded = loc;
      try {
        decoded = Uri.decodeFull(loc);
      } on ArgumentError {
        // Bad percent-encoding throws ArgumentError, not FormatException.
        // Keep the encoded form; the title check below may still match.
      }
      final title = _title.firstMatch(inner)?.group(1) ?? '';
      if (!isWeeklyTitle(title) && !isWeeklyTitle(decoded)) {
        continue;
      }
      final number = int.parse(id);
      if (best == null || number > best.id) {
        best = HaramainPost(id: number, articleUrl: loc);
      }
    }
    return best;
  }
}
