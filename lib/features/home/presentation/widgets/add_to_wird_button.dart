import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/custom_wird.dart';
import '../providers/custom_wird_provider.dart';

/// "Add this to my daily wird" — the same control wherever it appears.
///
/// One widget rather than a button written out at each site, because the point
/// of the thing is that a reader learns it once. It looks the same beside a
/// surah, an azkar chapter and a tasbih phrase, it says what it does in words
/// rather than trusting a glyph, and once something is in the wird it says so
/// instead of offering to add it again.
class AddToWirdButton extends ConsumerWidget {
  const AddToWirdButton({
    super.key,
    required this.kind,
    required this.reference,
    required this.title,
    this.target = 1,
    this.compact = false,
  });

  final WirdKind kind;

  /// What the line points at: a surah number, a chapter id, a juz number.
  final String reference;

  /// What the line will be called in the wird.
  final String title;

  /// How many times a day. One for anything read rather than counted.
  final int target;

  /// Icon only, for a crowded row. The label is kept wherever there is room —
  /// a bare plus beside a surah does not say what it adds it to.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final added = ref.watch(inWirdProvider((kind, reference)));

    Future<void> toggle() async {
      final notifier = ref.read(customWirdProvider.notifier);
      final id = CustomWirdItem.idFor(kind, reference);
      final messenger = ScaffoldMessenger.of(context);
      final message = context.tr(added ? 'wird_removed' : 'wird_added');

      if (added) {
        await notifier.remove(id);
      } else {
        await notifier.add(
          CustomWirdItem(
            id: id,
            kind: kind,
            title: title,
            target: target,
            reference: reference,
          ),
        );
      }

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
    }

    final icon =
        added ? Icons.playlist_add_check_rounded : Icons.playlist_add_rounded;
    final tint = added ? tokens.brand : tokens.inkMuted;

    if (compact) {
      return IconButton(
        tooltip: context.tr(added ? 'wird_in' : 'wird_add'),
        onPressed: toggle,
        icon: Icon(icon, size: 20, color: tint),
      );
    }

    return TextButton.icon(
      onPressed: toggle,
      icon: Icon(icon, size: 18, color: tint),
      label: Text(
        context.tr(added ? 'wird_in' : 'wird_add'),
        style: TextStyle(color: tint, fontWeight: FontWeight.w600),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
