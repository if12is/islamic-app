import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
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
        _filteredCategories = widget.categories
            .where((category) =>
                category.nameAr.toLowerCase().contains(normalized) ||
                category.nameEn.toLowerCase().contains(normalized))
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
    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            context.tr('azkar_categories'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: widget.categories.isEmpty
            ? Center(
                child: Text(
                  context.tr('no_azkar_found'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              )
            : Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => _filterCategories(context, value),
                      decoration: InputDecoration(
                        hintText: context.tr('search_zekr_hint'),
                        prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  // Categories Grid
                  Expanded(
                    child: _filteredCategories.isEmpty
                        ? Center(
                            child: Text(
                              context.tr('no_matching_results'),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                          )
                        : GridView.builder(
                            padding: EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.0, // Square shape
                            ),
                            itemCount: _filteredCategories.length,
                            itemBuilder: (context, index) {
                              final category = _filteredCategories[index];
                              
                              return GestureDetector(
                    onTap: () {
                      if (category.azkar.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.tr('no_azkar_in_section'))),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AzkarDetailsPage(category: category),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            radius: 28,
                            child: Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary, size: 28),
                          ),
                          SizedBox(height: 16),
                          Text(
                            context.isAppRtl
                                ? category.nameAr
                                : (category.nameEn.isNotEmpty
                                    ? category.nameEn
                                    : category.nameAr),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${category.azkar.length} ${context.tr('zekr_count_unit')}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
