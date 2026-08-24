import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/utils/app_logger.dart';

/// A named run of surahs to listen to.
///
/// The unit is the whole surah rather than the verse: a listening list is what
/// you put on in the car or before sleep, and nobody builds one of those out
/// of individual ayat. The memorisation loop already covers verse ranges.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.surahs,
    this.isDailyWird = false,
    this.lastPlayedOn,
  });

  final String id;
  final String name;

  /// Surah numbers, in the order they play.
  final List<int> surahs;

  /// Marks this as the list to get through each day.
  final bool isDailyWird;

  /// `2026-08-24` — the last day it was played to the end.
  final String? lastPlayedOn;

  bool get isEmpty => surahs.isEmpty;

  bool doneOn(DateTime date) => lastPlayedOn == PlaylistStore.dayKey(date);

  Playlist copyWith({
    String? name,
    List<int>? surahs,
    bool? isDailyWird,
    String? lastPlayedOn,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      surahs: surahs ?? this.surahs,
      isDailyWird: isDailyWird ?? this.isDailyWird,
      lastPlayedOn: lastPlayedOn ?? this.lastPlayedOn,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'surahs': surahs,
    'daily': isDailyWird,
    'lastPlayedOn': lastPlayedOn,
  };

  static Playlist? fromMap(Map<dynamic, dynamic> map) {
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) {
      return null;
    }
    return Playlist(
      id: id,
      name:
          (map['name'] as String?)?.trim().isNotEmpty == true
              ? (map['name'] as String).trim()
              : id,
      surahs: [
        for (final value in (map['surahs'] as List? ?? const []))
          if (value is num && value >= 1 && value <= 114) value.toInt(),
      ],
      isDailyWird: map['daily'] == true,
      lastPlayedOn: map['lastPlayedOn'] as String?,
    );
  }
}

/// Where the listening lists live.
class PlaylistStore {
  static const String boxName = 'audio_playlists';

  /// Ids are minted from the clock, so two lists made in the same session
  /// never collide and the order they were created in is recoverable.
  static String mintId(DateTime now) =>
      'pl_${now.millisecondsSinceEpoch.toRadixString(36)}';

  static String dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<Box<Map>> _open() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<Map>(boxName);
    }
    return Hive.openBox<Map>(boxName);
  }

  Future<List<Playlist>> all() async {
    try {
      final box = await _open();
      final lists = <Playlist>[];
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw == null) {
          continue;
        }
        final playlist = Playlist.fromMap(raw);
        if (playlist != null) {
          lists.add(playlist);
        }
      }
      // The daily wird first, then by id, which is creation order.
      lists.sort((a, b) {
        if (a.isDailyWird != b.isDailyWird) {
          return a.isDailyWird ? -1 : 1;
        }
        return a.id.compareTo(b.id);
      });
      return lists;
    } catch (e, stack) {
      AppLogger.error('Could not read the playlists', e, stack);
      return const [];
    }
  }

  Future<Playlist?> find(String id) async {
    final box = await _open();
    final raw = box.get(id);
    return raw == null ? null : Playlist.fromMap(raw);
  }

  Future<void> save(Playlist playlist) async {
    final box = await _open();
    // Only one list can be the daily wird; setting a second would leave two
    // cards on the home screen both claiming to be today's.
    if (playlist.isDailyWird) {
      for (final other in await all()) {
        if (other.id != playlist.id && other.isDailyWird) {
          await box.put(other.id, other.copyWith(isDailyWird: false).toMap());
        }
      }
    }
    await box.put(playlist.id, playlist.toMap());
  }

  Future<void> delete(String id) async {
    final box = await _open();
    await box.delete(id);
  }

  /// Record that the list was played through today.
  Future<void> markPlayed(String id, {DateTime? when}) async {
    final playlist = await find(id);
    if (playlist == null) {
      return;
    }
    await save(playlist.copyWith(lastPlayedOn: dayKey(when ?? DateTime.now())));
  }

  Future<Playlist?> dailyWird() async {
    for (final playlist in await all()) {
      if (playlist.isDailyWird) {
        return playlist;
      }
    }
    return null;
  }
}
