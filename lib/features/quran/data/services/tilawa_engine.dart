import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:record/record.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/tilawa_event.dart';

/// The on-device recitation listener ([Tilawa](https://github.com/yazinsai/tilawa)).
///
/// Tilawa is a JavaScript engine, so it runs inside a hidden WebView that the
/// page keeps in its widget tree (see [view]). The bundle in
/// `assets/tilawa/host.js` is built from `tool/tilawa`. Audio is captured and
/// recognised inside the WebView; nothing is uploaded. The first run downloads
/// the model (25–70 MB) once and the WebView caches it, after which listening
/// needs no network.
class TilawaEngine {
  TilawaEngine() {
    final controller = WebViewController(
      onPermissionRequest: (request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(_channelName, onMessageReceived: _onMessage);
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      unawaited(platform.setMediaPlaybackRequiresUserGesture(false));
    }
    _controller = controller;
  }

  static const String _channelName = 'TilawaChannel';

  /// The page is served as if from tilawa.dev, which is both a secure context
  /// (the microphone needs one) and the same origin as the model files, so the
  /// WebView's cache of them survives restarts.
  static const String _origin = 'https://tilawa.dev/';

  /// Whether a WebView is available on this platform at all.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  late final WebViewController _controller;
  final StreamController<TilawaEvent> _events = StreamController.broadcast();
  Completer<void>? _booted;
  bool _disposed = false;

  Stream<TilawaEvent> get events => _events.stream;

  /// Put this in the widget tree (a 1×1 box is enough) so the platform view
  /// is created.
  Widget get view => WebViewWidget(controller: _controller);

  void _onMessage(JavaScriptMessage message) {
    final event = TilawaEvent.parse(message.message);
    if (event == null || _disposed) {
      return;
    }
    if (event is TilawaBooted) {
      final booted = _booted;
      if (booted != null && !booted.isCompleted) {
        booted.complete();
      }
      return;
    }
    _events.add(event);
  }

  Future<void> _ensureBooted() async {
    final existing = _booted;
    if (existing != null) {
      return existing.future;
    }
    final booted = Completer<void>();
    _booted = booted;
    final script = await rootBundle.loadString('assets/tilawa/host.js');
    // A literal "</script" inside the bundle would end the tag early.
    final safe = script.replaceAll('</script', r'<\/script');
    await _controller.loadHtmlString(
      '<!doctype html><html><head><meta charset="utf-8"></head>'
      '<body><script>$safe</script></body></html>',
      baseUrl: _origin,
    );
    return booted.future.timeout(const Duration(seconds: 20));
  }

  Future<void> _call(String expression) async {
    try {
      await _controller.runJavaScript(expression);
    } catch (e, stack) {
      AppLogger.error('Tilawa call failed: $expression', e, stack);
      if (_events.isClosed) {
        return;
      }
      _events.add(
        TilawaFailure(stage: 'load', name: 'BridgeError', message: '$e'),
      );
    }
  }

  /// Boot the page and load the model. Emits [TilawaProgress], then
  /// [TilawaReady] or [TilawaFailure].
  Future<void> load() async {
    try {
      await _ensureBooted();
    } catch (e, stack) {
      AppLogger.error('Tilawa page did not start', e, stack);
      if (_events.isClosed) {
        return;
      }
      _events.add(
        TilawaFailure(stage: 'load', name: 'BootError', message: '$e'),
      );
      return;
    }
    await _call("window.host.load('auto')");
  }

  /// Ask for the microphone at the OS level (the WebView cannot do it alone on
  /// Android), then start a session. A null [passage] is free recitation.
  /// Returns false when the permission was refused.
  Future<bool> start({
    int? surah,
    int? fromAyah,
    int? toAyah,
  }) async {
    final recorder = AudioRecorder();
    try {
      if (!await recorder.hasPermission()) {
        return false;
      }
    } finally {
      await recorder.dispose();
    }
    final passage =
        surah == null
            ? 'null'
            : '{surah:$surah,fromAyah:$fromAyah,toAyah:$toAyah}';
    await _call('window.host.start($passage)');
    return true;
  }

  /// Stop listening; a [TilawaDone] follows with the confirmed slips.
  Future<void> stop() => _call('window.host.stop()');

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    if (_booted?.isCompleted == true) {
      await _call('window.host.dispose()');
    }
    _disposed = true;
    await _events.close();
  }
}
