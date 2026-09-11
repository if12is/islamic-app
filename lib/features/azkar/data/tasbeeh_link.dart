import 'package:shared_preferences/shared_preferences.dart';

import '../../quran/data/services/quran_local_service.dart';
import 'azkar_progress_store.dart';
import 'models/azkar_models.dart';
import 'tasbeeh_store.dart';

/// The smart misbaha and the wird's tasbeeh list, counting as one.
///
/// They were two stores that never spoke. Thirty-three of سبحان الله on the
/// beads left the wird's سبحان الله at nothing, and finishing all seven lines
/// of the wird's tasbeeh left its summary at "0/6" — because that summary
/// was reading the beads, which had not been touched, and counting six
/// phrases where the list it opens has seven.
///
/// Now a phrase said in one place is said in the other, whenever the two say
/// the same words. Matching is on the words themselves, with the vowel marks
/// and letter variants folded away, so "سُبْحَانَ اللَّهِ" in the wird and
/// "سبحان الله" on the beads are the same dhikr — and "أستغفر الله وأتوب
/// إليه" is not the same as "استغفر الله", because it is not.
///
/// Resets are not mirrored. Starting a fresh round on the beads after Asr
/// must not undo the wird someone finished after Fajr.
class TasbeehLink {
  TasbeehLink._();

  /// The chapter the wird's tasbeeh line opens.
  static const String wirdCategoryId = 'tasbeeh';

  /// The misbaha's phrases, in its order, in Arabic whatever the interface
  /// language — the words are what is matched, not their translation.
  static const List<String> misbahaPhrases = [
    'سبحان الله',
    'الحمد لله',
    'لا إله إلا الله',
    'الله أكبر',
    'استغفر الله',
    'لا حول ولا قوة إلا بالله',
  ];

  static String _normalize(String text) =>
      QuranLocalService.normalizeArabic(text);

  /// The wird dhikr that says what misbaha phrase [phraseIndex] says.
  static ZekrItem? zekrForPhrase(int phraseIndex, AzkarCategory? category) {
    if (category == null ||
        phraseIndex < 0 ||
        phraseIndex >= misbahaPhrases.length) {
      return null;
    }
    final phrase = _normalize(misbahaPhrases[phraseIndex]);
    for (final zekr in category.azkar) {
      if (_normalize(zekr.textAr) == phrase) {
        return zekr;
      }
    }
    return null;
  }

  /// The misbaha phrase that says what [zekr] says, if there is one.
  static int? phraseForZekr(ZekrItem zekr) {
    final text = _normalize(zekr.textAr);
    for (var index = 0; index < misbahaPhrases.length; index++) {
      if (_normalize(misbahaPhrases[index]) == text) {
        return index;
      }
    }
    return null;
  }

  /// A bead was counted: count it in the wird too, up to the wird's target.
  static Future<void> onMisbahaCount(
    SharedPreferences prefs,
    int phraseIndex,
    AzkarCategory? wirdTasbeeh, {
    DateTime? now,
  }) async {
    final zekr = zekrForPhrase(phraseIndex, wirdTasbeeh);
    if (zekr == null || wirdTasbeeh == null) {
      return;
    }
    await AzkarProgressStore.addOne(
      prefs,
      wirdTasbeeh.id,
      zekr.id,
      cap: zekr.targetCount,
      now: now,
    );
  }

  /// A line of the wird's tasbeeh was counted: move the beads with it.
  static Future<void> onWirdCount(
    SharedPreferences prefs,
    String categoryId,
    ZekrItem zekr, {
    DateTime? now,
  }) async {
    if (categoryId != wirdCategoryId) {
      return;
    }
    final phrase = phraseForZekr(zekr);
    if (phrase == null) {
      return;
    }
    await TasbeehStore.incrementRound(prefs, phrase, now: now);
  }
}
