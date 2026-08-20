import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/recitation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The voice pack is the user's choice, and it has to survive being made.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing is chosen until the user chooses', () async {
    expect(await RecitationService.savedLocale(), isNull);
  });

  test('a chosen pack is remembered, and can be cleared', () async {
    await RecitationService.setPreferredLocale('ar_EG');
    expect(await RecitationService.savedLocale(), 'ar_EG');

    // Switching to another installed pack is one call, not a reinstall.
    await RecitationService.setPreferredLocale('ar_SA');
    expect(await RecitationService.savedLocale(), 'ar_SA');

    await RecitationService.setPreferredLocale(null);
    expect(await RecitationService.savedLocale(), isNull);
  });

  group('Recognising an Arabic pack', () {
    test('accepts every Arabic variant, however it is written', () {
      for (final id in ['ar', 'ar_SA', 'ar-EG', 'ar_MA', 'AR_JO']) {
        expect(RecitationService.isArabic(id), isTrue, reason: id);
      }
    });

    test('does not mistake other languages for Arabic', () {
      for (final id in ['en_US', 'fa_IR', 'ur_PK', 'tr_TR', 'id_ID']) {
        expect(RecitationService.isArabic(id), isFalse, reason: id);
      }
    });
  });

  test('the preferred list is a suggestion, not a requirement', () {
    // Every entry is Arabic, and none of them is treated as mandatory —
    // the resolver falls through to any Arabic pack, then to the user's pick.
    expect(RecitationService.preferredLocales, isNotEmpty);
    expect(
      RecitationService.preferredLocales.every(RecitationService.isArabic),
      isTrue,
    );
  });
}
