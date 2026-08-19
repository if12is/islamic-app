import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/notification_preferences.dart';
import '../../../../core/services/notification_scheduler.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/prayer_calculation_service.dart';
import '../../../../shared/providers/app_providers.dart';

/// One screen that owns every reminder the app can send.
///
/// It shows what is actually queued (not just what is switched on), so the
/// user can tell at a glance whether the next adhan will really arrive.
class NotificationCenterPage extends ConsumerStatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  ConsumerState<NotificationCenterPage> createState() =>
      _NotificationCenterPageState();
}

class _NotificationCenterPageState
    extends ConsumerState<NotificationCenterPage> {
  List<ScheduledNotification> _upcoming = const [];
  bool _permissionGranted = true;
  bool _exactAlarms = true;
  int _pending = 0;
  bool _busy = false;

  static const List<int> _minuteChoices = [0, 5, 10, 15, 20, 30];
  static const List<int> _azkarOffsets = [0, 15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshStatus());
  }

  Future<void> _refreshStatus() async {
    final exact = await NotificationService.canScheduleExactAlarms();
    final pending = await NotificationService.pendingCount();
    final plan = await NotificationScheduler.preview(
      overrides: ref.read(notificationPreferencesProvider),
      maxItems: 40,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _exactAlarms = exact;
      _pending = pending;
      _upcoming = plan;
    });
  }

  Future<void> _apply(Future<ScheduleResult> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      await _refreshStatus();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _enableMaster(bool enabled) async {
    if (enabled) {
      final granted = await NotificationService.requestPermissions();
      if (!mounted) {
        return;
      }
      setState(() => _permissionGranted = granted);
      if (!granted) {
        _toast(context.tr('notifications_permission_denied'));
        return;
      }
    }

    await _apply(
      () => ref
          .read(notificationPreferencesProvider.notifier)
          .setMasterEnabled(enabled),
    );

    if (!mounted) {
      return;
    }
    _toast(
      enabled
          ? context.tr('notifications_enabled_body')
          : context.tr('notifications_disabled'),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('notification_center')),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _statusCard(prefs),
            const SizedBox(height: 16),
            _prayerModesCard(prefs),
            const SizedBox(height: 16),
            _adhanSoundCard(prefs),
            const SizedBox(height: 16),
            _timingCard(prefs),
            const SizedBox(height: 16),
            _azkarCard(prefs),
            const SizedBox(height: 16),
            _dailyCard(prefs),
            const SizedBox(height: 16),
            _quietHoursCard(prefs),
            const SizedBox(height: 16),
            _upcomingCard(),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, IconData? icon, String? subtitle, required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: colorScheme.secondary, size: 22),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
      ),
    );
  }

  Widget _statusCard(NotificationPreferences prefs) {
    final colorScheme = Theme.of(context).colorScheme;
    final next = _upcoming.isEmpty ? null : _upcoming.first;

    return _card(
      title: context.tr('notification_center'),
      icon: Icons.notifications_active,
      subtitle: context.tr('notification_center_desc'),
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.masterEnabled,
          onChanged: _busy ? null : _enableMaster,
          title: Text(context.tr('notif_master')),
          subtitle: Text(context.tr('notif_master_desc')),
        ),
        const Divider(height: 24),
        _statusRow(
          icon: prefs.masterEnabled && _pending > 0
              ? Icons.check_circle
              : Icons.schedule,
          color: prefs.masterEnabled && _pending > 0
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
          text: AppLocalizations.translate(
            Localizations.localeOf(context).languageCode,
            'notif_scheduled_count',
            replacements: {'count': _pending.toString()},
          ),
        ),
        _statusRow(
          icon: next != null ? Icons.notifications : Icons.notifications_off,
          color: colorScheme.onSurfaceVariant,
          text: next == null
              ? context.tr('notif_none_scheduled')
              : '${next.title} · ${_formatWhen(next.time)}',
        ),
        if (!_exactAlarms)
          _statusRow(
            icon: Icons.warning_amber_rounded,
            color: colorScheme.error,
            text: context.tr('notif_exact_alarms_missing'),
          ),
        if (!_permissionGranted)
          _statusRow(
            icon: Icons.block,
            color: colorScheme.error,
            text: context.tr('notifications_permission_denied'),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _busy
                  ? null
                  : () => _apply(
                      () => ref
                          .read(notificationPreferencesProvider.notifier)
                          .reschedule(),
                    ),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.tr('notif_reschedule')),
            ),
            if (!_exactAlarms)
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () async {
                        await NotificationService.requestExactAlarmPermission();
                        await _refreshStatus();
                      },
                icon: const Icon(Icons.alarm_on, size: 18),
                label: Text(context.tr('notif_allow_exact_alarms')),
              ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      await NotificationService.showNow(
                        title: context.tr('adhan_notifications'),
                        body: context.tr('test_notification_sent'),
                      );
                      if (mounted) {
                        _toast(context.tr('test_notification_sent'));
                      }
                    },
              icon: const Icon(Icons.send, size: 18),
              label: Text(context.tr('send_test')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _prayerModesCard(NotificationPreferences prefs) {
    return _card(
      title: context.tr('prayer_alerts'),
      icon: Icons.mosque,
      subtitle: context.tr('prayer_alerts_desc'),
      children: [
        for (final prayerId in PrayerIds.obligatory)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _prayerIcon(prayerId),
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(context.tr(prayerId))),
                _modeMenu(prefs, prayerId),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final mode in [PrayerAlertMode.adhan, PrayerAlertMode.off])
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _apply(
                        () => ref
                            .read(notificationPreferencesProvider.notifier)
                            .setAllPrayers(mode),
                      ),
                child: Text(
                  '${context.tr('apply_to_all')}: ${_modeLabel(mode)}',
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _modeMenu(NotificationPreferences prefs, String prayerId) {
    final current = prefs.modeFor(prayerId);
    return MenuAnchor(
      builder: (context, controller, child) {
        return FilledButton.tonalIcon(
          onPressed: _busy
              ? null
              : () =>
                  controller.isOpen ? controller.close() : controller.open(),
          icon: Icon(_modeIcon(current), size: 18),
          label: Text(_modeLabel(current)),
        );
      },
      menuChildren: [
        for (final mode in PrayerAlertMode.values)
          MenuItemButton(
            leadingIcon: Icon(_modeIcon(mode), size: 18),
            onPressed: () => _apply(
              () => ref
                  .read(notificationPreferencesProvider.notifier)
                  .setPrayerMode(prayerId, mode),
            ),
            child: Text(_modeLabel(mode)),
          ),
      ],
    );
  }

  /// Which adhan plays. Sounds without a bundled audio file are listed but
  /// disabled, so it is obvious what is missing rather than silently absent.
  Widget _adhanSoundCard(NotificationPreferences prefs) {
    final missing = NotificationService.adhanSounds
        .where((sound) => !NotificationService.isAdhanSoundAvailable(sound.id))
        .toList();

    return _card(
      title: context.tr('adhan_sound'),
      icon: Icons.campaign,
      subtitle: context.tr('adhan_sound_desc'),
      children: [
        RadioGroup<String>(
          groupValue: prefs.adhanSoundId,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            _apply(
              () => ref
                  .read(notificationPreferencesProvider.notifier)
                  .update(prefs.copyWith(adhanSoundId: value)),
            );
          },
          child: Column(
            children: [
              for (final sound in NotificationService.adhanSounds)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: sound.id,
                  enabled: NotificationService.isAdhanSoundAvailable(sound.id),
                  title: Text(context.tr(sound.nameKey)),
                  subtitle:
                      NotificationService.isAdhanSoundAvailable(sound.id)
                          ? null
                          : Text(context.tr('adhan_sound_missing')),
                ),
            ],
          ),
        ),
        if (missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.tr('adhan_sound_hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _timingCard(NotificationPreferences prefs) {
    return _card(
      title: context.tr('pre_adhan_reminder'),
      icon: Icons.timer,
      subtitle: context.tr('pre_adhan_desc'),
      children: [
        _minuteChips(
          value: prefs.preAdhanMinutes,
          choices: _minuteChoices,
          onSelected: (value) => _apply(
            () => ref
                .read(notificationPreferencesProvider.notifier)
                .update(prefs.copyWith(preAdhanMinutes: value)),
          ),
        ),
        const Divider(height: 28),
        Text(
          context.tr('iqama_reminder'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('iqama_desc'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _minuteChips(
          value: prefs.iqamaMinutes,
          choices: _minuteChoices,
          onSelected: (value) => _apply(
            () => ref
                .read(notificationPreferencesProvider.notifier)
                .update(prefs.copyWith(iqamaMinutes: value)),
          ),
        ),
      ],
    );
  }

  Widget _azkarCard(NotificationPreferences prefs) {
    return _card(
      title: context.tr('azkar_reminders'),
      icon: Icons.wb_twilight,
      subtitle: context.tr('azkar_reminders_desc'),
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.morningAzkarEnabled,
          onChanged: _busy
              ? null
              : (value) => _apply(
                  () => ref
                      .read(notificationPreferencesProvider.notifier)
                      .update(prefs.copyWith(morningAzkarEnabled: value)),
                ),
          title: Text(context.tr('morning_azkar_reminder')),
          subtitle: Text(context.tr('offset_after_fajr')),
        ),
        if (prefs.morningAzkarEnabled)
          _minuteChips(
            value: prefs.morningAzkarOffsetMinutes,
            choices: _azkarOffsets,
            onSelected: (value) => _apply(
              () => ref
                  .read(notificationPreferencesProvider.notifier)
                  .update(prefs.copyWith(morningAzkarOffsetMinutes: value)),
            ),
          ),
        const Divider(height: 24),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.eveningAzkarEnabled,
          onChanged: _busy
              ? null
              : (value) => _apply(
                  () => ref
                      .read(notificationPreferencesProvider.notifier)
                      .update(prefs.copyWith(eveningAzkarEnabled: value)),
                ),
          title: Text(context.tr('evening_azkar_reminder')),
          subtitle: Text(context.tr('offset_after_asr')),
        ),
        if (prefs.eveningAzkarEnabled)
          _minuteChips(
            value: prefs.eveningAzkarOffsetMinutes,
            choices: _azkarOffsets,
            onSelected: (value) => _apply(
              () => ref
                  .read(notificationPreferencesProvider.notifier)
                  .update(prefs.copyWith(eveningAzkarOffsetMinutes: value)),
            ),
          ),
      ],
    );
  }

  Widget _dailyCard(NotificationPreferences prefs) {
    return _card(
      title: context.tr('daily_reminders'),
      icon: Icons.auto_stories,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.dailyAyahEnabled,
          onChanged: _busy
              ? null
              : (value) => _apply(
                  () => ref
                      .read(notificationPreferencesProvider.notifier)
                      .update(prefs.copyWith(dailyAyahEnabled: value)),
                ),
          title: Text(context.tr('daily_ayah_reminder')),
          subtitle: Text(
            _formatHourMinute(prefs.dailyAyahHour, prefs.dailyAyahMinute),
          ),
        ),
        if (prefs.dailyAyahEnabled)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => _pickTime(
                      hour: prefs.dailyAyahHour,
                      minute: prefs.dailyAyahMinute,
                      onPicked: (hour, minute) => _apply(
                        () => ref
                            .read(notificationPreferencesProvider.notifier)
                            .update(
                              prefs.copyWith(
                                dailyAyahHour: hour,
                                dailyAyahMinute: minute,
                              ),
                            ),
                      ),
                    ),
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(context.tr('change_time')),
            ),
          ),
        const Divider(height: 24),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.wirdEnabled,
          onChanged: _busy
              ? null
              : (value) => _apply(
                  () => ref
                      .read(notificationPreferencesProvider.notifier)
                      .update(prefs.copyWith(wirdEnabled: value)),
                ),
          title: Text(context.tr('wird_reminder')),
          subtitle: Text(_formatHourMinute(prefs.wirdHour, prefs.wirdMinute)),
        ),
        if (prefs.wirdEnabled)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => _pickTime(
                      hour: prefs.wirdHour,
                      minute: prefs.wirdMinute,
                      onPicked: (hour, minute) => _apply(
                        () => ref
                            .read(notificationPreferencesProvider.notifier)
                            .update(
                              prefs.copyWith(
                                wirdHour: hour,
                                wirdMinute: minute,
                              ),
                            ),
                      ),
                    ),
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(context.tr('change_time')),
            ),
          ),
      ],
    );
  }

  Widget _quietHoursCard(NotificationPreferences prefs) {
    return _card(
      title: context.tr('quiet_hours'),
      icon: Icons.bedtime,
      subtitle: context.tr('quiet_hours_desc'),
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.quietHoursEnabled,
          onChanged: _busy
              ? null
              : (value) => _apply(
                  () => ref
                      .read(notificationPreferencesProvider.notifier)
                      .update(prefs.copyWith(quietHoursEnabled: value)),
                ),
          title: Text(context.tr('quiet_hours')),
          subtitle: Text(
            '${_formatHourMinute(prefs.quietStartHour, 0)}'
            ' — ${_formatHourMinute(prefs.quietEndHour, 0)}',
          ),
        ),
        if (prefs.quietHoursEnabled)
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _pickTime(
                    hour: prefs.quietStartHour,
                    minute: 0,
                    onPicked: (hour, _) => _apply(
                      () => ref
                          .read(notificationPreferencesProvider.notifier)
                          .update(prefs.copyWith(quietStartHour: hour)),
                    ),
                  ),
                  icon: const Icon(Icons.nights_stay, size: 18),
                  label: Text(context.tr('quiet_from')),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _pickTime(
                    hour: prefs.quietEndHour,
                    minute: 0,
                    onPicked: (hour, _) => _apply(
                      () => ref
                          .read(notificationPreferencesProvider.notifier)
                          .update(prefs.copyWith(quietEndHour: hour)),
                    ),
                  ),
                  icon: const Icon(Icons.wb_sunny, size: 18),
                  label: Text(context.tr('quiet_to')),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _upcomingCard() {
    final items = _upcoming.take(8).toList();
    return _card(
      title: context.tr('upcoming_alerts'),
      icon: Icons.list_alt,
      children: [
        if (items.isEmpty)
          Text(
            context.tr('notif_none_scheduled'),
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(_kindIcon(item.kind), size: 20),
              title: Text(item.title),
              subtitle: Text(_formatWhen(item.time)),
              trailing: Text(
                _kindLabel(item.kind),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
      ],
    );
  }

  Widget _minuteChips({
    required int value,
    required List<int> choices,
    required void Function(int value) onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final choice in choices)
          ChoiceChip(
            selected: value == choice,
            onSelected: _busy ? null : (_) => onSelected(choice),
            label: Text(
              choice == 0
                  ? context.tr('minutes_off')
                  : AppLocalizations.translate(
                      Localizations.localeOf(context).languageCode,
                      'minutes_value',
                      replacements: {'minutes': choice.toString()},
                    ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickTime({
    required int hour,
    required int minute,
    required void Function(int hour, int minute) onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked != null) {
      onPicked(picked.hour, picked.minute);
    }
  }

  String _formatHourMinute(int hour, int minute) {
    final time = DateTime(2000, 1, 1, hour, minute);
    return NotificationPlanner.formatClock(
      time,
      Localizations.localeOf(context).languageCode,
    );
  }

  String _formatWhen(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final difference = day.difference(today).inDays;

    final clock = NotificationPlanner.formatClock(
      time,
      Localizations.localeOf(context).languageCode,
    );

    if (difference == 0) {
      return '${context.tr('today')} · $clock';
    }
    if (difference == 1) {
      return '${context.tr('tomorrow')} · $clock';
    }
    return '${time.day}/${time.month} · $clock';
  }

  String _modeLabel(PrayerAlertMode mode) {
    switch (mode) {
      case PrayerAlertMode.off:
        return context.tr('mode_off');
      case PrayerAlertMode.silent:
        return context.tr('mode_silent');
      case PrayerAlertMode.vibrate:
        return context.tr('mode_vibrate');
      case PrayerAlertMode.notification:
        return context.tr('mode_notification');
      case PrayerAlertMode.adhan:
        return context.tr('mode_adhan');
    }
  }

  IconData _modeIcon(PrayerAlertMode mode) {
    switch (mode) {
      case PrayerAlertMode.off:
        return Icons.notifications_off;
      case PrayerAlertMode.silent:
        return Icons.notifications_none;
      case PrayerAlertMode.vibrate:
        return Icons.vibration;
      case PrayerAlertMode.notification:
        return Icons.notifications_active;
      case PrayerAlertMode.adhan:
        return Icons.campaign;
    }
  }

  IconData _prayerIcon(String prayerId) {
    switch (prayerId) {
      case PrayerIds.fajr:
        return Icons.wb_twilight;
      case PrayerIds.dhuhr:
        return Icons.wb_sunny;
      case PrayerIds.asr:
        return Icons.wb_cloudy;
      case PrayerIds.maghrib:
        return Icons.nights_stay;
      default:
        return Icons.bedtime;
    }
  }

  IconData _kindIcon(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.prayer:
        return Icons.mosque;
      case NotificationKind.preAdhan:
        return Icons.timer;
      case NotificationKind.iqama:
        return Icons.groups;
      case NotificationKind.azkar:
        return Icons.spa;
      case NotificationKind.dailyAyah:
        return Icons.auto_stories;
      case NotificationKind.wird:
        return Icons.menu_book;
      case NotificationKind.test:
        return Icons.science;
    }
  }

  String _kindLabel(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.prayer:
        return context.tr('notif_kind_prayer');
      case NotificationKind.preAdhan:
        return context.tr('notif_kind_pre');
      case NotificationKind.iqama:
        return context.tr('notif_kind_iqama');
      case NotificationKind.azkar:
        return context.tr('notif_kind_azkar');
      case NotificationKind.dailyAyah:
        return context.tr('notif_kind_ayah');
      case NotificationKind.wird:
        return context.tr('notif_kind_wird');
      case NotificationKind.test:
        return context.tr('send_test');
    }
  }
}
