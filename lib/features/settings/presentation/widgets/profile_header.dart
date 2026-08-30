import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../shared/providers/app_providers.dart';

/// The name and place at the top of Settings.
///
/// Two things were wrong with what stood here. The avatar was a 100 px block
/// filled with `tokens.ink` — a near-black square on a cream page, the darkest
/// object in the app and easily its loudest, for a picture nobody has set. And
/// the empty state printed "أحمد عبدالله" and "القاهرة، مصر" as if they were
/// the reader's own details: a placeholder that reads as data, which is worse
/// than a blank because a reader has no way to know it is not theirs.
///
/// Now it is a quiet monogram in the brand's own wash, sized to sit beside the
/// two lines rather than tower over them, and an unset name says what to do
/// about it.
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key, required this.onEdit});

  final VoidCallback onEdit;

  static const double _avatar = 64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final profile = ref.watch(userProfileProvider);
    final hasName = profile.name.trim().isNotEmpty;
    final place = ref.watch(locationLabelProvider).value ?? profile.location;

    return Material(
      color: tokens.surface,
      borderRadius: AppRadii.lgAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              _Monogram(name: profile.name, size: _avatar),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasName
                          ? profile.name
                          : context.tr('profile_name_prompt'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.display(
                        context,
                        fontSize: 18,
                        // An unset name is an invitation, not a value, so it
                        // is set in the colour the app uses for hints.
                        color: hasName ? tokens.ink : tokens.inkFaint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place.isEmpty ? context.tr('location_unknown') : place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.edit_outlined, size: 19, color: tokens.brand),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reader's initial, or a person glyph until there is one.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final initial = _initialOf(name);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // The same 0.11 brand wash every icon tile in the app sits on, so the
        // avatar belongs to the set rather than being the one dark block on
        // the page.
        color: tokens.brand.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child:
          initial.isEmpty
              ? Icon(
                Icons.person_outline_rounded,
                size: size * 0.44,
                color: tokens.brand,
              )
              : Text(
                initial,
                style: AppTextStyles.display(
                  context,
                  fontSize: size * 0.4,
                  color: tokens.brand,
                ),
              ),
    );
  }

  /// The first letter of the first word that has one.
  ///
  /// Arabic has no case, so nothing is upper-cased; doing so would only mangle
  /// a Latin name typed in lower case while leaving an Arabic one alone.
  static String _initialOf(String name) {
    for (final word in name.trim().split(RegExp(r'\s+'))) {
      if (word.isNotEmpty) {
        return word.characters.first;
      }
    }
    return '';
  }
}
