import 'dart:convert';

import '../domain/haramain_week.dart';

/// JSON for the cached week.
///
/// Reading is defensive: anything that is not a complete week (older format,
/// truncated write, hand-edited) decodes to null, and the caller treats that
/// as "nothing cached" rather than showing part of a table.
class HaramainWeekCodec {
  const HaramainWeekCodec._();

  static const int version = 1;

  static String encode(HaramainWeek week) {
    Map<String, Object?> block(Map<HaramainPrayer, ImamEntry> entries) => {
      for (final e in entries.entries)
        e.key.name: {
          'raw': e.value.rawName,
          'name': e.value.displayName,
          'id': e.value.rosterId,
        },
    };

    return jsonEncode({
      'v': version,
      'startHijri': week.startHijri,
      'endHijri': week.endHijri,
      'hijriYear': week.hijriYear,
      'endsOn': _dateOnly(week.endsOn),
      'fetchedAt': week.fetchedAt.toUtc().toIso8601String(),
      'sourceUrl': week.sourceUrl,
      'haram': block(week.haram),
      'nabawi': block(week.nabawi),
    });
  }

  static HaramainWeek? decode(String? source) {
    if (source == null || source.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(source);
      if (json is! Map<String, dynamic> || json['v'] != version) {
        return null;
      }
      final haram = _block(json['haram']);
      final nabawi = _block(json['nabawi']);
      final endsOn = DateTime.tryParse('${json['endsOn']}');
      final fetchedAt = DateTime.tryParse('${json['fetchedAt']}');
      final year = json['hijriYear'];
      if (haram == null ||
          nabawi == null ||
          endsOn == null ||
          fetchedAt == null ||
          year is! int ||
          json['startHijri'] is! String ||
          json['endHijri'] is! String ||
          json['sourceUrl'] is! String) {
        return null;
      }
      return HaramainWeek(
        startHijri: json['startHijri'] as String,
        endHijri: json['endHijri'] as String,
        hijriYear: year,
        endsOn: DateTime.utc(endsOn.year, endsOn.month, endsOn.day),
        fetchedAt: fetchedAt.toUtc(),
        sourceUrl: json['sourceUrl'] as String,
        haram: haram,
        nabawi: nabawi,
      );
    } on FormatException {
      return null;
    }
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Map<HaramainPrayer, ImamEntry>? _block(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final out = <HaramainPrayer, ImamEntry>{};
    for (final prayer in HaramainPrayer.values) {
      final entry = raw[prayer.name];
      if (entry is! Map<String, dynamic>) {
        return null;
      }
      final name = entry['name'];
      final rawName = entry['raw'];
      final id = entry['id'];
      if (name is! String || name.isEmpty || rawName is! String) {
        return null;
      }
      out[prayer] = ImamEntry(
        rawName: rawName,
        displayName: name,
        rosterId: id is String ? id : null,
      );
    }
    return out;
  }
}
