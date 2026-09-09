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

/// Lets a percent through only when it is one the bar has not already drawn.
///
/// The plugin reports progress on every Okio segment it reads — 8 KiB at a
/// time, which for an 86 MB package is about eleven thousand events. Each one
/// crossed the platform channel, replaced the provider's state and rebuilt the
/// dialog, so the phone spent its main thread redrawing a progress bar eleven
/// thousand times instead of showing the download it was drawing. The network
/// was never the slow part; the app in front of it was.
///
/// A bar is a hundred positions wide, so a hundred events is everything it can
/// express. The rest are dropped.
class DownloadThrottle {
  int? _last;

  /// True when [percent] says something the last one did not.
  ///
  /// An unknown percent always passes: it means the size is not known yet, and
  /// that is a state the dialog shows differently rather than a repeat.
  bool accept(int? percent) {
    if (percent == null) {
      return true;
    }
    if (percent == _last) {
      return false;
    }
    _last = percent;
    return true;
  }
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

    final throttle = DownloadThrottle();

    try {
      _subscription?.cancel();
      _subscription = OtaUpdate()
          .execute(url, destinationFilename: fileName ?? 'islamic-app.apk')
          .listen(
            (event) {
              final percent = int.tryParse(event.value ?? '');
              switch (event.status) {
                case OtaStatus.DOWNLOADING:
                  if (!throttle.accept(percent)) {
                    return;
                  }
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
