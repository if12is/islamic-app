import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/azkar/data/tasbeeh_store.dart';
import '../constants/app_constants.dart';
import '../utils/app_logger.dart';

/// What a restore actually changed.
class RestoreSummary {
  const RestoreSummary({
    required this.bookmarks,
    required this.notes,
    required this.readingDays,
    required this.hifzItems,
    required this.settingsRestored,
    this.tasbeehTotal = 0,
  });

  final int bookmarks;
  final int notes;
  final int readingDays;
  final int hifzItems;
  final bool settingsRestored;

  /// The lifetime tasbeeh count that came across, so the user can see with
  /// their own eyes that the number they have been building survived.
  final int tasbeehTotal;

  static const RestoreSummary empty = RestoreSummary(
    bookmarks: 0,
    notes: 0,
    readingDays: 0,
    hifzItems: 0,
    settingsRestored: false,
  );
}

/// Export and restore everything the user has built up.
///
/// The backup is plain JSON the user owns: bookmarks and notes, the reading
/// log, the memorisation schedule, and every setting. No account, no server —
/// a file they can keep anywhere.
class BackupService {
  BackupService._();

  /// 2 adds the tasbeeh counts, the azkar sessions, and the daily wird
  /// targets. Version 1 files still restore; see [_migrateTasbeeh].
  static const int formatVersion = 2;

  /// Hive boxes carried in the backup.
  static const List<String> _boxes = [
    'quran_bookmarks',
    'reading_progress',
    'hifz_items',
  ];

  /// Whole families of keys, carried by prefix.
  ///
  /// The tasbeeh counters are per phrase, so listing them by name means a
  /// seventh phrase would silently stop being backed up. They were left out
  /// entirely before this: a lifetime count someone had spent years building
  /// was the one thing in the app that could not be exported.
  static const List<String> _preferencePrefixes = [
    'tasbeeh_',
    'azkar_',
    'seasonal_intro_',
    'salawat_',
    'prayer_log_',
    'zakat_',
  ];

  /// Preference keys carried in the backup.
  static const List<String> _preferenceKeys = [
    AppConstants.dailyWirdTargetsKey,
    AppConstants.lastAzkarCategoryIdKey,
    AppConstants.themeModeKey,
    AppConstants.localeKey,
    AppConstants.prayerMethodKey,
    AppConstants.prayerCalculationSettingsKey,
    AppConstants.notificationPreferencesKey,
    AppConstants.notificationsEnabledKey,
    AppConstants.readerSettingsKey,
    AppConstants.tafsirEditionKey,
    AppConstants.verseReciterKey,
    AppConstants.khatmahPlanKey,
    AppConstants.userNameKey,
    AppConstants.userCityKey,
    AppConstants.userLatitudeKey,
    AppConstants.userLongitudeKey,
    'last_read_surah_id',
    'last_read_verse_num',
    'last_read_scroll_offset',
    'last_read_surah_nameAr',
    'location_is_manual',
    'recitation_locale_id',
    'stt_selected_model',
  ];

  /// Whether a key belongs in the backup.
  static bool _isCarried(String key) =>
      _preferenceKeys.contains(key) || _preferencePrefixes.any(key.startsWith);

  /// Build the backup payload.
  static Future<Map<String, dynamic>> buildPayload() async {
    final prefs = await SharedPreferences.getInstance();

    // Walk what is actually stored rather than a fixed list, so every phrase
    // counter and every azkar session comes along without being named.
    final settings = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (!_isCarried(key)) {
        continue;
      }
      final value = prefs.get(key);
      if (value != null) {
        settings[key] = value;
      }
    }

    final boxes = <String, dynamic>{};
    for (final name in _boxes) {
      final box = await _openBox(name);
      boxes[name] = {
        for (final key in box.keys)
          key.toString(): jsonDecode(jsonEncode(box.get(key))),
      };
    }

    return {
      'version': formatVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'settings': settings,
      'boxes': boxes,
    };
  }

  /// Write the backup to a file and hand it to the share sheet.
  static Future<void> exportBackup() async {
    final payload = await buildPayload();
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
    );

    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final name = 'islamic_app_backup_$stamp.json';

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'application/json', name: name),
        ],
        fileNameOverrides: [name],
      ),
    );
  }

  /// Let the user pick a backup file and restore it.
  ///
  /// Returns null when the picker is dismissed; throws [BackupException] when
  /// the file is not a backup this app wrote.
  static Future<RestoreSummary?> importBackup() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (file == null) {
      return null;
    }

    return restoreFromBytes(await file.readAsBytes());
  }

  /// Apply a backup payload. Existing entries with the same key are replaced.
  static Future<RestoreSummary> restoreFromBytes(Uint8List bytes) async {
    late final Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const BackupException('not_a_backup');
      }
      payload = decoded;
    } catch (e) {
      AppLogger.warning('Backup parse failed: $e');
      throw const BackupException('not_a_backup');
    }

    if (payload['version'] is! int || payload['boxes'] is! Map) {
      throw const BackupException('not_a_backup');
    }
    if ((payload['version'] as int) > formatVersion) {
      throw const BackupException('newer_version');
    }

    final prefs = await SharedPreferences.getInstance();
    var settingsRestored = false;

    final settings = payload['settings'];
    if (settings is Map) {
      for (final entry in settings.entries) {
        final key = entry.key.toString();
        if (!_isCarried(key)) {
          continue;
        }
        final value = entry.value;
        if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is List) {
          await prefs.setStringList(key, value.map((e) => '$e').toList());
        } else {
          continue;
        }
        settingsRestored = true;
      }
    }

    final counts = <String, int>{};
    var notes = 0;

    final boxes = payload['boxes'] as Map;
    for (final name in _boxes) {
      final data = boxes[name];
      if (data is! Map) {
        continue;
      }

      final box = await _openBox(name);
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is! Map) {
          continue;
        }
        await box.put(entry.key.toString(), Map<String, dynamic>.from(value));
        if (name == 'quran_bookmarks' &&
            (value['note'] as String? ?? '').isNotEmpty) {
          notes++;
        }
      }
      counts[name] = data.length;
    }

    await _migrateTasbeeh(prefs);

    return RestoreSummary(
      bookmarks: counts['quran_bookmarks'] ?? 0,
      notes: notes,
      readingDays: counts['reading_progress'] ?? 0,
      hifzItems: counts['hifz_items'] ?? 0,
      settingsRestored: settingsRestored,
      tasbeehTotal: TasbeehStore.total(prefs),
    );
  }

  /// Give a pre-split backup's tasbeeh total somewhere to live.
  ///
  /// Counts used to be one running number for every phrase; they are now kept
  /// per phrase, with the sum shown underneath. A backup written before that
  /// carries the sum and nothing else, so the beads would read zero while the
  /// total underneath read four thousand — which looks exactly like loss.
  ///
  /// The only thing an old file says about which phrase the count belongs to
  /// is the phrase that was open when it was written, so the whole total goes
  /// there. It is an assumption, and it keeps the number the user earned.
  static Future<void> _migrateTasbeeh(SharedPreferences prefs) async {
    final total = TasbeehStore.total(prefs);
    if (total <= 0) {
      return;
    }

    final alreadySplit = List.generate(
      TasbeehStore.phraseCount,
      (index) => TasbeehStore.totalFor(prefs, index),
    ).any((value) => value > 0);
    if (alreadySplit) {
      return;
    }

    final phrase = TasbeehStore.phraseIndex(prefs);
    await TasbeehStore.seedPhraseTotal(prefs, phrase, total);
    AppLogger.info('Migrated $total tasbeeh onto phrase $phrase');
  }

  static Future<Box<Map>> _openBox(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<Map>(name);
    }
    return Hive.openBox<Map>(name);
  }
}

/// Raised when a file is not a backup this app can read.
class BackupException implements Exception {
  const BackupException(this.code);

  final String code;

  bool get isWrongVersion => code == 'newer_version';

  @override
  String toString() => 'BackupException($code)';
}
