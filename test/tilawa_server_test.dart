import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/tilawa_server.dart';
import 'package:islamic_app/features/quran/data/services/tilawa_store.dart';

void main() {
  group('TilawaStore', () {
    test(
      'lists every file the listener needs, with the sizes the site serves',
      () {
        final paths = TilawaStore.files.map((f) => f.path).toList();
        expect(paths, contains('reference/ref-v2.json'));
        expect(paths, contains('models/spliced-clean-lite/1-int8/model.onnx'));
        expect(paths, contains('models/spliced-clean/1-int8/model.onnx'));
        expect(paths.where((p) => p.endsWith('.wasm')), hasLength(1));
        expect(paths.where((p) => p.endsWith('.mjs')), hasLength(1));
        // About 125 MB all told, which the download screen quotes.
        expect(TilawaStore.totalBytes, inInclusiveRange(120e6, 130e6));
      },
    );

    test('checks every model against a known digest', () {
      for (final file in TilawaStore.files.where(
        (f) => f.path.endsWith('.onnx'),
      )) {
        expect(file.sha256, hasLength(64));
      }
    });
  });

  group('TilawaServer', () {
    late Directory mirror;
    late TilawaServer server;
    final client = HttpClient();

    setUp(() async {
      mirror = await Directory.systemTemp.createTemp('tilawa_mirror');
      await File('${mirror.path}/a.txt').writeAsString('hello');
      await Directory('${mirror.path}/runtime').create();
      await File(
        '${mirror.path}/runtime/x.wasm',
      ).writeAsBytes([0, 97, 115, 109]);
      server = await TilawaServer.start(mirror: mirror, hostJs: 'var host=1;');
    });

    tearDown(() async {
      await server.close();
      await mirror.delete(recursive: true);
    });

    Future<(int, String, List<int>)> get(String url) async {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      return (
        response.statusCode,
        response.headers.contentType?.mimeType ?? '',
        bytes,
      );
    }

    test(
      'serves the page, the bundle and the mirrored files on loopback',
      () async {
        expect(server.origin.host, '127.0.0.1');

        final page = await get('${server.origin}');
        expect(page.$1, 200);
        expect(String.fromCharCodes(page.$3), contains('/host.js'));

        final js = await get('${server.origin}host.js');
        expect(js.$2, 'text/javascript');
        expect(String.fromCharCodes(js.$3), 'var host=1;');

        final file = await get('${server.assetBase}a.txt');
        expect(String.fromCharCodes(file.$3), 'hello');

        final wasm = await get('${server.assetBase}runtime/x.wasm');
        expect(wasm.$2, 'application/wasm');
        expect(wasm.$3, [0, 97, 115, 109]);
      },
    );

    test('never reads outside the mirror', () async {
      await File('${mirror.parent.path}/secret.txt').writeAsString('no');
      final up = await get('${server.assetBase}..%2Fsecret.txt');
      expect(up.$1, 404);
      final missing = await get('${server.assetBase}nope.bin');
      expect(missing.$1, 404);
      final other = await get('${server.origin}etc/passwd');
      expect(other.$1, 404);
    });
  });
}
