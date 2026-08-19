import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notification service used for prayer reminders and test alerts.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _prayerChannel =
      AndroidNotificationChannel(
    'prayer_reminders',
    'Prayer Reminders',
    description: 'Prayer reminders and daily Islamic notifications',
    importance: Importance.high,
  );

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: iOS);

    await _plugin.initialize(settings: settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_prayerChannel);

    _initialized = true;
  }

  static Future<bool> requestPermissions() async {
    await initialize();

    bool isGranted = true;

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted =
        await androidPlugin?.requestNotificationsPermission();
    if (androidGranted != null) {
      isGranted = isGranted && androidGranted;
    }

    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosGranted != null) {
      isGranted = isGranted && iosGranted;
    }

    return isGranted;
  }

  static Future<void> showTestNotification({
    String? title,
    String? body,
  }) async {
    await initialize();
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title ?? 'Prayer Reminder',
      body: body ?? 'This is a test notification from Islamic App.',
      notificationDetails: _notificationDetails(),
    );
  }

  static Future<void> showPrayerReminder({
    required String prayerName,
    required String prayerTime,
    String? title,
    String? body,
  }) async {
    await initialize();
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title ?? 'وقت الصلاة',
      body: body ?? 'حان وقت صلاة $prayerName ($prayerTime)',
      notificationDetails: _notificationDetails(),
    );
  }

  static NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_reminders',
        'Prayer Reminders',
        channelDescription: 'Prayer reminders and daily Islamic notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }
}
