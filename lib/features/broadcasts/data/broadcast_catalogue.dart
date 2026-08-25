import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/secure_http_client.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/broadcast.dart';

/// The live stations and channels, fetched once and then kept.
///
/// Like the reciter list, this is fetched and cached rather than bundled: the
/// stations change, and a list frozen into the build goes stale in a way
/// nobody can fix without a new release. Unlike the reciter list, it is small
/// enough that the whole thing fits in a preference.
class BroadcastCatalogue {
  BroadcastCatalogue._();

  /// The `www` is required: the bare domain answers 301 and the client is
  /// configured not to follow redirects.
  static const String radiosEndpoint =
      'https://www.mp3quran.net/api/v3/radios?language=ar';
  static const String tvEndpoint =
      'https://www.mp3quran.net/api/v3/live-tv?language=ar';

  // Bumped when a pinned address changes, so a phone that already cached the
  // dead ones does not keep serving them for another week.
  static const String cacheKey = 'broadcast_catalogue_v2';
  static const String cachedAtKey = 'broadcast_catalogue_fetched_at';

  /// Stations do not move often; a weekly re-check is generous.
  static const Duration refreshAfter = Duration(days: 7);

  /// The host the catalogue publishes, and the one that actually answers.
  ///
  /// Measured, not assumed: over a sample of ten stations the primary host
  /// answered ten times and the backup eight. Both are kept — the primary is
  /// tried first and the published address is the fallback.
  static const String publishedHost = 'backup.qurango.net';
  static const String primaryHost = 'qurango.net';

  /// Channels whose published address does not answer.
  ///
  /// mp3quran's `live-tv` endpoint hands out `win.holol.com/live/quran` and
  /// `.../sunnah`, and both have been 404 on every path variant for as long as
  /// this has been checked — the host is up, the streams are gone. So the two
  /// channels are pinned to addresses that were verified end to end: master
  /// playlist, variant playlist, and an actual video segment downloaded. The
  /// address the API publishes is kept behind them, in case it comes back.
  static const List<String> deadTvHosts = ['win.holol.com'];

  /// Stations and channels the API either omits or gets wrong.
  static const List<Broadcast> pinned = [
    Broadcast(
      // Cairo's Quran radio — broadcasting since 1964, and what most people in
      // Egypt mean by "إذاعة القرآن الكريم" — is not in mp3quran's list at all.
      //
      // The address is deliberately http. Radiojar answers the https address
      // with a redirect to a plain-http node, and a player will not follow a
      // redirect that drops from https to http — which is why this station,
      // alone among the radios, would not start. Going to http directly makes
      // the redirect same-protocol and it plays. Nothing is lost by it: the
      // audio arrives in the clear either way, and it carries no credential.
      id: 'cairo-quran',
      name: 'إذاعة القرآن الكريم من القاهرة',
      url: 'http://stream.radiojar.com/8s5u5tpdtwzuv',
      fallbackUrl: 'https://stream.radiojar.com/8s5u5tpdtwzuv',
      kind: BroadcastKind.radio,
      pinned: true,
      noteAr: 'البث المباشر · ٩٨٫٢ FM',
    ),
    Broadcast(
      id: 'tv:3',
      name: 'قناة القرآن الكريم',
      url:
          'https://cdn-globecast.akamaized.net/live/eds/saudi_quran/'
          'hls_roku/index.m3u8',
      fallbackUrl: 'https://win.holol.com/live/quran/playlist.m3u8',
      kind: BroadcastKind.tv,
      pinned: true,
      noteAr: 'الحرم المكي · بث مباشر',
    ),
    Broadcast(
      id: 'tv:4',
      name: 'قناة السنة النبوية',
      url:
          'https://cdn-globecast.akamaized.net/live/eds/saudi_sunnah/'
          'hls_roku/index.m3u8',
      fallbackUrl: 'https://win.holol.com/live/sunnah/playlist.m3u8',
      kind: BroadcastKind.tv,
      pinned: true,
      noteAr: 'المسجد النبوي · بث مباشر',
    ),
  ];

  static List<Broadcast>? _memory;

  /// Everything, pinned stations first. Never returns empty-handed: with no
  /// network and no cache it still has the pinned list.
  static Future<List<Broadcast>> load({bool refresh = false}) async {
    if (_memory != null && !refresh) {
      return _memory!;
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = _readCache(prefs);

    if (cached.isNotEmpty && !refresh && !_isStale(prefs)) {
      return _memory = cached;
    }

    final fetched = await _fetchAll();
    if (fetched.isNotEmpty) {
      final all = merge(pinned, fetched);
      await _writeCache(prefs, all);
      return _memory = all;
    }

    return _memory = cached.isNotEmpty ? cached : pinned;
  }

  /// Pinned entries win over the API's own.
  ///
  /// The two television channels are pinned *and* published, under the same
  /// ids. Without this they would appear twice — once playing and once not,
  /// which is a worse way to be broken than simply not working.
  static List<Broadcast> merge(
    List<Broadcast> pinnedItems,
    List<Broadcast> fetched,
  ) {
    final ids = {for (final item in pinnedItems) item.id};
    return [
      ...pinnedItems,
      for (final item in fetched)
        if (!ids.contains(item.id)) item,
    ];
  }

  static List<Broadcast> of(List<Broadcast> all, BroadcastKind kind) => [
    for (final item in all)
      if (item.kind == kind) item,
  ];

  /// Name search that ignores the word every station starts with.
  static List<Broadcast> search(List<Broadcast> all, String query) {
    final needle = normalize(query);
    if (needle.isEmpty) {
      return all;
    }
    return [
      for (final item in all)
        if (normalize(item.name).contains(needle)) item,
    ];
  }

  /// Strip diacritics and normalise the alif and ya, so "اذاعة القران" finds
  /// "إذاعة القرآن".
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.trim().toLowerCase().runes) {
      if (rune >= 0x064B && rune <= 0x0652) {
        continue;
      }
      buffer.writeCharCode(switch (rune) {
        0x0623 || 0x0625 || 0x0622 || 0x0671 => 0x0627,
        0x0649 => 0x064A,
        0x0629 => 0x0647,
        _ => rune,
      });
    }
    return buffer.toString();
  }

  static Future<List<Broadcast>> _fetchAll() async {
    final radios = await _fetch(radiosEndpoint, 'radios', BroadcastKind.radio);
    final tv = await _fetch(tvEndpoint, 'livetv', BroadcastKind.tv);
    return [...tv, ...radios];
  }

  static Future<List<Broadcast>> _fetch(
    String endpoint,
    String key,
    BroadcastKind kind,
  ) async {
    try {
      final response = await SecureHttpClient.create().get<dynamic>(endpoint);
      final body = response.data;
      final json =
          body is String
              ? jsonDecode(body) as Map<String, dynamic>
              : Map<String, dynamic>.from(body as Map);
      return parse(json, key, kind);
    } catch (e) {
      AppLogger.warning('Could not fetch $key: $e');
      return const [];
    }
  }

  /// Read one endpoint's payload. Separate so it can be tested with no network.
  static List<Broadcast> parse(
    Map<String, dynamic> json,
    String key,
    BroadcastKind kind,
  ) {
    final list = json[key];
    if (list is! List) {
      return const [];
    }

    final items = <Broadcast>[];
    final seen = <String>{};

    for (final raw in list) {
      if (raw is! Map) {
        continue;
      }
      final entry = Map<String, dynamic>.from(raw);
      final url = (entry['url'] as String? ?? '').trim();
      final name = (entry['name'] as String? ?? '').trim();
      final id = entry['id']?.toString();

      if (name.isEmpty || id == null || !url.startsWith('https://')) {
        // A station served over plain http would be blocked outright, and
        // listing one that cannot play is worse than leaving it out.
        continue;
      }
      if (!seen.add('${kind.name}:$id')) {
        continue;
      }

      final preferred = url.replaceFirst(publishedHost, primaryHost);
      items.add(
        Broadcast(
          id: '${kind.name}:$id',
          name: name,
          url: preferred,
          fallbackUrl: preferred == url ? null : url,
          kind: kind,
        ),
      );
    }

    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  static bool _isStale(SharedPreferences prefs) {
    final at = prefs.getInt(cachedAtKey);
    if (at == null) {
      return true;
    }
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at)) >=
        refreshAfter;
  }

  static List<Broadcast> _readCache(SharedPreferences prefs) {
    final raw = prefs.getString(cacheKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final entry in list)
          if (entry is Map<String, dynamic>)
            if (Broadcast.fromJson(entry) case final item?) item,
      ];
    } catch (e) {
      AppLogger.warning('Broadcast cache unreadable: $e');
      return const [];
    }
  }

  static Future<void> _writeCache(
    SharedPreferences prefs,
    List<Broadcast> items,
  ) async {
    await prefs.setString(
      cacheKey,
      jsonEncode([for (final item in items) item.toJson()]),
    );
    await prefs.setInt(cachedAtKey, DateTime.now().millisecondsSinceEpoch);
  }
}
