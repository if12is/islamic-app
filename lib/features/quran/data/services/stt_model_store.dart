import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/app_logger.dart';
import 'stt_model_catalogue.dart';

/// Where a model is in its life.
enum SttModelState { absent, downloading, extracting, installed, failed }

/// Progress of one download, for the screen that started it.
class SttDownloadProgress {
  const SttDownloadProgress({
    required this.state,
    this.received = 0,
    this.total = 0,
  });

  final SttModelState state;
  final int received;
  final int total;

  double get ratio => total <= 0 ? 0 : (received / total).clamp(0.0, 1.0);
}

/// Downloads, unpacks, and keeps track of offline recognition models.
///
/// Everything here is the user's to undo: a model can be cancelled mid-flight
/// and deleted afterwards, and the app works exactly as before without one.
/// Nothing downloads on its own — a hundred megabytes on someone's data plan
/// is not a decision an app gets to make quietly.
class SttModelStore {
  SttModelStore._();

  static const String selectedKey = 'stt_selected_model';

  static CancelToken? _cancelToken;

  /// The folder models are unpacked into.
  static Future<Directory> _root() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/stt_models');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<Directory> directoryFor(SttModel model) async {
    final root = await _root();
    return Directory('${root.path}/${model.folder}');
  }

  /// A model counts as installed only when all three files are on disk — a
  /// half-unpacked archive would fail at the worst moment otherwise.
  static Future<bool> isInstalled(SttModel model) async {
    final directory = await directoryFor(model);
    for (final name in [model.encoder, model.decoder, model.tokens]) {
      if (!await File('${directory.path}/$name').exists()) {
        return false;
      }
    }
    return true;
  }

  static Future<int> installedSize(SttModel model) async {
    final directory = await directoryFor(model);
    if (!await directory.exists()) {
      return 0;
    }
    var total = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// Which model the recitation uses, or null for the device recogniser.
  static Future<String?> selectedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(selectedKey);
  }

  static Future<void> select(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(selectedKey);
    } else {
      await prefs.setString(selectedKey, id);
    }
  }

  /// Fetch and unpack a model, reporting progress as it goes.
  static Stream<SttDownloadProgress> download(SttModel model) {
    final controller = StreamController<SttDownloadProgress>();

    Future<void> run() async {
      final root = await _root();
      final archivePath = '${root.path}/${model.id}.tar.bz2';
      final archiveFile = File(archivePath);
      _cancelToken = CancelToken();

      try {
        controller.add(
          SttDownloadProgress(
            state: SttModelState.downloading,
            total: model.downloadBytes,
          ),
        );

        // A plain Dio client: this is a GitHub release asset, not one of the
        // app's own hosts, so it does not belong behind the allowlist.
        await Dio().download(
          model.url,
          archivePath,
          cancelToken: _cancelToken,
          onReceiveProgress: (count, size) {
            if (controller.isClosed) {
              return;
            }
            controller.add(
              SttDownloadProgress(
                state: SttModelState.downloading,
                received: count,
                total: size > 0 ? size : model.downloadBytes,
              ),
            );
          },
        );

        controller.add(
          const SttDownloadProgress(state: SttModelState.extracting),
        );
        await _extract(archiveFile, root);
        if (await archiveFile.exists()) {
          await archiveFile.delete();
        }

        if (await isInstalled(model)) {
          controller.add(
            const SttDownloadProgress(state: SttModelState.installed),
          );
        } else {
          AppLogger.warning('Model ${model.id} unpacked but files are missing');
          controller.add(
            const SttDownloadProgress(state: SttModelState.failed),
          );
        }
      } catch (e, stack) {
        if (e is DioException && CancelToken.isCancel(e)) {
          AppLogger.info('Model download cancelled: ${model.id}');
        } else {
          AppLogger.error('Model download failed: ${model.id}', e, stack);
        }
        if (await archiveFile.exists()) {
          await archiveFile.delete();
        }
        controller.add(const SttDownloadProgress(state: SttModelState.failed));
      } finally {
        _cancelToken = null;
        await controller.close();
      }
    }

    unawaited(run());
    return controller.stream;
  }

  static void cancel() {
    _cancelToken?.cancel('cancelled by the user');
    _cancelToken = null;
  }

  static bool get isDownloading => _cancelToken != null;

  /// Free the space again.
  static Future<void> remove(SttModel model) async {
    final directory = await directoryFor(model);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    if (await selectedId() == model.id) {
      await select(null);
    }
  }

  /// Unpack a `.tar.bz2` into [destination].
  static Future<void> _extract(File archive, Directory destination) async {
    final bytes = await archive.readAsBytes();
    final tar = TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes));

    for (final entry in tar) {
      if (!entry.isFile) {
        continue;
      }
      final file = File('${destination.path}/${entry.name}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.content as List<int>);
    }
  }
}
