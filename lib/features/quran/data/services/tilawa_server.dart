import 'dart:convert';
import 'dart:io';

import '../../../../core/utils/app_logger.dart';

/// A tiny web server on the loopback address, so the recitation listener's
/// WebView finds its page and files where it expects them.
///
/// It stands in for tilawa.dev: `/` is the listener page, `/host.js` the
/// bundled engine and `/v1/...` the files [TilawaStore] downloaded. Serving
/// over `http://127.0.0.1` also makes the page a secure context, which the
/// microphone requires, without any file ever leaving the device. It listens
/// on loopback only and serves nothing outside [mirror].
class TilawaServer {
  TilawaServer._(this._server, this._mirror, this._hostJs);

  final HttpServer _server;
  final Directory _mirror;
  final String _hostJs;

  static Future<TilawaServer> start({
    required Directory mirror,
    required String hostJs,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final instance = TilawaServer._(server, mirror, hostJs);
    server.listen(
      instance._handle,
      onError: (Object e) {
        AppLogger.warning('Recitation listener server error: $e');
      },
    );
    return instance;
  }

  Uri get origin => Uri.parse('http://127.0.0.1:${_server.port}/');

  /// Where the listener expects tilawa.dev/v1/ to be.
  String get assetBase => '${origin}v1/';

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      final path = request.uri.path;
      if (path == '/') {
        _text(
          response,
          'text/html; charset=utf-8',
          '<!doctype html><html><head><meta charset="utf-8"></head><body>'
              '<script src="/host.js"></script></body></html>',
        );
      } else if (path == '/host.js') {
        _text(response, 'text/javascript; charset=utf-8', _hostJs);
      } else if (path.startsWith('/v1/')) {
        await _file(request, response, path.substring(4));
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } catch (e) {
      AppLogger.warning('Recitation listener request failed: $e');
      try {
        response.statusCode = HttpStatus.internalServerError;
      } catch (_) {}
    } finally {
      await response.close();
    }
  }

  void _text(HttpResponse response, String type, String body) {
    final bytes = utf8.encode(body);
    response.headers.contentType = ContentType.parse(type);
    response.contentLength = bytes.length;
    response.add(bytes);
  }

  Future<void> _file(
    HttpRequest request,
    HttpResponse response,
    String relative,
  ) async {
    // Plain names only: nothing outside the mirror is ever readable.
    final segments = Uri.decodeFull(relative).split('/');
    if (segments.any((s) => s.isEmpty || s == '.' || s == '..')) {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    final file = File('${_mirror.path}/${segments.join('/')}');
    if (!file.existsSync()) {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    response.headers.contentType = ContentType.parse(switch (relative
        .split('.')
        .last) {
      'mjs' || 'js' => 'text/javascript',
      'wasm' => 'application/wasm',
      'json' => 'application/json',
      _ => 'application/octet-stream',
    });
    response.contentLength = await file.length();
    if (request.method == 'GET') {
      await response.addStream(file.openRead());
    }
  }

  Future<void> close() => _server.close(force: true);
}
