import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/offline_recitation_engine.dart';
import 'package:islamic_app/features/quran/data/services/recitation_service.dart';
import 'package:islamic_app/features/quran/data/services/stt_model_catalogue.dart';
import 'package:islamic_app/features/quran/data/services/stt_model_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PCM conversion', () {
    test('little-endian 16-bit samples become floats in -1..1', () {
      // 0, +1, -1, and full scale in both directions.
      final bytes = Uint8List.fromList([
        0x00, 0x00, //
        0x01, 0x00,
        0xFF, 0xFF,
        0x00, 0x80,
        0xFF, 0x7F,
      ]);

      final samples = OfflineRecitationEngine.pcm16ToFloat32(bytes);

      expect(samples.length, 5);
      expect(samples[0], 0.0);
      expect(samples[1], closeTo(1 / 32768, 1e-9));
      expect(samples[2], closeTo(-1 / 32768, 1e-9));
      expect(samples[3], -1.0);
      expect(samples[4], closeTo(1.0, 1e-4));
      for (final sample in samples) {
        expect(sample, inInclusiveRange(-1.0, 1.0));
      }
    });

    test('an odd trailing byte is dropped rather than misread', () {
      final samples = OfflineRecitationEngine.pcm16ToFloat32(
        Uint8List.fromList([0x00, 0x00, 0x11]),
      );
      expect(samples.length, 1);
    });

    test('the decode window is the thirty seconds Whisper actually reads', () {
      expect(
        OfflineRecitationEngine.windowSamples,
        OfflineRecitationEngine.sampleRate * 30,
      );
      expect(
        OfflineRecitationEngine.decodeEvery,
        lessThan(OfflineRecitationEngine.windowSamples),
      );
    });
  });

  group('engine choice', () {
    late Directory support;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // A real, empty support directory, so "installed" is decided by whether
      // the files are there rather than by a plugin that is not.
      support = await Directory.systemTemp.createTemp('stt_models_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async =>
                call.method == 'getApplicationSupportDirectory'
                    ? support.path
                    : null,
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      if (await support.exists()) {
        await support.delete(recursive: true);
      }
    });

    test('no choice means the device recogniser', () async {
      expect(await RecitationService.preferredOfflineModel(), isNull);
    });

    test('a choice naming a model that is not installed is ignored', () async {
      // This is the regression: the sheet stored the id, and nothing ever
      // checked whether the files behind it were on disk before listening.
      SharedPreferences.setMockInitialValues({
        SttModelStore.selectedKey: 'whisper-tiny',
      });
      expect(await RecitationService.preferredOfflineModel(), isNull);
    });

    test('a model whose files are on disk is the one that listens', () async {
      SharedPreferences.setMockInitialValues({
        SttModelStore.selectedKey: 'whisper-tiny',
      });
      final model = SttModelCatalogue.byId('whisper-tiny')!;
      final directory = Directory('${support.path}/stt_models/${model.folder}');
      await directory.create(recursive: true);
      for (final name in [model.encoder, model.decoder, model.tokens]) {
        await File('${directory.path}/$name').writeAsString('x');
      }

      expect(
        (await RecitationService.preferredOfflineModel())?.id,
        'whisper-tiny',
      );
    });

    test('a stale id from an older catalogue is ignored', () async {
      SharedPreferences.setMockInitialValues({
        SttModelStore.selectedKey: 'whisper-from-a-previous-release',
      });
      expect(await RecitationService.preferredOfflineModel(), isNull);
    });

    test('every catalogue entry names the three files it needs', () {
      for (final model in SttModelCatalogue.models) {
        expect(model.encoder, endsWith('.onnx'));
        expect(model.decoder, endsWith('.onnx'));
        expect(model.tokens, endsWith('.txt'));
        expect(model.folder, isNotEmpty);
        expect(model.url, startsWith('https://'));
      }
    });
  });
}
