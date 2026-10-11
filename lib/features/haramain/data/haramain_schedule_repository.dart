import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/secure_http_client.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/haramain_week.dart';
import 'haramain_discovery.dart';
import 'haramain_refresh_policy.dart';
import 'haramain_schedule_parser.dart';
import 'haramain_week_codec.dart';

/// What a refresh did.
class HaramainRefreshResult {
  const HaramainRefreshResult({
    required this.week,
    this.attempted = false,
    this.failed = false,
  });

  /// The best week we have: the new one, or the last good one.
  final HaramainWeek? week;

  /// False when the refresh rules said it was too soon to ask.
  final bool attempted;

  /// True when the source could not be reached or read, or when there is
  /// still nothing to show.
  final bool failed;
}

/// Finds, reads and remembers the weekly imams announcement.
///
/// The last good week always survives: a failed fetch, an unreadable page or
/// a redesign of the source leaves the stored week untouched.
class HaramainScheduleRepository {
  HaramainScheduleRepository({
    Future<String> Function(String url)? fetchText,
    DateTime Function()? clock,
    HaramainScheduleParser? parser,
  }) : _fetchText = fetchText ?? _fetchOverHttp,
       _clock = clock ?? DateTime.now,
       _parser = parser ?? HaramainScheduleParser();

  static const String weekKey = 'haramain_week_v1';
  static const String checkedKey = 'haramain_checked_v1';

  static const String _newsSitemap =
      'https://www.al-madina.com/sitemaps/newsSitemap.xml';

  /// Shahd Now's WordPress REST search for the weekly post, newest first.
  /// Only the fields that are read are asked for, which keeps the answer to a
  /// few kilobytes. A search is ordered by relevance unless told otherwise,
  /// which could push this week's post past the first three.
  static final String _shahdUrl =
      Uri.https('shahdnow.sa', '/wp-json/wp/v2/posts', {
        'search': 'الجدول الأسبوعي لأئمة الحرمين',
        'orderby': 'date',
        'per_page': '3',
        '_fields': 'id,date_gmt,link,title,content',
      }).toString();

  final Future<String> Function(String url) _fetchText;
  final DateTime Function() _clock;
  final HaramainScheduleParser _parser;

  /// The stored week, or null. Never touches the network.
  Future<HaramainWeek?> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    return HaramainWeekCodec.decode(prefs.getString(weekKey));
  }

  /// Asks the source for a newer week when the refresh rules allow it.
  /// [force] is for the retry button: a person pressed it, so the rules'
  /// spacing does not apply.
  Future<HaramainRefreshResult> refresh({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = HaramainWeekCodec.decode(prefs.getString(weekKey));
    final now = _clock();
    final checkedMs = prefs.getInt(checkedKey);
    final lastChecked =
        checkedMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(checkedMs, isUtc: true);

    if (!force &&
        !HaramainRefreshPolicy.shouldFetch(
          cached: cached,
          lastCheckedAt: lastChecked,
          now: now,
        )) {
      return HaramainRefreshResult(week: cached, failed: cached == null);
    }

    // Recorded before the request, so a hang or a crash does not make the
    // next page opening try again straight away.
    await prefs.setInt(checkedKey, now.toUtc().millisecondsSinceEpoch);

    // Two independent sources, Shahd Now first: it posts every week, while
    // Al-Madina skips some. Each is wrapped on its own so one being down (or
    // redesigned) never stops the other. Al-Madina is only asked when Shahd
    // Now brought nothing, nothing newer than what is stored, or a week that
    // is itself already over (so a fresher one may exist elsewhere).
    var errored = false;
    HaramainWeek? found;
    try {
      found = await _fromShahd(now);
    } on Object catch (error) {
      errored = true;
      AppLogger.warning('Haramain: Shahd Now failed (${error.runtimeType})');
    }

    if (found == null || !_isNewer(found, cached) || found.hasEndedAt(now)) {
      try {
        final fromMadina = await _fromMadina(now, cached);
        if (fromMadina != null &&
            (found == null || fromMadina.endsOn.isAfter(found.endsOn))) {
          found = fromMadina;
        }
      } on Object catch (error) {
        errored = true;
        AppLogger.warning('Haramain: Al-Madina failed (${error.runtimeType})');
      }
    }

    if (found != null && _isNewer(found, cached)) {
      await prefs.setString(weekKey, HaramainWeekCodec.encode(found));
      return HaramainRefreshResult(week: found, attempted: true);
    }

    if (cached == null || errored) {
      AppLogger.info('Haramain: no new week found');
      return HaramainRefreshResult(week: cached, attempted: true, failed: true);
    }
    // Nothing newer, and every source answered: the cached week is confirmed
    // as current. A same-week repost is deliberately ignored; the stored one
    // was already read successfully.
    final confirmed = cached.copyWith(fetchedAt: now.toUtc());
    await prefs.setString(weekKey, HaramainWeekCodec.encode(confirmed));
    return HaramainRefreshResult(week: confirmed, attempted: true);
  }

  /// Post ids of two sites are not comparable, so "newer" is the week itself.
  static bool _isNewer(HaramainWeek candidate, HaramainWeek? cached) =>
      cached == null || candidate.startsOn.isAfter(cached.startsOn);

  /// The newest week among Shahd Now's search hits, or null when none of
  /// them parses as a weekly announcement. Throws when the site cannot be
  /// reached or answers something that is not the expected JSON.
  Future<HaramainWeek?> _fromShahd(DateTime now) async {
    final decoded = jsonDecode(await _fetchText(_shahdUrl));
    if (decoded is! List) {
      throw const FormatException('Shahd Now: expected a JSON array');
    }
    HaramainWeek? best;
    for (final post in decoded) {
      if (post is! Map) {
        continue;
      }
      final content = post['content'];
      final html = content is Map ? content['rendered'] : null;
      final link = post['link'];
      if (html is! String || link is! String) {
        continue;
      }
      final week = _parser.parse(
        HaramainScheduleParser.extractWordPressText(html),
        sourceUrl: link,
        fetchedAt: now.toUtc(),
      );
      if (week != null && (best == null || week.endsOn.isAfter(best.endsOn))) {
        best = week;
      }
    }
    return best;
  }

  /// The week of Al-Madina's newest weekly post, or null when there is no
  /// such post, or it is no newer than the stored one (compared by post id
  /// when the stored week came from Al-Madina too, which saves the download).
  Future<HaramainWeek?> _fromMadina(DateTime now, HaramainWeek? cached) async {
    final deep = cached == null || cached.hasEndedAt(now);
    final post = await _discover(now, deep: deep);
    if (post == null) {
      AppLogger.info('Haramain: no weekly post listed');
      return null;
    }
    final cachedId = _idOf(cached?.sourceUrl);
    if (cachedId != null && post.id <= cachedId) {
      return null;
    }

    final html = await _fetchText(post.ampUrl);
    final text = HaramainScheduleParser.extractBodyText(html);
    final week =
        text == null
            ? null
            : _parser.parse(
              text,
              sourceUrl: post.articleUrl,
              fetchedAt: now.toUtc(),
            );
    if (week == null) {
      // Unlike "nothing listed", this is a source that is broken.
      throw FormatException('Al-Madina post ${post.id} could not be parsed');
    }
    return week;
  }

  /// Newest weekly post: the two-day news sitemap first, then, only when the
  /// caller really needs a new week, this month's and last month's full
  /// sitemaps (a Saturday-night post stays in the current month's list, but a
  /// phone opened on the 1st needs the month before).
  Future<HaramainPost?> _discover(DateTime now, {required bool deep}) async {
    final fromNews = HaramainDiscovery.newest(await _fetchText(_newsSitemap));
    if (fromNews != null || !deep) {
      return fromNews;
    }
    final makkah = makkahNow(now);
    final previous = DateTime.utc(makkah.year, makkah.month - 1);
    for (final month in [makkah, previous]) {
      final url =
          'https://www.al-madina.com/sitemaps/${month.year}/${month.month}/'
          'sitemap_0.xml';
      final found = HaramainDiscovery.newest(await _fetchText(url));
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  static int? _idOf(String? url) {
    if (url == null) {
      return null;
    }
    final match = RegExp(r'/article/(\d+)').firstMatch(url);
    return match == null ? null : int.parse(match.group(1)!);
  }

  static Dio? _dio;

  static Future<String> _fetchOverHttp(String url) async {
    final dio = _dio ??= SecureHttpClient.create();
    // The client defaults to JSON; this host serves HTML and XML.
    final response = await dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {'Accept': 'text/html,application/xml,application/json'},
      ),
    );
    return response.data ?? '';
  }
}
