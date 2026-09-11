import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/utils/arabic_numerals.dart';
import '../../../../shared/providers/app_update_provider.dart';

/// Check-and-install sheet used from Settings and from the startup prompt.
class AppUpdateDialog extends ConsumerWidget {
  const AppUpdateDialog({super.key});

  static Future<void> present(
    BuildContext context,
    WidgetRef ref, {
    bool forceCheck = false,
  }) async {
    final notifier = ref.read(appUpdateProvider.notifier);
    final current = ref.read(appUpdateProvider);
    if (forceCheck ||
        current.release == null ||
        current.status == AppUpdateStatus.idle ||
        current.status == AppUpdateStatus.failed) {
      await notifier.check(force: true);
    }
    if (!context.mounted) {
      return;
    }

    final next = ref.read(appUpdateProvider);
    if (next.status == AppUpdateStatus.current || next.release == null) {
      // A check that could not reach GitHub says so, and offers to try again.
      // A check that succeeded names both builds — the one installed and the
      // newest published — because "you are on the latest version" is a claim
      // the reader cannot check, and has no way to challenge when they think
      // it is wrong.
      final failed = next.status == AppUpdateStatus.failed;
      final language = Localizations.localeOf(context).languageCode;

      final message =
          failed
              ? context.tr(next.messageKey ?? 'app_update_failed')
              : AppLocalizations.translate(
                language,
                'app_update_current',
                replacements: {
                  'installed':
                      next.currentLabel.isEmpty ? '—' : next.currentLabel,
                  'latest': next.release?.label ?? '—',
                },
              );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: Duration(seconds: failed ? 6 : 6),
            action:
                failed
                    ? SnackBarAction(
                      label: context.tr('retry'),
                      onPressed: () => present(context, ref, forceCheck: true),
                    )
                    : null,
          ),
        );
      return;
    }

    await showDialog<void>(
      context: context,
      // Never dismissible by a tap outside. Once the download starts there is
      // no way to bring the dialog back, and a download nobody can see is one
      // nobody can cancel or tell has finished. Every exit is a button.
      barrierDismissible: false,
      builder: (_) => const AppUpdateDialog(),
    );
  }

  /// "١.٥.٠" — the name people know a version by, in their own digits. The
  /// build number stays in the comparison and out of the sentence: a
  /// seven-digit versionCode means nothing to anyone holding the phone.
  static String versionText(BuildContext context, AppRelease release) =>
      localizeDigits(context, release.versionName);

  /// "٨٦٫٨ ميجابايت" / "86.8 MB".
  static String sizeText(BuildContext context, int bytes) {
    if (bytes <= 0) {
      return '';
    }
    final language = Localizations.localeOf(context).languageCode;
    final megabytes = bytes >= 1000000;
    var value =
        megabytes
            ? (bytes / 1000000).toStringAsFixed(1)
            : '${(bytes / 1000).round()}';
    if (language == 'ar') {
      value = localizeDigits(context, value).replaceAll('.', '٫');
    }
    return AppLocalizations.translate(
      language,
      megabytes ? 'size_mb' : 'size_kb',
      replacements: {'value': value},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateProvider);
    final release = state.release;
    final language = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final busy =
        state.status == AppUpdateStatus.downloading ||
        state.status == AppUpdateStatus.installing;

    // Android's installer takes over at this point and the app is about to be
    // replaced; there is nothing left to cancel.
    final installing = state.status == AppUpdateStatus.installing;
    final percent = state.progress?.percent;

    // Only what the reader can use: which version, how big, and what changed
    // — in the language the app is in. This used to print the version code,
    // the installed build, a note about CPU packages, and then the raw GitHub
    // release body: English in an Arabic dialog, backticks and all.
    final whatsNew = release?.whatsNewIn(language) ?? const <String>[];
    final showVersion =
        release != null &&
        UpdateService.compareVersionNames(
              release.versionName,
              state.currentVersionName,
            ) !=
            0;
    final size = sizeText(context, release?.apkBytes ?? 0);

    return PopScope(
      // The back button is the other way a dialog gets dismissed, and it has
      // to be closed off for the same reason the barrier is.
      canPop: !busy,
      child: AlertDialog(
        title: Text(context.tr('app_update_available_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (release != null && showVersion)
              Text(
                AppLocalizations.translate(
                  language,
                  'app_update_version',
                  replacements: {'version': versionText(context, release)},
                ),
                style: theme.textTheme.bodyMedium,
              ),
            if (size.isNotEmpty)
              Text(
                AppLocalizations.translate(
                  language,
                  'app_update_size',
                  replacements: {'size': size},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (whatsNew.isNotEmpty && !busy) ...[
              const SizedBox(height: 16),
              Text(
                context.tr('app_update_whats_new'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.36,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in whatsNew)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  line,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (busy) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  // Null until the first byte arrives, so the bar is
                  // indeterminate rather than sitting at a false zero.
                  value: percent == null ? null : (percent / 100).clamp(0, 1),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      installing
                          ? context.tr('app_update_installing')
                          : AppLocalizations.translate(
                            language,
                            'app_update_downloading',
                            replacements: {
                              'percent': localizeDigits(
                                context,
                                '${percent ?? 0}',
                              ),
                            },
                          ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (!installing && percent != null && release != null)
                    Text(
                      // Derived from the percent against a size GitHub gave
                      // us, so the megabytes are honest about the total even
                      // though the plugin only reports a percentage.
                      AppLocalizations.translate(
                        language,
                        'app_update_downloaded',
                        replacements: {
                          'done': sizeText(
                            context,
                            (release.apkBytes * percent / 100).round(),
                          ),
                          'total': sizeText(context, release.apkBytes),
                        },
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ],
            if (state.status == AppUpdateStatus.failed) ...[
              const SizedBox(height: 12),
              Text(
                context.tr(state.messageKey ?? 'app_update_failed'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          if (busy && !installing)
            TextButton(
              onPressed: () {
                ref.read(appUpdateProvider.notifier).cancelDownload();
              },
              child: Text(context.tr('cancel')),
            ),
          if (!busy) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('app_update_later')),
            ),
            TextButton(
              onPressed: () async {
                await ref.read(appUpdateProvider.notifier).skip();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(context.tr('app_update_skip')),
            ),
            FilledButton(
              onPressed:
                  !state.canInstall
                      ? null
                      : () => unawaited(
                        ref.read(appUpdateProvider.notifier).download(),
                      ),
              child: Text(context.tr('app_update_now')),
            ),
          ],
        ],
      ),
    );
  }
}
