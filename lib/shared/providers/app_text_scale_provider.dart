import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';
import 'app_providers.dart';

/// How large the app sets its own text, everywhere outside the Mushaf.
///
/// The reading page could already be resized three ways — pinch, the toolbar,
/// the settings sheet — and every other screen in the app was fixed: 10px on
/// the navigation bar, 11px under the home shortcuts, 12.5px for anything
/// secondary. So the app knew exactly how to serve a weak eye, and did it on
/// one screen out of thirty-eight.
///
/// Flutter honours the operating system's own font scale by default, and that
/// stays true — this multiplies it rather than replacing it. It exists because
/// the OS setting lives several screens deep in a menu the people who most
/// need it do not know is there, and an app they already have open is a much
/// shorter walk than Android's display settings.
enum AppTextScale {
  normal('normal', 1.0),
  large('large', 1.18),
  largest('largest', 1.36);

  const AppTextScale(this.id, this.factor);

  /// Stored rather than the index, so reordering the enum cannot silently
  /// resize every screen for everyone who already chose.
  final String id;

  /// What the app's own text is multiplied by.
  final double factor;

  /// The translation key naming this size to the reader.
  String get labelKey => 'text_scale_$id';

  static AppTextScale fromId(String? id) => AppTextScale.values.firstWhere(
    (scale) => scale.id == id,
    orElse: () => AppTextScale.normal,
  );
}

class AppTextScaleNotifier extends Notifier<AppTextScale> {
  @override
  AppTextScale build() => AppTextScale.fromId(
    appPreferences.getString(AppConstants.appTextScaleKey),
  );

  Future<void> set(AppTextScale scale) async {
    state = scale;
    await appPreferences.setString(AppConstants.appTextScaleKey, scale.id);
    AppLogger.info('App text scale set to ${scale.id}');
  }
}

final appTextScaleProvider =
    NotifierProvider<AppTextScaleNotifier, AppTextScale>(
      AppTextScaleNotifier.new,
    );

/// Applies the chosen size to everything below it.
///
/// The device's own setting is kept and multiplied, not overwritten: someone
/// who has already enlarged text system-wide should not have the app quietly
/// undo that. The result is capped, because past roughly twice the base size
/// the layouts stop being layouts — a nav bar label that wraps to three lines
/// helps nobody.
class AppTextScaleScope extends ConsumerWidget {
  const AppTextScaleScope({super.key, required this.child});

  final Widget child;

  static const double _ceiling = 2.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(appTextScaleProvider);
    final media = MediaQuery.of(context);
    final combined = (media.textScaler.scale(1) * scale.factor).clamp(
      1.0,
      _ceiling,
    );

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(combined)),
      child: child,
    );
  }
}
