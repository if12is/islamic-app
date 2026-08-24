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
      // It used to report "you are on the latest version", which is a claim
      // the app had no way of making.
      final failed = next.status == AppUpdateStatus.failed;
      final message =
          failed
              ? context.tr(next.messageKey ?? 'app_update_failed')
              : context.tr('app_update_current');

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: Duration(seconds: failed ? 6 : 4),
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
      barrierDismissible: next.status != AppUpdateStatus.downloading,
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

    return AlertDialog(
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
          if ((release?.notes ?? '').isNotEmpty) ...[
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
            LinearProgressIndicator(
              value:
                  state.progress?.percent == null
                      ? null
                      : (state.progress!.percent! / 100).clamp(0, 1),
            ),
            const SizedBox(height: 8),
            Text(
              state.status == AppUpdateStatus.installing
                  ? context.tr('app_update_installing')
                  : AppLocalizations.translate(
                    language,
                    'app_update_downloading',
                    replacements: {
                      'percent': '${state.progress?.percent ?? 0}',
                    },
                  ),
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
        if (!busy)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('app_update_later')),
          ),
        if (!busy)
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
              busy || !state.canInstall
                  ? null
                  : () => unawaited(
                    ref.read(appUpdateProvider.notifier).download(),
                  ),
          child: Text(context.tr('app_update_now')),
        ),
      ],
    );
  }
}
