import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/secure_http_client.dart';
import '../../../../core/utils/app_logger.dart';

/// One immutable file of the listener, as published at tilawa.dev.
class TilawaFile {
  const TilawaFile(this.path, this.bytes, [this.sha256]);

  /// Relative to `https://tilawa.dev/v1/`, and to the local mirror's root.
  final String path;
  final int bytes;

  /// Checked after download when known.
  final String? sha256;
}

/// Which model the listener runs on. Full is the more accurate one; lite is
/// about a third of the size, for phones short on space or memory.
enum TilawaTier { lite, full }

enum TilawaDownloadState { downloading, installed, failed, cancelled }

class TilawaDownloadProgress {
  const TilawaDownloadProgress({
    required this.state,
    this.received = 0,
    this.total = 0,
  });

  final TilawaDownloadState state;
  final int received;
  final int total;

  double get ratio => total <= 0 ? 0 : (received / total).clamp(0.0, 1.0);
}

/// Everything the on-device recitation listener needs, kept on disk.
///
/// The user is asked once to download what the chosen model needs — the model
/// itself (about 25 MB lite or 68 MB full), the inference runtime (about 28 MB)
/// and the Quran reference (about 5 MB) — and after that listening needs no
/// network. Nothing downloads on its own: up to about 100 MB on someone's data
/// plan is not a decision to make quietly.
///
/// Files live under the app's support folder, mirroring the layout of
/// `https://tilawa.dev/v1/`, so [TilawaServer] can hand them to the listener
/// as if it were the site. They are immutable upstream (a new model gets a new
/// path), so a file that is present at the right size is never fetched again.
class TilawaStore {
  TilawaStore._();

  static const String baseUrl = 'https://tilawa.dev/v1/';

  /// The ONNX Runtime Web version the listener bundle in `assets/tilawa` was
  /// built with; it names the folder the runtime files are published under.
  /// Change it together with `tool/tilawa/package.json`.
  static const String ortVersion = '1.30.0';

  /// Needed whichever model is chosen.
  static const List<TilawaFile> shared = [
    TilawaFile(
      'reference/ref-v2.json',
      4749281,
      'f236384ea91e81ad554ba2777bc4073c3ff41e34120343a8a474571c577b7727',
    ),
    TilawaFile(
      'runtime/ort/$ortVersion/ort-wasm-simd-threaded.jsep.mjs',
      46851,
    ),
    TilawaFile(
      'runtime/ort/$ortVersion/ort-wasm-simd-threaded.jsep.wasm',
      28312028,
    ),
  ];

  static const TilawaFile liteModel = TilawaFile(
    'models/spliced-clean-lite/1-int8/model.onnx',
    24650054,
    '4974de78d3c35d2542e7a24d99b747e1160d6e31e366fb68492b74a789890f1b',
  );

  static const TilawaFile fullModel = TilawaFile(
    'models/spliced-clean/1-int8/model.onnx',
    67759744,
    '714e98addee73b1b8781ad7d99b6d3c745acd9116638baf4e12891f53a15af1b',
  );

  /// Every file the listener can ever hold.
  static const List<TilawaFile> files = [...shared, liteModel, fullModel];

  /// What one choice of model needs on disk.
  static List<TilawaFile> filesFor(TilawaTier tier) => [
    ...shared,
    tier == TilawaTier.full ? fullModel : liteModel,
  ];

  static int totalBytesFor(TilawaTier tier) =>
      filesFor(tier).fold(0, (sum, file) => sum + file.bytes);

  static CancelToken? _cancelToken;

  /// The mirror's root folder (the equivalent of `https://tilawa.dev/v1/`).
  static Future<Directory> root() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/tilawa/v1');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<File> _file(TilawaFile file) async {
    final directory = await root();
    return File('${directory.path}/${file.path}');
  }

  static Future<bool> _present(TilawaFile file) async {
    final local = await _file(file);
    return local.existsSync() && await local.length() == file.bytes;
  }

  /// Whether everything [tier] needs is on disk and whole — a half-downloaded
  /// model would fail at the worst moment otherwise.
  static Future<bool> isInstalled(TilawaTier tier) async {
    try {
      for (final file in filesFor(tier)) {
        if (!await _present(file)) {
          return false;
        }
      }
      return true;
    } catch (e, stack) {
      AppLogger.error('Could not check the recitation listener', e, stack);
      return false;
    }
  }

  /// The model to listen with: full when it is there, else lite, else none.
  static Future<TilawaTier?> installedTier() async {
    for (final tier in [TilawaTier.full, TilawaTier.lite]) {
      if (await isInstalled(tier)) {
        return tier;
      }
    }
    return null;
  }

  /// Bytes on disk, for the storage screen.
  static Future<int> installedSize() async {
    var sum = 0;
    try {
      for (final file in files) {
        final local = await _file(file);
        if (local.existsSync()) {
          sum += await local.length();
        }
      }
    } catch (e) {
      AppLogger.warning('Could not measure the recitation listener: $e');
    }
    return sum;
  }

  /// Download whatever is missing, reporting overall progress.
  ///
  /// Ends with [TilawaDownloadState.installed], [failed] or [cancelled]. A
  /// partial file is never left looking finished: each one is written under a
  /// `.part` name, checked, then renamed.
  static Stream<TilawaDownloadProgress> download(TilawaTier tier) async* {
    final wanted = filesFor(tier);
    final total = totalBytesFor(tier);
    final token = CancelToken();
    _cancelToken = token;
    final dio = Dio();
    var done = 0;

    yield TilawaDownloadProgress(
      state: TilawaDownloadState.downloading,
      total: total,
    );

    for (final file in wanted) {
      if (await _present(file)) {
        done += file.bytes;
        continue;
      }

      final uri = Uri.parse('$baseUrl${file.path}');
      if (!SecureHttpClient.isAllowedHost(uri.host)) {
        yield TilawaDownloadProgress(
          state: TilawaDownloadState.failed,
          total: total,
        );
        return;
      }

      final target = await _file(file);
      await target.parent.create(recursive: true);
      final part = File('${target.path}.part');
      final progress = StreamController<int>();

      try {
        // The outcome is captured rather than thrown, so a failure that lands
        // while the progress loop below is still running is not left unhandled.
        final outcome = dio
            .download(
              uri.toString(),
              part.path,
              cancelToken: token,
              onReceiveProgress: (received, _) => progress.add(received),
            )
            .then<Object?>((_) => null, onError: (Object e) => e)
            .whenComplete(progress.close);

        await for (final received in progress.stream) {
          yield TilawaDownloadProgress(
            state: TilawaDownloadState.downloading,
            received: done + received,
            total: total,
          );
        }
        final failure = await outcome;
        if (failure != null) {
          throw failure;
        }

        if (await part.length() != file.bytes) {
          throw const FormatException('Truncated download');
        }
        final expected = file.sha256;
        if (expected != null &&
            (await sha256.bind(part.openRead()).first).toString() != expected) {
          throw const FormatException('Checksum mismatch');
        }
        await part.rename(target.path);
        done += file.bytes;
      } catch (e) {
        if (part.existsSync()) {
          await part.delete();
        }
        final cancelled = e is DioException && CancelToken.isCancel(e);
        if (!cancelled) {
          AppLogger.warning('Recitation listener download failed: $e');
        }
        yield TilawaDownloadProgress(
          state:
              cancelled
                  ? TilawaDownloadState.cancelled
                  : TilawaDownloadState.failed,
          total: total,
        );
        return;
      } finally {
        await progress.close();
      }
    }

    yield TilawaDownloadProgress(
      state: TilawaDownloadState.installed,
      received: total,
      total: total,
    );
  }

  static void cancel() => _cancelToken?.cancel();

  static Future<void> remove() async {
    final directory = await root();
    if (directory.existsSync()) {
      await directory.parent.delete(recursive: true);
    }
  }
}
