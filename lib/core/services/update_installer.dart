import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ota_update/ota_update.dart';

import '../utils/app_logger.dart';

/// Where a download has got to.
class UpdateProgress {
  const UpdateProgress({
    required this.percent,
    required this.installing,
    this.failed = false,
    this.message,
  });

  /// 0 to 100, or null while the size is still unknown.
  final int? percent;

  /// True once the file is on disk and Android's installer has been asked.
  final bool installing;

  final bool failed;
  final String? message;
}

/// Downloads the new APK and hands it to Android's package installer.
///
/// The install itself is Android's to run, not the app's: it shows its own
/// confirmation, checks the signature against the installed copy, and refuses
/// if they do not match. That last part is why the CI signing key matters —
/// with a throwaway key per build, this step fails every time no matter how
/// well the download went.
class UpdateInstaller {
  UpdateInstaller._();

  static StreamSubscription<OtaEvent>? _subscription;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Fetch [url] and start the install, reporting progress as it goes.
  static Stream<UpdateProgress> download(String url, {String? fileName}) {
    final controller = StreamController<UpdateProgress>();

    if (!isSupported) {
      controller
        ..add(
          const UpdateProgress(
            percent: null,
            installing: false,
            failed: true,
            message: 'unsupported',
          ),
        )
        ..close();
      return controller.stream;
    }

    try {
      _subscription?.cancel();
      _subscription = OtaUpdate()
          .execute(url, destinationFilename: fileName ?? 'islamic-app.apk')
          .listen(
            (event) {
              final percent = int.tryParse(event.value ?? '');
              switch (event.status) {
                case OtaStatus.DOWNLOADING:
                  controller.add(
                    UpdateProgress(percent: percent, installing: false),
                  );
                case OtaStatus.INSTALLING:
                case OtaStatus.INSTALLATION_DONE:
                  // Android's installer is up; the app is about to be replaced.
                  controller.add(
                    const UpdateProgress(percent: 100, installing: true),
                  );
                  unawaited(controller.close());
                case OtaStatus.ALREADY_RUNNING_ERROR:
                case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                case OtaStatus.INTERNAL_ERROR:
                case OtaStatus.DOWNLOAD_ERROR:
                case OtaStatus.CHECKSUM_ERROR:
                case OtaStatus.INSTALLATION_ERROR:
                case OtaStatus.CANCELED:
                  AppLogger.warning('Update failed: ${event.status}');
                  controller.add(
                    UpdateProgress(
                      percent: null,
                      installing: false,
                      failed: true,
                      message: event.status.name,
                    ),
                  );
                  unawaited(controller.close());
              }
            },
            onError: (Object error, StackTrace stack) {
              AppLogger.error('Update download failed', error, stack);
              controller
                ..add(
                  const UpdateProgress(
                    percent: null,
                    installing: false,
                    failed: true,
                  ),
                )
                ..close();
            },
          );
    } catch (e, stack) {
      AppLogger.error('Could not start the update', e, stack);
      controller
        ..add(
          const UpdateProgress(percent: null, installing: false, failed: true),
        )
        ..close();
    }

    return controller.stream;
  }

  static void cancel() {
    _subscription?.cancel();
    _subscription = null;
  }
}
