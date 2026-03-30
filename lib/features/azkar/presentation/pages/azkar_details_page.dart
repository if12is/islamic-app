import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../data/models/azkar_models.dart';

class AzkarDetailsPage extends StatefulWidget {
  final AzkarCategory category;

  const AzkarDetailsPage({Key? key, required this.category}) : super(key: key);

  @override
  State<AzkarDetailsPage> createState() => _AzkarDetailsPageState();
}

class _AzkarDetailsPageState extends State<AzkarDetailsPage> {
  Map<int, int> _counts = {};
  bool _isLoading = true;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initAndLoadProgress();
  }

  String get _currentSessionKey {
    final now = DateTime.now();
    // Use AM/PM split to automatically reset 'Morning/Evening' combinations 
    // at noon and midnight respectively.
    final bool isAM = now.hour < 12;
    return '${now.year}-${now.month}-${now.day}_${isAM ? "AM" : "PM"}';
  }

  Future<void> _initAndLoadProgress() async {
    _prefs = await SharedPreferences.getInstance();
    
    final categoryId = widget.category.id;
    final savedSession = _prefs!.getString('azkar_session_$categoryId');
    final currentSession = _currentSessionKey;

    if (savedSession == currentSession) {
      // Same period, load saved counts
      final savedCountsStr = _prefs!.getString('azkar_counts_$categoryId');
      if (savedCountsStr != null) {
        try {
          final Map<String, dynamic> decoded = json.decode(savedCountsStr);
          final Map<int, int> loadedCounts = {};
          decoded.forEach((key, value) {
            loadedCounts[int.parse(key)] = value as int;
          });
          setState(() {
            _counts = loadedCounts;
          });
        } catch (e) {
          // Fallback to empty if parse fails
          _counts = {};
        }
      }
    } else {
      // New period, start fresh & save new session
      _counts = {};
      await _saveProgressData(); // Initial save avoids overwriting with old data later
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveProgressData() async {
    if (_prefs == null) return;
    
    final categoryId = widget.category.id;
    final currentSession = _currentSessionKey;
    
    await _prefs!.setString('azkar_session_$categoryId', currentSession);
    
    final stringKeyedMap = _counts.map((key, value) => MapEntry(key.toString(), value));
    await _prefs!.setString('azkar_counts_$categoryId', json.encode(stringKeyedMap));
  }

  void _increment(ZekrItem zekr) {
    if ((_counts[zekr.id] ?? 0) < zekr.targetCount) {
      HapticFeedback.lightImpact();
      setState(() {
        _counts[zekr.id] = (_counts[zekr.id] ?? 0) + 1;
      });
      _saveProgressData();
    }
  }

  void _reset(ZekrItem zekr) {
    HapticFeedback.mediumImpact();
    setState(() {
      _counts[zekr.id] = 0;
    });
    _saveProgressData();
  }

  void _resetAll() {
    HapticFeedback.heavyImpact();
    setState(() {
      _counts.clear();
    });
    _saveProgressData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CustomLoader()),
      );
    }
    
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
          title: Text(
            widget.category.nameAr,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black87),
              onPressed: _resetAll,
              tooltip: 'إعادة تعيين الكل',
            )
          ],
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: widget.category.azkar.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final zekr = widget.category.azkar[index];
            final currentCount = _counts[zekr.id] ?? 0;
            final isDone = currentCount >= zekr.targetCount;

            return GestureDetector(
              onTap: () => _increment(zekr),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFFE8F5E9) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDone ? Colors.green.withOpacity(0.5) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      zekr.textAr.replaceAll(RegExp(r'[\[\]{}()]'), ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Target count info
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6D167).withOpacity(0.2), // Gold tinted
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'التكرار: ${zekr.targetCount}',
                            style: const TextStyle(
                              color: Color(0xFF0B4633), // Dark Green
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        // Right: Interactive Progress Circle
                        Row(
                          children: [
                            if (currentCount > 0)
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.grey, size: 20),
                                onPressed: () => _reset(zekr),
                              ),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: CircularProgressIndicator(
                                    value: zekr.targetCount == 0 ? 1.0 : (currentCount / zekr.targetCount),
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDone ? Colors.green : const Color(0xFF0B4633), // Dark green or Green
                                    ),
                                    strokeWidth: 4,
                                  ),
                                ),
                                isDone
                                    ? const Icon(Icons.check, color: Colors.green)
                                    : Text(
                                        '$currentCount',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF0B4633),
                                        ),
                                      ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
