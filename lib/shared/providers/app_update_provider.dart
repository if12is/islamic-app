import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/update_installer.dart';
import '../../core/services/update_service.dart';
import '../../core/utils/app_logger.dart';
import 'app_providers.dart';

enum AppUpdateStatus {
  idle,
  checking,
  current,
  available,
  downloading,
  installing,
  failed,
}

class AppUpdateState {
  const AppUpdateState({
    this.status = AppUpdateStatus.idle,
    this.release,
    this.currentLabel = '',
    this.progress,
    this.messageKey,
  });

  final AppUpdateStatus status;
  final AppRelease? release;
  final String currentLabel;
  final UpdateProgress? progress;

  /// Why the check or the download did not work, when it did not.
  ///
  /// A failed check used to be shown as a successful one that found nothing,
  /// so someone with no signal was told they were on the latest build.
  final String? messageKey;

  bool get canInstall =>
      release?.apkUrl != null &&
      release!.apkUrl!.isNotEmpty &&
      UpdateInstaller.isSupported;

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    AppRelease? release,
    String? currentLabel,
    UpdateProgress? progress,
    String? messageKey,
    bool clearRelease = false,
    bool clearProgress = false,
    bool clearMessage = false,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      release: clearRelease ? null : (release ?? this.release),
      currentLabel: currentLabel ?? this.currentLabel,
      progress: clearProgress ? null : (progress ?? this.progress),
      messageKey: clearMessage ? null : (messageKey ?? this.messageKey),
    );
  }
}

class AppUpdateNotifier extends Notifier<AppUpdateState> {
  @override
  AppUpdateState build() => const AppUpdateState();

  /// Startup path: only hit the network when the interval has elapsed.
  Future<void> checkIfDue() async {
    if (!UpdateInstaller.isSupported) {
      return;
    }
    if (!UpdateService.isDue(appPreferences)) {
      return;
    }
    await check(force: false);
  }

  /// [force] true means a tap in Settings: tell the user even if they skipped.
  Future<void> check({bool force = true}) async {
    state = state.copyWith(
      status: AppUpdateStatus.checking,
      clearProgress: true,
      clearMessage: true,
    );

    var label = state.currentLabel;
    try {
      final currentBuild = await UpdateService.currentBuildNumber();
      final currentName = await UpdateService.currentVersionName();
      label = '$currentName ($currentBuild)';

      final release = await UpdateService.fetchLatest();
      // Only a check that actually reached GitHub resets the timer. Marking a
      // failed one as done would put the next attempt twelve hours away.
      await UpdateService.markChecked(appPreferences);

      if (release == null ||
          !UpdateService.isNewer(
            release,
            currentBuild,
            currentVersionName: currentName,
          )) {
        // The release is kept even when there is nothing to install, so the
        // screen can name what it compared against. Dropping it here is what
        // left "you are on the latest version" as a bare assertion the reader
        // had no way to check — and no way to challenge when they believed it
        // was wrong.
        state = AppUpdateState(
          status: AppUpdateStatus.current,
          release: release,
          currentLabel: label,
        );
        return;
      }

      if (!force &&
          UpdateService.wasSkipped(appPreferences, release.buildNumber)) {
        state = AppUpdateState(
          status: AppUpdateStatus.current,
          release: release,
          currentLabel: label,
        );
        return;
      }

      state = AppUpdateState(
        status: AppUpdateStatus.available,
        release: release,
        currentLabel: label,
      );
    } on UpdateCheckException catch (e) {
      // Not knowing is not the same as there being nothing, and saying "you
      // are up to date" when the request never arrived is a lie the user
      // cannot see through.
      AppLogger.warning('Update check could not complete: $e');
      state = AppUpdateState(
        status: AppUpdateStatus.failed,
        currentLabel: label,
        messageKey: e.messageKey,
      );
    } catch (e, stack) {
      AppLogger.error('Update check failed', e, stack);
      state = AppUpdateState(
        status: AppUpdateStatus.failed,
        currentLabel: label,
        messageKey: 'update_check_failed',
      );
    }
  }

  Future<void> skip() async {
    final build = state.release?.buildNumber;
    if (build != null) {
      await UpdateService.skip(appPreferences, build);
    }
    state = state.copyWith(
      status: AppUpdateStatus.current,
      clearRelease: true,
      clearProgress: true,
    );
  }

  Future<void> download() async {
    final url = state.release?.apkUrl;
    if (url == null || url.isEmpty || !UpdateInstaller.isSupported) {
      state = state.copyWith(status: AppUpdateStatus.failed);
      return;
    }

    state = state.copyWith(
      status: AppUpdateStatus.downloading,
      progress: const UpdateProgress(percent: 0, installing: false),
    );

    await for (final progress in UpdateInstaller.download(url)) {
      if (progress.failed) {
        state = state.copyWith(
          status: AppUpdateStatus.failed,
          progress: progress,
        );
        return;
      }
      state = state.copyWith(
        status:
            progress.installing
                ? AppUpdateStatus.installing
                : AppUpdateStatus.downloading,
        progress: progress,
      );
    }
  }

  /// Stop a download in progress and put the offer back.
  ///
  /// The dialog cannot be dismissed while the bar is moving — a download that
  /// carries on behind a closed dialog is one nobody can see, cancel, or tell
  /// has finished — so there has to be a way out that is not the back button.
  void cancelDownload() {
    UpdateInstaller.cancel();
    state = state.copyWith(
      status:
          state.release == null
              ? AppUpdateStatus.idle
              : AppUpdateStatus.available,
      clearProgress: true,
      clearMessage: true,
    );
  }

  void dismissFailure() {
    state = state.copyWith(
      status:
          state.release == null
              ? AppUpdateStatus.idle
              : AppUpdateStatus.available,
      clearProgress: true,
    );
  }
}

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);
