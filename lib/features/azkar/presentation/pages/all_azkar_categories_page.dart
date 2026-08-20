import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../data/models/azkar_models.dart';
import 'azkar_details_page.dart';

class AllAzkarCategoriesPage extends StatefulWidget {
  final List<AzkarCategory> categories;

  const AllAzkarCategoriesPage({super.key, required this.categories});

  @override
  State<AllAzkarCategoriesPage> createState() => _AllAzkarCategoriesPageState();
}

class _AllAzkarCategoriesPageState extends State<AllAzkarCategoriesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<AzkarCategory> _filteredCategories = [];

  @override
  void initState() {
    super.initState();
    _filteredCategories = widget.categories;
  }

  void _filterCategories(BuildContext context, String query) {
    final normalized = query.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCategories = widget.categories;
      } else {
        _filteredCategories =
            widget.categories
                .where(
                  (category) =>
                      category.nameAr.toLowerCase().contains(normalized) ||
                      category.nameEn.toLowerCase().contains(normalized),
                )
                .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'azkar_categories',
      showBack: true,
      body:
          widget.categories.isEmpty
              ? Center(
                child: Text(
                  context.tr('no_azkar_found'),
                  style: AppTextStyles.body(context),
                ),
              )
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.sm,
                      AppSpacing.page,
                      AppSpacing.md,
                    ),
                    child: GlassSearchField(
                      controller: _searchController,
                      hintText: context.tr('search_zekr_hint'),
                      onChanged: (value) => _filterCategories(context, value),
                    ),
                  ),
                  // A list, not a grid: with 136 chapters, scanning titles beats
                  // scanning tiles.
                  Expanded(
                    child:
                        _filteredCategories.isEmpty
                            ? Center(
                              child: Text(
                                context.tr('no_matching_results'),
                                style: AppTextStyles.body(context),
                              ),
                            )
                            : ListView.builder(
                              padding: AppScaffold.scrollPadding,
                              itemCount: _filteredCategories.length,
                              itemBuilder: (context, index) {
                                final category = _filteredCategories[index];

                                return AppListRow(
                                  dense: true,
                                  leading: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: context.tokens.brand.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: AppRadii.smAll,
                                    ),
                                    child: Icon(
                                      Icons.auto_awesome,
                                      size: 18,
                                      color: context.tokens.brand,
                                    ),
                                  ),
                                  title:
                                      context.isAppRtl
                                          ? category.nameAr
                                          : (category.nameEn.isNotEmpty
                                              ? category.nameEn
                                              : category.nameAr),
                                  meta:
                                      '${category.azkar.length} '
                                      '${context.tr('zekr_word')}',
                                  trailing: Icon(
                                    context.isAppRtl
                                        ? Icons.keyboard_arrow_left
                                        : Icons.keyboard_arrow_right,
                                    size: 18,
                                    color: context.tokens.inkFaint,
                                  ),
                                  onTap: () {
                                    if (category.azkar.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.tr('no_azkar_in_section'),
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder:
                                            (_) => AzkarDetailsPage(
                                              category: category,
                                            ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}
