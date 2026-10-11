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

    try {
      final deep = cached == null || cached.hasEndedAt(now);
      final post = await _discover(now, deep: deep);
      if (post == null) {
        AppLogger.info('Haramain: no weekly post listed');
        return HaramainRefreshResult(
          week: cached,
          attempted: true,
          failed: cached == null,
        );
      }

      final cachedId = _idOf(cached?.sourceUrl);
      if (cached != null && cachedId != null && post.id <= cachedId) {
        // Nothing newer: the cached week is confirmed as current.
        final confirmed = cached.copyWith(fetchedAt: now.toUtc());
        await prefs.setString(weekKey, HaramainWeekCodec.encode(confirmed));
        return HaramainRefreshResult(week: confirmed, attempted: true);
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
        AppLogger.warning('Haramain: post ${post.id} could not be parsed');
        return HaramainRefreshResult(
          week: cached,
          attempted: true,
          failed: true,
        );
      }

      await prefs.setString(weekKey, HaramainWeekCodec.encode(week));
      return HaramainRefreshResult(week: week, attempted: true);
    } on Object catch (error) {
      AppLogger.warning('Haramain: refresh failed (${error.runtimeType})');
      return HaramainRefreshResult(week: cached, attempted: true, failed: true);
    }
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
        headers: const {'Accept': 'text/html,application/xml'},
      ),
    );
    return response.data ?? '';
  }
}
