import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../data/services/tafsir_service.dart';

final tafsirServiceProvider = Provider<TafsirService>((ref) => TafsirService());

/// The tafsir the reader prefers, remembered between sessions.
class TafsirEditionNotifier extends Notifier<String> {
  @override
  String build() {
    final saved = appPreferences.getString(AppConstants.tafsirEditionKey);
    if (saved != null && TafsirService.isKnownEdition(saved)) {
      return saved;
    }
    return TafsirService.editions.first.id;
  }

  Future<void> select(String editionId) async {
    if (!TafsirService.isKnownEdition(editionId)) {
      return;
    }
    state = editionId;
    await appPreferences.setString(AppConstants.tafsirEditionKey, editionId);
  }
}

final tafsirEditionProvider =
    NotifierProvider<TafsirEditionNotifier, String>(TafsirEditionNotifier.new);

/// Identifies one verse in one tafsir.
class TafsirRequest {
  const TafsirRequest({
    required this.editionId,
    required this.surahNumber,
    required this.verseNumber,
  });

  final String editionId;
  final int surahNumber;
  final int verseNumber;

  @override
  bool operator ==(Object other) =>
      other is TafsirRequest &&
      other.editionId == editionId &&
      other.surahNumber == surahNumber &&
      other.verseNumber == verseNumber;

  @override
  int get hashCode => Object.hash(editionId, surahNumber, verseNumber);
}

/// Tafsir text for a verse; null when it is neither cached nor reachable.
final tafsirTextProvider = FutureProvider.family<String?, TafsirRequest>((
  ref,
  request,
) async {
  final service = ref.watch(tafsirServiceProvider);
  return service.forVerse(
    editionId: request.editionId,
    surahNumber: request.surahNumber,
    verseNumber: request.verseNumber,
  );
});
