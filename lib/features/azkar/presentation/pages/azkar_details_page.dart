import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../data/azkar_progress_store.dart';
import '../../data/models/azkar_models.dart';

class AzkarDetailsPage extends StatefulWidget {
  final AzkarCategory category;

  const AzkarDetailsPage({super.key, required this.category});

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
    AzkarProgressStore.markOpened(widget.category.id);
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
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CustomLoader()),
      );
    }
    
    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).textTheme.bodyLarge!.color!),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            context.isAppRtl
                ? widget.category.nameAr
                : (widget.category.nameEn.isNotEmpty
                    ? widget.category.nameEn
                    : widget.category.nameAr),
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge!.color!,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Theme.of(context).textTheme.bodyLarge!.color!),
              onPressed: _resetAll,
              tooltip: context.tr('reset_all'),
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
                  color: isDone ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDone ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      (context.isAppRtl
                              ? zekr.textAr
                              : (zekr.textEn.isNotEmpty ? zekr.textEn : zekr.textAr))
                          .replaceAll(RegExp(r'[\[\]{}()]'), ''),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.6,
                        color: Theme.of(context).textTheme.bodyLarge!.color!,
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
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${context.tr('repeat_label')}: ${zekr.targetCount}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        // Right: Interactive Progress Circle
                        Row(
                          children: [
                            if (currentCount > 0)
                              IconButton(
                                icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
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
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDone ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                    ),
                                    strokeWidth: 4,
                                  ),
                                ),
                                isDone
                                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                                    : Text(
                                        '$currentCount',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Theme.of(context).textTheme.bodyLarge!.color!,
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
