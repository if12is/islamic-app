import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/stt_model_catalogue.dart';
import 'package:islamic_app/features/quran/data/services/stt_model_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Downloading a hundred megabytes is a decision, so the facts behind it have
/// to be right: real URLs, honest sizes, and nothing selected by default.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('The catalogue', () {
    test('every model has a real HTTPS source and named files', () {
      expect(SttModelCatalogue.models, isNotEmpty);

      for (final model in SttModelCatalogue.models) {
        expect(model.url, startsWith('https://'), reason: model.id);
        expect(model.url, endsWith('.tar.bz2'), reason: model.id);
        expect(model.encoder, isNotEmpty);
        expect(model.decoder, isNotEmpty);
        expect(model.tokens, isNotEmpty);
        expect(model.licence, isNotEmpty);
      }
    });

    test('sizes are stated and unpacking is bigger than the download', () {
      for (final model in SttModelCatalogue.models) {
        expect(model.downloadBytes, greaterThan(1000000), reason: model.id);
        expect(
          model.installedBytes,
          greaterThan(model.downloadBytes),
          reason: '${model.id} must not understate what it occupies',
        );
      }
    });

    test('ids are unique and findable', () {
      final ids = SttModelCatalogue.models.map((m) => m.id).toSet();
      expect(ids.length, SttModelCatalogue.models.length);

      for (final id in ids) {
        expect(SttModelCatalogue.byId(id), isNotNull);
      }
      expect(SttModelCatalogue.byId('does-not-exist'), isNull);
    });

    test('sizes read the way a person would say them', () {
      expect(SttModelCatalogue.formatBytes(116000000), '116 MB');
      expect(SttModelCatalogue.formatBytes(1000000000), '1.0 GB');
    });
  });

  group('Choosing an engine', () {
    test('nothing is selected until the user selects it', () async {
      expect(await SttModelStore.selectedId(), isNull);
    });

    test('a selection is remembered and can be undone', () async {
      await SttModelStore.select('whisper-base');
      expect(await SttModelStore.selectedId(), 'whisper-base');

      await SttModelStore.select(null);
      expect(await SttModelStore.selectedId(), isNull);
    });
  });
}
