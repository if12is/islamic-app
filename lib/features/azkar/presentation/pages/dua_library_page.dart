import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/models/azkar_models.dart';
import '../../domain/dua_library.dart';
import 'azkar_details_page.dart';

/// The supplications, shelved by the situation you are in.
///
/// Same 136 chapters as the full list — this is a second way in, not a second
/// copy. Someone who knows the chapter name searches; someone who only knows
/// "I am about to travel" browses.
class DuaLibraryPage extends StatelessWidget {
  const DuaLibraryPage({super.key, required this.categories});

  final List<AzkarCategory> categories;

  static const Map<DuaTheme, IconData> _icons = {
    DuaTheme.day: Icons.wb_twilight,
    DuaTheme.prayer: Icons.mosque_outlined,
    DuaTheme.home: Icons.home_outlined,
    DuaTheme.distress: Icons.favorite_outline,
    DuaTheme.family: Icons.child_care_outlined,
    DuaTheme.illness: Icons.healing_outlined,
    DuaTheme.nature: Icons.water_drop_outlined,
    DuaTheme.travel: Icons.flight_takeoff,
    DuaTheme.hajj: Icons.location_on_outlined,
    DuaTheme.manners: Icons.groups_outlined,
    DuaTheme.remembrance: Icons.auto_awesome_outlined,
    DuaTheme.ruqyah: Icons.shield_outlined,
  };

  Map<DuaTheme, List<AzkarCategory>> get _shelves {
    final shelves = <DuaTheme, List<AzkarCategory>>{};
    for (final category in categories) {
      shelves
          .putIfAbsent(DuaLibrary.themeOf(category.id), () => [])
          .add(category);
    }
    return shelves;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final shelves = _shelves;

    return AppScaffold(
      title: 'dua_library',
      showBack: true,
      body: ListView(
        padding: AppScaffold.scrollPadding,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              context.tr('dua_library_desc'),
              style: AppTextStyles.caption(context, color: tokens.inkMuted),
            ),
          ),
          for (final theme in DuaTheme.values)
            if ((shelves[theme] ?? const []).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppListRow(
                  dense: true,
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tokens.brand.withValues(alpha: 0.12),
                      borderRadius: AppRadii.smAll,
                    ),
                    child: Icon(
                      _icons[theme] ?? Icons.auto_awesome,
                      size: 18,
                      color: tokens.brand,
                    ),
                  ),
                  title: context.tr(theme.labelKey),
                  meta: context.tr(theme.descriptionKey),
                  trailingText: '${shelves[theme]!.length}',
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => _DuaShelfPage(
                                theme: theme,
                                categories: shelves[theme]!,
                              ),
                        ),
                      ),
                ),
              ),
        ],
      ),
    );
  }
}

/// One shelf: the chapters on it, in the book's own order.
class _DuaShelfPage extends StatelessWidget {
  const _DuaShelfPage({required this.theme, required this.categories});

  final DuaTheme theme;
  final List<AzkarCategory> categories;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final ordered = [...categories]..sort((a, b) {
      final left = DuaLibrary.chapterOf(a.id) ?? DuaLibrary.chapterCount;
      final right = DuaLibrary.chapterOf(b.id) ?? DuaLibrary.chapterCount;
      return left.compareTo(right);
    });

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        context.tr(theme.labelKey),
        style: AppTextStyles.display(context, fontSize: 18, color: tokens.ink),
      ),
      body: ListView.builder(
        padding: AppScaffold.scrollPadding,
        itemCount: ordered.length,
        itemBuilder: (context, index) {
          final category = ordered[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppListRow(
              dense: true,
              title:
                  context.isAppRtl || category.nameEn.isEmpty
                      ? category.nameAr
                      : category.nameEn,
              meta: '${category.azkar.length} ${context.tr('zekr_word')}',
              trailing: Icon(
                context.isAppRtl
                    ? Icons.keyboard_arrow_left
                    : Icons.keyboard_arrow_right,
                size: 18,
                color: tokens.inkFaint,
              ),
              onTap:
                  category.azkar.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AzkarDetailsPage(category: category),
                        ),
                      ),
            ),
          );
        },
      ),
    );
  }
}
