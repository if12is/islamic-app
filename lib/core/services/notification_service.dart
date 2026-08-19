import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_preferences.dart';
import '../utils/app_logger.dart';
import 'notification_router.dart';

/// The notification categories the app schedules.
///
/// Each one gets its own Android channel so the user can silence, re-tone, or
/// disable a single category from system settings without losing the rest.
enum NotificationKind { prayer, preAdhan, iqama, azkar, dailyAyah, wird, test }

/// A button under a notification.
class NotificationActionSpec {
  const NotificationActionSpec({required this.id, required this.label});

  /// Action id; the payload decides where it lands.
  final String id;
  final String label;
}

/// A fully resolved notification, ready to be handed to the platform.
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.kind,
    required this.time,
    required this.title,
    required this.body,
    this.mode = PrayerAlertMode.notification,
    this.payload,
    this.prayerId = '',
    this.actions = const [],
    this.adhanSoundId = NotificationService.systemAdhanSoundId,
  });

  final int id;
  final NotificationKind kind;
  final DateTime time;
  final String title;
  final String body;

  /// Sound/vibration behaviour. Non-prayer kinds use it too: `silent` during
  /// quiet hours, `notification` otherwise.
  final PrayerAlertMode mode;
  final String? payload;
  final String prayerId;

  /// Buttons shown under the notification.
  final List<NotificationActionSpec> actions;

  /// Which adhan sound to play (prayer notifications in adhan mode).
  final String adhanSoundId;
}

/// An adhan the user can choose for prayer alerts.
class AdhanSound {
  const AdhanSound({
    required this.id,
    required this.rawResource,
    required this.nameKey,
  });

  final String id;

  /// File name (without extension) in `android/app/src/main/res/raw/`.
  final String? rawResource;

  /// Localization key for the display name.
  final String nameKey;
}

/// Runs when a notification action is tapped while the app is not in the
/// foreground. Actions that open a screen are handled by the foreground
/// callback once the app is up, so this only needs to exist.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  // Intentionally empty: every action opens the UI.
}

/// Local notifications: channels, permissions, and exact scheduling.
///
/// This service does not know anything about preferences, prayer calculation,
/// or translations — it schedules what it is given. Building the daily plan is
/// the job of `NotificationScheduler`.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _timeZoneReady = false;

  /// Adhan sounds the user can pick from.
  ///
  /// Everything except [systemAdhanSoundId] needs an audio file in
  /// `android/app/src/main/res/raw/` named after its `rawResource`; add the
  /// file, list its id in [bundledAdhanSoundIds], and it becomes selectable.
  /// Android freezes a channel's sound at creation time, hence one channel per
  /// sound and the version suffix in the ids.
  static const String systemAdhanSoundId = 'system';

  static const List<AdhanSound> adhanSounds = [
    AdhanSound(
      id: systemAdhanSoundId,
      rawResource: null,
      nameKey: 'adhan_sound_system',
    ),
    AdhanSound(
      id: 'makkah',
      rawResource: 'adhan_makkah',
      nameKey: 'adhan_sound_makkah',
    ),
    AdhanSound(
      id: 'madinah',
      rawResource: 'adhan_madinah',
      nameKey: 'adhan_sound_madinah',
    ),
    AdhanSound(
      id: 'alafasy',
      rawResource: 'adhan_alafasy',
      nameKey: 'adhan_sound_alafasy',
    ),
  ];

  /// Ids from [adhanSounds] whose audio file is actually bundled.
  static const Set<String> bundledAdhanSoundIds = <String>{};

  static bool isAdhanSoundAvailable(String id) =>
      id == systemAdhanSoundId || bundledAdhanSoundIds.contains(id);

  static AdhanSound adhanSoundById(String id) => adhanSounds.firstWhere(
    (sound) => sound.id == id && isAdhanSoundAvailable(sound.id),
    orElse: () => adhanSounds.first,
  );

  /// Channel id for an adhan sound; each sound needs its own channel.
  static String adhanChannelFor(String soundId) =>
      soundId == systemAdhanSoundId
          ? channelAdhan
          : '${channelAdhan}_$soundId';

  // Channel ids. Bump the suffix whenever sound/importance changes.
  static const String channelAdhan = 'prayer_adhan_v2';
  static const String channelPrayerAlert = 'prayer_alert_v2';
  static const String channelPrayerVibrate = 'prayer_vibrate_v2';
  static const String channelPrayerSilent = 'prayer_silent_v2';
  static const String channelPreAdhan = 'pre_adhan_v2';
  static const String channelIqama = 'iqama_v2';
  static const String channelAzkar = 'azkar_v2';
  static const String channelDailyAyah = 'daily_ayah_v2';
  static const String channelWird = 'wird_v2';
  static const String channelTest = 'test_alerts_v2';

  static final Int64List _adhanVibration = Int64List.fromList([
    0,
    600,
    300,
    600,
  ]);

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _ensureTimeZone();

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: iOS);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) =>
          NotificationRouter.handle(
            response.payload,
            actionId: response.actionId,
          ),
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    await _createChannels();

    _initialized = true;
    AppLogger.info('Notification service initialized');
  }

  /// Resolve the device time zone so scheduled times survive DST and travel.
  static Future<void> _ensureTimeZone() async {
    if (_timeZoneReady) {
      return;
    }

    tz_data.initializeTimeZones();

    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      AppLogger.info('Notification time zone: ${info.identifier}');
    } catch (e) {
      AppLogger.warning('Falling back to UTC time zone: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    _timeZoneReady = true;
  }

  static Future<void> _createChannels() async {
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (android == null) {
      return;
    }

    final channels = <AndroidNotificationChannel>[
      // One channel per available adhan sound.
      for (final sound in adhanSounds)
        if (isAdhanSoundAvailable(sound.id))
          AndroidNotificationChannel(
            adhanChannelFor(sound.id),
            'Adhan (${sound.id})',
            description: 'Full adhan alert at prayer time',
            importance: Importance.max,
            playSound: true,
            sound: sound.rawResource == null
                ? null
                : RawResourceAndroidNotificationSound(sound.rawResource!),
            enableVibration: true,
            vibrationPattern: _adhanVibration,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
      const AndroidNotificationChannel(
        channelPrayerAlert,
        'Prayer alert',
        description: 'Short notification sound at prayer time',
        importance: Importance.high,
      ),
      const AndroidNotificationChannel(
        channelPrayerVibrate,
        'Prayer vibration',
        description: 'Vibration only at prayer time',
        importance: Importance.high,
        playSound: false,
        enableVibration: true,
      ),
      const AndroidNotificationChannel(
        channelPrayerSilent,
        'Prayer (silent)',
        description: 'Silent prayer notification',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
      const AndroidNotificationChannel(
        channelPreAdhan,
        'Before adhan',
        description: 'Reminder shortly before the adhan',
        importance: Importance.high,
      ),
      const AndroidNotificationChannel(
        channelIqama,
        'Iqama',
        description: 'Reminder after the adhan, at iqama time',
        importance: Importance.high,
      ),
      const AndroidNotificationChannel(
        channelAzkar,
        'Azkar',
        description: 'Morning and evening azkar reminders',
        importance: Importance.defaultImportance,
      ),
      const AndroidNotificationChannel(
        channelDailyAyah,
        'Verse of the day',
        description: 'A daily verse from the Quran',
        importance: Importance.defaultImportance,
      ),
      const AndroidNotificationChannel(
        channelWird,
        'Daily wird',
        description: 'Reminder to read your daily portion',
        importance: Importance.defaultImportance,
      ),
      const AndroidNotificationChannel(
        channelTest,
        'Test alerts',
        description: 'Preview notifications triggered from settings',
        importance: Importance.high,
      ),
    ];

    for (final channel in channels) {
      await android.createNotificationChannel(channel);
    }
  }

  /// Ask for the notification permission (Android 13+, iOS).
  static Future<bool> requestPermissions() async {
    await initialize();

    var granted = true;

    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    final androidGranted = await android?.requestNotificationsPermission();
    if (androidGranted != null) {
      granted = granted && androidGranted;
    }

    final ios =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosGranted != null) {
      granted = granted && iosGranted;
    }

    return granted;
  }

  /// Whether Android will let us schedule to-the-minute alarms.
  static Future<bool> canScheduleExactAlarms() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    await initialize();
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  /// Send the user to the system screen that grants exact alarms.
  static Future<bool> requestExactAlarmPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    await initialize();
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    return await android?.requestExactAlarmsPermission() ?? false;
  }

  /// Schedule a batch, replacing everything scheduled before it.
  ///
  /// Returns how many notifications were actually handed to the platform.
  static Future<int> replaceSchedule(
    List<ScheduledNotification> notifications,
  ) async {
    await initialize();
    await cancelAllScheduled();

    final exact = await canScheduleExactAlarms();
    final scheduleMode =
        exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle;

    var scheduled = 0;
    for (final item in notifications) {
      final ok = await _scheduleOne(item, scheduleMode);
      if (ok) {
        scheduled++;
      }
    }

    AppLogger.info(
      'Scheduled $scheduled notifications (exact alarms: $exact)',
    );
    return scheduled;
  }

  static Future<bool> _scheduleOne(
    ScheduledNotification item,
    AndroidScheduleMode scheduleMode,
  ) async {
    final when = tz.TZDateTime.from(item.time, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) {
      return false;
    }

    try {
      await _plugin.zonedSchedule(
        id: item.id,
        title: item.title,
        body: item.body,
        scheduledDate: when,
        notificationDetails: detailsFor(
          kind: item.kind,
          mode: item.mode,
          body: item.body,
          actions: item.actions,
          adhanSoundId: item.adhanSoundId,
        ),
        androidScheduleMode: scheduleMode,
        payload: item.payload,
      );
      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to schedule notification ${item.id}', e, stack);
      return false;
    }
  }

  /// If the app was started by tapping a notification, open its screen.
  static Future<void> handleLaunchPayload() async {
    await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      NotificationRouter.handle(
        details?.notificationResponse?.payload,
        actionId: details?.notificationResponse?.actionId,
      );
    }
  }

  static Future<void> cancelAllScheduled() async {
    await initialize();
    await _plugin.cancelAll();
  }

  /// How many notifications the platform currently holds for us.
  static Future<int> pendingCount() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  /// Immediate notification, used by the "test" buttons.
  static Future<void> showNow({
    required String title,
    required String body,
    NotificationKind kind = NotificationKind.test,
    PrayerAlertMode mode = PrayerAlertMode.notification,
    int? id,
  }) async {
    await initialize();
    await _plugin.show(
      id: id ?? 9000 + kind.index,
      title: title,
      body: body,
      notificationDetails: detailsFor(kind: kind, mode: mode, body: body),
    );
  }

  /// Kept for backwards compatibility with the settings screen.
  static Future<void> showTestNotification({
    String? title,
    String? body,
  }) async {
    await showNow(
      title: title ?? 'Islamic App',
      body: body ?? 'This is a test notification.',
    );
  }

  static NotificationDetails detailsFor({
    required NotificationKind kind,
    required PrayerAlertMode mode,
    String? body,
    List<NotificationActionSpec> actions = const [],
    String adhanSoundId = systemAdhanSoundId,
  }) {
    final channelId = _channelIdFor(
      kind: kind,
      mode: mode,
      adhanSoundId: adhanSoundId,
    );
    final playSound = mode.playsSound;
    final vibrate = mode == PrayerAlertMode.vibrate ||
        mode == PrayerAlertMode.adhan ||
        mode == PrayerAlertMode.notification;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _channelNameFor(channelId),
        channelDescription: 'Islamic App reminders',
        importance:
            mode == PrayerAlertMode.adhan
                ? Importance.max
                : mode == PrayerAlertMode.silent
                ? Importance.low
                : Importance.high,
        priority:
            mode == PrayerAlertMode.silent ? Priority.low : Priority.high,
        playSound: playSound,
        sound: _adhanResourceFor(
          kind: kind,
          mode: mode,
          adhanSoundId: adhanSoundId,
        ),
        enableVibration: vibrate,
        vibrationPattern:
            mode == PrayerAlertMode.adhan ? _adhanVibration : null,
        silent: mode == PrayerAlertMode.silent,
        category:
            kind == NotificationKind.prayer && mode == PrayerAlertMode.adhan
                ? AndroidNotificationCategory.alarm
                : AndroidNotificationCategory.reminder,
        styleInformation:
            (body != null && body.length > 60)
                ? BigTextStyleInformation(body)
                : null,
        audioAttributesUsage:
            mode == PrayerAlertMode.adhan
                ? AudioAttributesUsage.alarm
                : AudioAttributesUsage.notification,
        actions: actions.isEmpty
            ? null
            : [
                for (final action in actions)
                  AndroidNotificationAction(
                    action.id,
                    action.label,
                    showsUserInterface: true,
                    cancelNotification: true,
                  ),
              ],
      ),
      iOS: DarwinNotificationDetails(
        presentSound: playSound,
        presentBanner: true,
        presentList: true,
      ),
    );
  }

  static RawResourceAndroidNotificationSound? _adhanResourceFor({
    required NotificationKind kind,
    required PrayerAlertMode mode,
    required String adhanSoundId,
  }) {
    if (kind != NotificationKind.prayer || mode != PrayerAlertMode.adhan) {
      return null;
    }
    final sound = adhanSoundById(adhanSoundId);
    final resource = sound.rawResource;
    return resource == null
        ? null
        : RawResourceAndroidNotificationSound(resource);
  }

  static String _channelIdFor({
    required NotificationKind kind,
    required PrayerAlertMode mode,
    String adhanSoundId = systemAdhanSoundId,
  }) {
    switch (kind) {
      case NotificationKind.prayer:
        switch (mode) {
          case PrayerAlertMode.adhan:
            return adhanChannelFor(adhanSoundById(adhanSoundId).id);
          case PrayerAlertMode.notification:
            return channelPrayerAlert;
          case PrayerAlertMode.vibrate:
            return channelPrayerVibrate;
          case PrayerAlertMode.silent:
          case PrayerAlertMode.off:
            return channelPrayerSilent;
        }
      case NotificationKind.preAdhan:
        return channelPreAdhan;
      case NotificationKind.iqama:
        return channelIqama;
      case NotificationKind.azkar:
        return channelAzkar;
      case NotificationKind.dailyAyah:
        return channelDailyAyah;
      case NotificationKind.wird:
        return channelWird;
      case NotificationKind.test:
        return channelTest;
    }
  }

  static String _channelNameFor(String channelId) {
    if (channelId.startsWith(channelAdhan)) {
      return 'Adhan';
    }

    switch (channelId) {
      case channelPrayerAlert:
        return 'Prayer alert';
      case channelPrayerVibrate:
        return 'Prayer vibration';
      case channelPrayerSilent:
        return 'Prayer (silent)';
      case channelPreAdhan:
        return 'Before adhan';
      case channelIqama:
        return 'Iqama';
      case channelAzkar:
        return 'Azkar';
      case channelDailyAyah:
        return 'Verse of the day';
      case channelWird:
        return 'Daily wird';
      default:
        return 'Test alerts';
    }
  }
}
