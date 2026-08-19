import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../domain/entities/prayer_times_entity.dart';
import '../providers/prayer_times_providers.dart';
import '../widgets/qibla_compass.dart';

class _PrayerSlot {
  final String id;
  final PrayerEntity prayer;
  final DateTime time;

  const _PrayerSlot({
    required this.id,
    required this.prayer,
    required this.time,
  });
}

class PrayerTimesPage extends ConsumerStatefulWidget {
  const PrayerTimesPage({super.key});

  @override
  ConsumerState<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends ConsumerState<PrayerTimesPage> {
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _toArabicDigits(String input) {
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var output = input;
    for (var i = 0; i < western.length; i++) {
      output = output.replaceAll(western[i], arabic[i]);
    }
    return output;
  }

  String _localizeDigits(BuildContext context, String input) {
    return context.isAppRtl ? _toArabicDigits(input) : input;
  }

  String _normalizeToWesternDigits(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var output = input;
    for (var i = 0; i < arabic.length; i++) {
      output = output.replaceAll(arabic[i], '$i');
    }
    return output;
  }

  DateTime _parseTime(String timeStr) {
    try {
      final clean = _normalizeToWesternDigits(timeStr.split(' ').first);
      final parts = clean.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _canonicalPrayerId(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('fajr')) return 'fajr';
    if (lower.contains('dhuhr')) return 'dhuhr';
    if (lower.contains('asr')) return 'asr';
    if (lower.contains('maghrib')) return 'maghrib';
    if (lower.contains('isha')) return 'isha';
    return '';
  }

  String _getPrayerDisplayName(BuildContext context, String name) {
    final lower = name.toLowerCase();
    if (lower.contains('fajr')) return context.tr('fajr');
    if (lower.contains('dhuhr')) return context.tr('dhuhr');
    if (lower.contains('asr')) return context.tr('asr');
    if (lower.contains('maghrib')) return context.tr('maghrib');
    if (lower.contains('isha')) return context.tr('isha');
    return name;
  }

  IconData _getIconForPrayer(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('fajr')) return Icons.wb_twilight;
    if (lower.contains('dhuhr')) return Icons.wb_sunny_outlined;
    if (lower.contains('asr')) return Icons.light_mode_outlined;
    if (lower.contains('maghrib')) return Icons.nightlight_round;
    if (lower.contains('isha')) return Icons.nightlight_outlined;
    return Icons.access_time;
  }

  String _formatTime12H(BuildContext context, DateTime time) {
    var hour = time.hour;
    final minute = time.minute;
    final ampm = hour >= 12 ? context.tr('pm_short') : context.tr('am_short');
    hour = hour % 12;
    if (hour == 0) {
      hour = 12;
    }
    final formatted =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
    return _localizeDigits(context, formatted);
  }

  double _calculateQiblaBearing({
    required double latitude,
    required double longitude,
  }) {
    final userLat = latitude * (math.pi / 180);
    final userLon = longitude * (math.pi / 180);
    final kaabaLat = AppConstants.kaabaLatitude * (math.pi / 180);
    final kaabaLon = AppConstants.kaabaLongitude * (math.pi / 180);

    final deltaLon = kaabaLon - userLon;
    final y = math.sin(deltaLon);
    final x =
        math.cos(userLat) * math.tan(kaabaLat) -
        math.sin(userLat) * math.cos(deltaLon);

    final bearing = math.atan2(y, x) * (180 / math.pi);
    return (bearing + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(currentLocationCoordinatesProvider);
    final selectedMethod = ref.watch(prayerMethodProvider);
    final completedPrayers = ref.watch(dailyPrayerCompletionProvider);

    const fallbackCoordinates = UserCoordinates(
      latitude: 31.0345728,
      longitude: 30.4676864,
    );

    final coordinates = locationAsync.maybeWhen(
      data: (value) => value,
      orElse: () => fallbackCoordinates,
    );

    final method = ref
        .watch(sharedPreferencesProvider)
        .maybeWhen(
          data:
              (prefs) =>
                  prefs.getInt(AppConstants.prayerMethodKey) ?? selectedMethod,
          orElse: () => selectedMethod,
        );

    final params = PrayerTimesParams(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      method: method,
    );

    final prayerTimesAsync = ref.watch(prayerTimesProvider(params));
    final qiblaBearing = _calculateQiblaBearing(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    );

    Future<void> refreshAll() async {
      ref.invalidate(currentLocationCoordinatesProvider);
      ref.invalidate(prayerTimesProvider(params));
      await ref.read(dailyPrayerCompletionProvider.notifier).reloadToday();
    }

    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).textTheme.bodyLarge!.color!,
              size: 28,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            context.tr('qibla_direction'),
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge!.color!,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: false,
          actions: const [SizedBox(width: 12)],
        ),
        body: prayerTimesAsync.when(
          loading: () => const Center(child: CustomLoader()),
          error:
              (_, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: Theme.of(context).colorScheme.error,
                        size: 48,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.tr('unable_load_prayer_times_connection'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(currentLocationCoordinatesProvider);
                          ref.invalidate(prayerTimesProvider(params));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          context.tr('retry'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          data: (entity) {
            final order = {
              'fajr': 0,
              'dhuhr': 1,
              'asr': 2,
              'maghrib': 3,
              'isha': 4,
            };

            final slots =
                entity.prayers
                    .where(
                      (p) => [
                        'fajr',
                        'dhuhr',
                        'asr',
                        'maghrib',
                        'isha',
                      ].any((valid) => p.name.toLowerCase().contains(valid)),
                    )
                    .map((prayer) {
                      final id = _canonicalPrayerId(prayer.name);
                      if (id.isEmpty) {
                        return null;
                      }
                      return _PrayerSlot(
                        id: id,
                        prayer: prayer,
                        time: _parseTime(prayer.time),
                      );
                    })
                    .whereType<_PrayerSlot>()
                    .toList()
                  ..sort((a, b) {
                    return (order[a.id] ?? 99).compareTo(order[b.id] ?? 99);
                  });

            _PrayerSlot? currentSlot;
            for (final slot in slots) {
              if (!_currentTime.isBefore(slot.time)) {
                currentSlot = slot;
              } else {
                break;
              }
            }

            if (currentSlot == null && slots.isNotEmpty) {
              currentSlot = slots.last;
            }

            final lat = _localizeDigits(
              context,
              coordinates.latitude.toStringAsFixed(4),
            );
            final lon = _localizeDigits(
              context,
              coordinates.longitude.toStringAsFixed(4),
            );
            final locationText = '${context.tr('location')}: $lat, $lon';

            return RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: refreshAll,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                children: [
                  Center(
                    child: Text(
                      context.tr('qibla_direction'),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).textTheme.bodyLarge!.color!,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      context.tr('qibla_precision_desc'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  QiblaCompass(
                    qiblaBearing: qiblaBearing,
                    alignedText: context.tr('qibla_correct_direction'),
                    rotateText: context.tr('rotate_to_qibla'),
                  ),
                  const SizedBox(height: 56),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        context.tr('prayer_times_today'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).textTheme.bodyLarge!.color!,
                        ),
                      ),
                      Text(
                        _localizeDigits(
                          context,
                          entity.hijriDate.formattedDate,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...slots.map((slot) {
                    final isCurrent = currentSlot?.id == slot.id;
                    final isDone = completedPrayers.contains(slot.id);

                    return _buildPrayerTimeTile(
                      context: context,
                      name: _getPrayerDisplayName(context, slot.prayer.name),
                      time: _formatTime12H(context, slot.time),
                      icon: _getIconForPrayer(slot.prayer.name),
                      isCurrent: isCurrent,
                      isDone: isDone,
                      onToggleDone:
                          () => ref
                              .read(dailyPrayerCompletionProvider.notifier)
                              .togglePrayer(slot.id),
                    );
                  }),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.my_location,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                locationText,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Theme.of(context).textTheme.bodyLarge!.color!,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr('prayer_times_auto_update'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () {
                            ref.invalidate(currentLocationCoordinatesProvider);
                            ref.invalidate(prayerTimesProvider(params));
                          },
                          child: Text(
                            context.tr('change'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPrayerTimeTile({
    required BuildContext context,
    required String name,
    required String time,
    required IconData icon,
    required bool isCurrent,
    required bool isDone,
    required VoidCallback onToggleDone,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isCurrent ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow:
            isCurrent
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isCurrent
                          ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.12)
                          : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isCurrent ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.tr('prayer_label_prefix')} $name',
                    style: TextStyle(
                      color:
                          isCurrent
                              ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      color: isCurrent ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.tr('current_prayer'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              if (isCurrent) const SizedBox(width: 10),
              GestureDetector(
                onTap: onToggleDone,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isDone
                              ? Theme.of(context).colorScheme.secondary
                              : (isCurrent
                                  ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.45)
                                  : Theme.of(context).colorScheme.outline),
                      width: 2,
                    ),
                    color:
                        isDone ? Theme.of(context).colorScheme.secondary : Colors.transparent,
                  ),
                  child:
                      isDone
                          ? Icon(
                            Icons.check,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSecondary,
                          )
                          : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
