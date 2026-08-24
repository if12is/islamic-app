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
  });

  final AppUpdateStatus status;
  final AppRelease? release;
  final String currentLabel;
  final UpdateProgress? progress;

  bool get canInstall =>
      release?.apkUrl != null &&
      release!.apkUrl!.isNotEmpty &&
      UpdateInstaller.isSupported;

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    AppRelease? release,
    String? currentLabel,
    UpdateProgress? progress,
    bool clearRelease = false,
    bool clearProgress = false,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      release: clearRelease ? null : (release ?? this.release),
      currentLabel: currentLabel ?? this.currentLabel,
      progress: clearProgress ? null : (progress ?? this.progress),
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
    );
    try {
      final currentBuild = await UpdateService.currentBuildNumber();
      final currentName = await UpdateService.currentVersionName();
      final label = '$currentName ($currentBuild)';

      await UpdateService.markChecked(appPreferences);
      final release = await UpdateService.fetchLatest();

      if (release == null || !UpdateService.isNewer(release, currentBuild)) {
        state = AppUpdateState(
          status: AppUpdateStatus.current,
          currentLabel: label,
        );
        return;
      }

      if (!force &&
          UpdateService.wasSkipped(appPreferences, release.buildNumber)) {
        state = AppUpdateState(
          status: AppUpdateStatus.current,
          currentLabel: label,
        );
        return;
      }

      state = AppUpdateState(
        status: AppUpdateStatus.available,
        release: release,
        currentLabel: label,
      );
    } catch (e, stack) {
      AppLogger.error('Update check failed', e, stack);
      state = state.copyWith(
        status: AppUpdateStatus.failed,
        clearRelease: true,
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
