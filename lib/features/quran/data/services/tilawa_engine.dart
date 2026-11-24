import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:record/record.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/tilawa_event.dart';
import 'tilawa_server.dart';
import 'tilawa_store.dart';

/// The on-device recitation listener ([Tilawa](https://github.com/yazinsai/tilawa)).
///
/// Tilawa is a JavaScript engine, so it runs inside a hidden WebView that the
/// page keeps in its widget tree (see [view]). The bundle in
/// `assets/tilawa/host.js` is built from `tool/tilawa`. Its models, runtime
/// and reference are downloaded once by [TilawaStore] and served to the
/// WebView from a loopback [TilawaServer], so after that listening needs no
/// network. Audio is captured and recognised inside the WebView; nothing is
/// uploaded.
class TilawaEngine {
  TilawaEngine() {
    final controller =
        WebViewController(onPermissionRequest: (request) => request.grant())
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel(_channelName, onMessageReceived: _onMessage);
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      unawaited(platform.setMediaPlaybackRequiresUserGesture(false));
    }
    _controller = controller;
  }

  static const String _channelName = 'TilawaChannel';

  /// Whether a WebView is available on this platform at all.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  late final WebViewController _controller;
  final StreamController<TilawaEvent> _events = StreamController.broadcast();
  Completer<void>? _booted;
  TilawaServer? _server;
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
    final server = await TilawaServer.start(
      mirror: await TilawaStore.root(),
      hostJs: script,
    );
    _server = server;
    await _controller.loadRequest(server.origin);
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

  /// Boot the page and load the model; the files must already be installed
  /// ([TilawaStore.isInstalled] for [tier]). Emits [TilawaProgress], then
  /// [TilawaReady] or [TilawaFailure].
  Future<void> load(TilawaTier tier) async {
    try {
      await _ensureBooted();
    } catch (e, stack) {
      AppLogger.error('Tilawa page did not start', e, stack);
      // Let a retry start from scratch instead of waiting on the dead boot.
      _booted = null;
      await _server?.close();
      _server = null;
      if (_events.isClosed) {
        return;
      }
      _events.add(
        TilawaFailure(stage: 'load', name: 'BootError', message: '$e'),
      );
      return;
    }
    await _call("window.host.load('${tier.name}', '${_server!.assetBase}')");
  }

  /// Ask for the microphone at the OS level (the WebView cannot do it alone on
  /// Android), then start a session. A null [passage] is free recitation.
  /// Returns false when the permission was refused.
  Future<bool> start({int? surah, int? fromAyah, int? toAyah}) async {
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
    await _server?.close();
  }
}
