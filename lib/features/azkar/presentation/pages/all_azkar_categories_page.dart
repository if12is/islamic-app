import 'package:flutter/material.dart';
import '../../data/models/azkar_models.dart';
import 'azkar_details_page.dart';

class AllAzkarCategoriesPage extends StatefulWidget {
  final List<AzkarCategory> categories;

  const AllAzkarCategoriesPage({Key? key, required this.categories}) : super(key: key);

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

  void _filterCategories(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCategories = widget.categories;
      } else {
        _filteredCategories = widget.categories
            .where((category) =>
                category.nameAr.toLowerCase().contains(query.toLowerCase()))
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
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'تصنيفات الأذكار',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: widget.categories.isEmpty
            ? Center(
                child: Text(
                  'لم يتم العثور على أذكار',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              )
            : Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterCategories,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن ذكر...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF0B4633)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  // Categories Grid
                  Expanded(
                    child: _filteredCategories.isEmpty
                        ? Center(
                            child: Text(
                              'لا توجد نتائج مطابقة للبحث',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
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
                          const SnackBar(content: Text('لا توجد أذكار في هذا القسم حالياً')),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFF0B4633).withOpacity(0.1),
                            radius: 28,
                            child: const Icon(Icons.menu_book, color: Color(0xFF0B4633), size: 28),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            category.nameAr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${category.azkar.length} ذكراً',
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
