import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/update_service.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateProvider);
    final release = state.release;
    final language = Localizations.localeOf(context).languageCode;
    final busy =
        state.status == AppUpdateStatus.downloading ||
        state.status == AppUpdateStatus.installing;

    // Android's installer takes over at this point and the app is about to be
    // replaced; there is nothing left to cancel.
    final installing = state.status == AppUpdateStatus.installing;
    final percent = state.progress?.percent;

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
            Text(
              AppLocalizations.translate(
                language,
                'app_update_available',
                replacements: {
                  'version': release?.label ?? '',
                  'size': UpdateService.formatBytes(release?.apkBytes ?? 0),
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('app_update_size_hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (state.currentLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.translate(
                  language,
                  'app_update_installed',
                  replacements: {'version': state.currentLabel},
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if ((release?.notes ?? '').isNotEmpty && !busy) ...[
              const SizedBox(height: 12),
              Text(
                release!.notes,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
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
                            replacements: {'percent': '${percent ?? 0}'},
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
                          'done': UpdateService.formatBytes(
                            (release.apkBytes * percent / 100).round(),
                          ),
                          'total': UpdateService.formatBytes(release.apkBytes),
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
