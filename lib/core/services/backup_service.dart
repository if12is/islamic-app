import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });

  final int bookmarks;
  final int notes;
  final int readingDays;
  final int hifzItems;
  final bool settingsRestored;

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

  static const int formatVersion = 1;

  /// Hive boxes carried in the backup.
  static const List<String> _boxes = [
    'quran_bookmarks',
    'reading_progress',
    'hifz_items',
  ];

  /// Preference keys carried in the backup.
  static const List<String> _preferenceKeys = [
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
  ];

  /// Build the backup payload.
  static Future<Map<String, dynamic>> buildPayload() async {
    final prefs = await SharedPreferences.getInstance();

    final settings = <String, dynamic>{};
    for (final key in _preferenceKeys) {
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
        if (!_preferenceKeys.contains(key)) {
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

    return RestoreSummary(
      bookmarks: counts['quran_bookmarks'] ?? 0,
      notes: notes,
      readingDays: counts['reading_progress'] ?? 0,
      hifzItems: counts['hifz_items'] ?? 0,
      settingsRestored: settingsRestored,
    );
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
