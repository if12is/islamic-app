import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/app_logger.dart';
import 'notification_service.dart';

/// One thing standing between a scheduled adhan and the user hearing it.
class DeliveryCondition {
  const DeliveryCondition({
    required this.id,
    required this.ok,
    this.detail,
    this.fixable = false,
  });

  final String id;

  /// True when this condition is satisfied. Null when the platform will not
  /// say — reported as unknown rather than guessed at.
  final bool? ok;

  final String? detail;

  /// Whether the app can send the user somewhere to change it.
  final bool fixable;
}

/// Everything that has to be true for a prayer alert to sound on time.
class DeliveryReport {
  const DeliveryReport({
    required this.conditions,
    required this.pending,
    required this.manufacturer,
  });

  final List<DeliveryCondition> conditions;

  /// How many alarms the platform is actually holding for us right now.
  final int pending;

  final String manufacturer;

  bool get allClear => conditions.every((c) => c.ok != false);

  /// Vendors that keep their own kill-list on top of Android's.
  ///
  /// Honor and OnePlus are on it for good reason: both ship a startup manager
  /// that force-stops apps it has not been told to spare, and a force-stopped
  /// app keeps no alarms at all.
  static const Set<String> aggressiveVendors = {
    'xiaomi',
    'redmi',
    'poco',
    'oppo',
    'realme',
    'vivo',
    'iqoo',
    'huawei',
    'honor',
    'hihonor',
    'oneplus',
    'samsung',
    'meizu',
    'tecno',
    'infinix',
    'itel',
    'nothing',
  };

  bool get vendorRestricts =>
      aggressiveVendors.contains(manufacturer.toLowerCase());
}

/// Answers "will the adhan actually sound?" instead of assuming it will.
///
/// Scheduling a notification succeeds long before anything is guaranteed to
/// play: the app can hold a perfectly valid alarm that the system quietly
/// drops because the app is dozing, because exact alarms were refused, or
/// because a vendor's own battery manager force-stopped it overnight. None of
/// that surfaces as an error anywhere — which is why an app that schedules
/// silently can look broken for weeks.
///
/// So this reads the real state back out of the platform, and offers a test
/// that proves delivery rather than describing it.
class DeliveryCheck {
  DeliveryCheck._();

  static const MethodChannel _channel = MethodChannel(
    'islamic_app/adhan_sound',
  );

  /// Notification id for the background test, kept out of the schedule's range.
  static const int testNotificationId = 987654;

  static Future<T?> _invoke<T>(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      return await _channel.invokeMethod<T>(method);
    } catch (e) {
      AppLogger.warning('Delivery check "$method" failed: $e');
      return null;
    }
  }

  static Future<DeliveryReport> run() async {
    final permitted = await NotificationService.areNotificationsEnabled();
    final exact = await NotificationService.canScheduleExactAlarms();
    final battery = await _invoke<bool>('isIgnoringBatteryOptimizations');
    final pending = await NotificationService.pendingCount();
    final manufacturer = await _invoke<String>('deviceManufacturer') ?? '';

    return DeliveryReport(
      manufacturer: manufacturer,
      pending: pending,
      conditions: [
        DeliveryCondition(
          id: 'permission',
          ok: permitted,
          fixable: permitted != true,
        ),
        DeliveryCondition(
          id: 'exact_alarms',
          ok: exact,
          fixable: exact != true,
        ),
        DeliveryCondition(id: 'battery', ok: battery, fixable: battery != true),
        DeliveryCondition(id: 'scheduled', ok: pending > 0, detail: '$pending'),
      ],
    );
  }

  static Future<bool> requestBatteryExemption() async =>
      await _invoke<bool>('requestIgnoreBatteryOptimizations') ?? false;

  static Future<bool> openNotificationSettings() async =>
      await _invoke<bool>('openAppNotificationSettings') ?? false;

  static Future<bool> openAutostartSettings() async =>
      await _invoke<bool>('openAutostartSettings') ?? false;

  /// Schedule a real adhan [delay] from now, on the real channel.
  ///
  /// This is the only honest test. A notification shown immediately proves
  /// nothing — it goes through a different path and the app is in the
  /// foreground, which is exactly the case that always worked. This one is
  /// handed to the alarm manager like every prayer is, so locking the phone
  /// and waiting answers the question the settings screens cannot.
  static Future<bool> scheduleBackgroundTest({
    Duration delay = const Duration(seconds: 20),
  }) async {
    return NotificationService.scheduleDeliveryTest(
      id: testNotificationId,
      at: DateTime.now().add(delay),
    );
  }

  static Future<void> cancelBackgroundTest() =>
      NotificationService.cancelOne(testNotificationId);
}
