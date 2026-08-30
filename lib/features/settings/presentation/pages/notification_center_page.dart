import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/models/adhan_sound.dart';
import '../../../../core/models/notification_preferences.dart';
import '../../../../core/services/adhan_preview_player.dart';
import '../../../../core/services/adhan_sound_service.dart';
import '../../../../core/services/delivery_check.dart';
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

  /// What the platform says about background delivery, once asked.
  DeliveryReport? _delivery;
  bool _checking = false;
  DateTime? _testDueAt;
  Timer? _testTimer;

  static const List<int> _minuteChoices = [0, 5, 10, 15, 20, 30];
  static const List<int> _azkarOffsets = [0, 15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    AdhanPreviewPlayer.playing.addListener(_onPreviewChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshStatus());
  }

  void _onPreviewChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    AdhanPreviewPlayer.playing.removeListener(_onPreviewChanged);
    unawaited(AdhanPreviewPlayer.stop());
    _testTimer?.cancel();
    super.dispose();
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

    return AppScaffold(
      showBack: true,
      titleWidget: Text(context.tr('notification_center')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _statusCard(prefs),
          const SizedBox(height: 16),
          _deliveryCard(),
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
          _occasionsCard(prefs),
          const SizedBox(height: 16),
          _quietHoursCard(prefs),
          const SizedBox(height: 16),
          _upcomingCard(),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    IconData? icon,
    String? subtitle,
    required List<Widget> children,
  }) {
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

  /// Does an alert actually arrive when the app is closed?
  ///
  /// Everything above this card describes intent; this one reports fact. The
  /// settings can all be correct and the adhan still never sound, because the
  /// system decides separately whether a sleeping app keeps its alarms.
  Widget _deliveryCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final report = _delivery;

    return _card(
      title: context.tr('delivery_title'),
      icon: Icons.verified_user_outlined,
      subtitle: context.tr('delivery_subtitle'),
      children: [
        if (report == null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: _checking ? null : _runDeliveryCheck,
              icon:
                  _checking
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.play_circle_outline, size: 18),
              label: Text(context.tr('delivery_run')),
            ),
          )
        else ...[
          for (final condition in report.conditions)
            _deliveryRow(condition, colorScheme),
          if (report.vendorRestricts) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.translate(
                      Localizations.localeOf(context).languageCode,
                      'delivery_vendor_warning',
                      replacements: {'brand': report.manufacturer},
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final opened =
                            await DeliveryCheck.openAutostartSettings();
                        if (!opened && mounted) {
                          _say(context.tr('delivery_screen_missing'));
                        }
                      },
                      icon: const Icon(Icons.launch, size: 16),
                      label: Text(context.tr('delivery_open_autostart')),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _testDueAt != null ? null : _startBackgroundTest,
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(
                    _testDueAt == null
                        ? context.tr('delivery_test')
                        : context.tr('delivery_test_waiting'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _checking ? null : _runDeliveryCheck,
                child: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          if (_testDueAt != null) ...[
            const SizedBox(height: 8),
            Text(
              context.tr('delivery_test_hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _deliveryRow(DeliveryCondition condition, ColorScheme colorScheme) {
    final ok = condition.ok;
    final colour =
        ok == true
            ? colorScheme.primary
            : ok == false
            ? colorScheme.error
            : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            ok == true
                ? Icons.check_circle
                : ok == false
                ? Icons.cancel
                : Icons.help_outline,
            size: 18,
            color: colour,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('delivery_${condition.id}'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  condition.detail != null
                      ? AppLocalizations.translate(
                        Localizations.localeOf(context).languageCode,
                        'delivery_${condition.id}_detail',
                        replacements: {'count': condition.detail!},
                      )
                      : context.tr(
                        ok == true
                            ? 'delivery_ok'
                            : ok == false
                            ? 'delivery_blocked'
                            : 'delivery_unknown',
                      ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (condition.fixable)
            TextButton(
              onPressed: () => _fixCondition(condition.id),
              child: Text(context.tr('delivery_fix')),
            ),
        ],
      ),
    );
  }

  Future<void> _runDeliveryCheck() async {
    setState(() => _checking = true);
    final report = await DeliveryCheck.run();
    if (mounted) {
      setState(() {
        _delivery = report;
        _checking = false;
      });
    }
  }

  Future<void> _fixCondition(String id) async {
    switch (id) {
      case 'permission':
        await NotificationService.requestPermissions();
        await DeliveryCheck.openNotificationSettings();
      case 'exact_alarms':
        await NotificationService.requestExactAlarmPermission();
      case 'battery':
        await DeliveryCheck.requestBatteryExemption();
    }
    // The user is coming back from a system screen, so re-read rather than
    // assume the change was made.
    await _runDeliveryCheck();
  }

  /// Schedule a real alert twenty seconds out and ask the user to lock the
  /// phone, which is the only way to observe what actually happens.
  Future<void> _startBackgroundTest() async {
    const delay = Duration(seconds: 20);
    final ok = await DeliveryCheck.scheduleBackgroundTest(delay: delay);
    if (!mounted) {
      return;
    }
    if (!ok) {
      _say(context.tr('delivery_test_failed'));
      return;
    }

    setState(() => _testDueAt = DateTime.now().add(delay));
    _testTimer?.cancel();
    _testTimer = Timer(delay + const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _testDueAt = null);
      }
    });
  }

  void _say(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickSurahHour(NotificationPreferences prefs) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.surahReminderHour, minute: 0),
    );
    if (picked == null || !mounted) {
      return;
    }
    await _apply(
      () => ref
          .read(notificationPreferencesProvider.notifier)
          .update(prefs.copyWith(surahReminderHour: picked.hour)),
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
          icon:
              prefs.masterEnabled && _pending > 0
                  ? Icons.check_circle
                  : Icons.schedule,
          color:
              prefs.masterEnabled && _pending > 0
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
          text:
              next == null
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
              onPressed:
                  _busy
                      ? null
                      : () => _apply(
                        () =>
                            ref
                                .read(notificationPreferencesProvider.notifier)
                                .reschedule(),
                      ),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.tr('notif_reschedule')),
            ),
            if (!_exactAlarms)
              FilledButton.tonalIcon(
                onPressed:
                    _busy
                        ? null
                        : () async {
                          await NotificationService.requestExactAlarmPermission();
                          await _refreshStatus();
                        },
                icon: const Icon(Icons.alarm_on, size: 18),
                label: Text(context.tr('notif_allow_exact_alarms')),
              ),
            OutlinedButton.icon(
              onPressed:
                  _busy
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
        // One switch, not two buttons. It was a pair of outlined buttons
        // reading "all prayers: adhan" and "all prayers: off" — two controls
        // for one two-state decision, sitting at different widths because
        // their labels are different lengths, and neither showing which state
        // was current. A switch is the shape of the question being asked.
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _allPrayersOn(prefs),
          onChanged:
              _busy
                  ? null
                  : (value) => _apply(
                    () => ref
                        .read(notificationPreferencesProvider.notifier)
                        .setAllPrayers(
                          value ? PrayerAlertMode.adhan : PrayerAlertMode.off,
                        ),
                  ),
          title: Text(context.tr('all_prayers_adhan')),
          subtitle: Text(
            context.tr('all_prayers_adhan_desc'),
            style: AppTextStyles.caption(context),
          ),
        ),
      ],
    );
  }

  /// True when every prayer is on the adhan mode, which is what the switch
  /// reports. A mixed set reads as off, because the switch's job is to say
  /// "all of them" and a half-on switch would be a lie either way.
  bool _allPrayersOn(NotificationPreferences prefs) => PrayerIds.obligatory
      .every((id) => prefs.modeFor(id) == PrayerAlertMode.adhan);

  Widget _modeMenu(NotificationPreferences prefs, String prayerId) {
    final current = prefs.modeFor(prayerId);
    return MenuAnchor(
      builder: (context, controller, child) {
        return FilledButton.tonalIcon(
          onPressed:
              _busy
                  ? null
                  : () =>
                      controller.isOpen
                          ? controller.close()
                          : controller.open(),
          icon: Icon(_modeIcon(current), size: 18),
          label: Text(_modeLabel(current)),
        );
      },
      menuChildren: [
        for (final mode in PrayerAlertMode.values)
          MenuItemButton(
            leadingIcon: Icon(_modeIcon(mode), size: 18),
            onPressed:
                () => _apply(
                  () => ref
                      .read(notificationPreferencesProvider.notifier)
                      .setPrayerMode(prayerId, mode),
                ),
            child: Text(_modeLabel(mode)),
          ),
      ],
    );
  }

  /// Which adhan plays: one of the bundled recordings, a file the user
  /// imports, or a sound already on the device. Fajr can differ from the rest.
  Widget _adhanSoundCard(NotificationPreferences prefs) {
    return _card(
      title: context.tr('adhan_sound'),
      icon: Icons.campaign,
      subtitle: context.tr('adhan_sound_desc'),
      children: [
        _soundPicker(
          selection: prefs.adhanSound,
          onSelected:
              (selection) => _apply(
                () => ref
                    .read(notificationPreferencesProvider.notifier)
                    .update(prefs.copyWith(adhanSound: selection)),
              ),
        ),
        const Divider(height: 28),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.fajrAdhanSound != null,
          onChanged:
              _busy
                  ? null
                  : (value) => _apply(
                    () => ref
                        .read(notificationPreferencesProvider.notifier)
                        .update(
                          value
                              ? prefs.copyWith(fajrAdhanSound: prefs.adhanSound)
                              : prefs.copyWith(clearFajrAdhanSound: true),
                        ),
                  ),
          title: Text(context.tr('fajr_adhan_sound')),
          subtitle: Text(context.tr('fajr_adhan_sound_desc')),
        ),
        if (prefs.fajrAdhanSound != null)
          _soundPicker(
            selection: prefs.fajrAdhanSound!,
            onSelected:
                (selection) => _apply(
                  () => ref
                      .read(notificationPreferencesProvider.notifier)
                      .update(prefs.copyWith(fajrAdhanSound: selection)),
                ),
          ),
      ],
    );
  }

  Widget _soundPicker({
    required AdhanSoundSelection selection,
    required void Function(AdhanSoundSelection selection) onSelected,
  }) {
    return Column(
      children: [
        RadioGroup<String>(
          groupValue: selection.id,
          onChanged: (value) {
            if (value == null || value == AdhanSoundSelection.customId) {
              return;
            }
            onSelected(AdhanSoundSelection(id: value));
          },
          child: Column(
            children: [
              for (final sound in NotificationService.adhanSounds)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: sound.id,
                  title: Text(context.tr(sound.nameKey)),
                  subtitle: sound.credit == null ? null : Text(sound.credit!),
                  secondary:
                      sound.rawResource == null
                          ? null
                          : IconButton(
                            tooltip: context.tr('preview_sound'),
                            icon: Icon(
                              AdhanPreviewPlayer.playingId == sound.id
                                  ? Icons.stop_circle_outlined
                                  : Icons.play_circle_outline,
                              color:
                                  AdhanPreviewPlayer.playingId == sound.id
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                            ),
                            onPressed:
                                () => _previewSound(
                                  AdhanSoundSelection(id: sound.id),
                                ),
                          ),
                ),
              if (selection.isCustom)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: AdhanSoundSelection.customId,
                  title: Text(
                    selection.title?.isNotEmpty == true
                        ? selection.title!
                        : context.tr('adhan_sound_custom'),
                  ),
                  subtitle: Text(context.tr('adhan_sound_custom_desc')),
                  secondary: IconButton(
                    tooltip: context.tr('preview_sound'),
                    icon: Icon(
                      AdhanPreviewPlayer.playingId == selection.id
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                      color:
                          AdhanPreviewPlayer.playingId == selection.id
                              ? Theme.of(context).colorScheme.primary
                              : null,
                    ),
                    onPressed: () => _previewSound(selection),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Folded away, because bringing your own adhan is the rare case and it
        // was taking the loudest two controls on the screen: a filled button
        // and an outlined one, side by side at different widths, competing
        // with the list of sounds that is what most people came here to use.
        // Behind one line it is still one tap from being found.
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(
            Icons.library_music_outlined,
            size: 20,
            color: context.tokens.inkMuted,
          ),
          title: Text(
            context.tr('adhan_own_sound'),
            style: AppTextStyles.body(context, fontSize: 14),
          ),
          subtitle: Text(
            context.tr('adhan_own_sound_desc'),
            style: AppTextStyles.caption(context),
          ),
          children: [
            // Both actions are the same weight now. They do the same kind of
            // thing — point at a file — and one being filled and one outlined
            // said there was a right answer and a wrong one.
            OutlinedButton.icon(
              onPressed:
                  _busy
                      ? null
                      : () => _chooseCustomSound(
                        onSelected,
                        AdhanSoundService.importFile,
                      ),
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(context.tr('import_adhan')),
              style: OutlinedButton.styleFrom(
                // Full width, both of them. They were sized by their labels,
                // so two controls doing equally important things sat at two
                // different widths and read as unequal.
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed:
                  _busy
                      ? null
                      : () => _chooseCustomSound(
                        onSelected,
                        AdhanSoundService.pickSystemSound,
                      ),
              icon: const Icon(Icons.library_music_outlined, size: 18),
              label: Text(context.tr('pick_device_sound')),
            ),
          ],
        ),
      ],
    );
  }

  /// Run a picker and store whatever the user chose.
  Future<void> _chooseCustomSound(
    void Function(AdhanSoundSelection selection) onSelected,
    Future<AdhanSoundSelection?> Function() picker,
  ) async {
    try {
      final choice = await picker();
      if (choice == null) {
        return;
      }
      await NotificationService.ensureAdhanChannel(choice);
      onSelected(choice);
      if (mounted) {
        _toast(context.tr('adhan_sound_saved'));
      }
    } on AdhanImportException catch (error) {
      if (!mounted) {
        return;
      }
      _toast(
        error.isUnsupported
            ? context.tr('adhan_import_unsupported')
            : context.tr('adhan_import_failed'),
      );
    }
  }

  /// Fire a one-off notification on that sound's channel — the only honest
  /// preview, because it is exactly what the adhan will sound like.
  /// Play it out loud, here and now.
  ///
  /// This used to post a notification and rely on the channel's sound. That
  /// silently does nothing in the foreground, and nothing at all for a sound
  /// the OS owns — so the file is played directly instead.
  Future<void> _previewSound(AdhanSoundSelection selection) async {
    final result = await AdhanPreviewPlayer.toggle(selection);
    if (!mounted) {
      return;
    }

    final message = switch (result) {
      AdhanPreviewResult.unavailable => context.tr('preview_unavailable'),
      AdhanPreviewResult.failed => context.tr('preview_failed'),
      AdhanPreviewResult.started || AdhanPreviewResult.stopped => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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
          onSelected:
              (value) => _apply(
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
          onSelected:
              (value) => _apply(
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
          onChanged:
              _busy
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
            onSelected:
                (value) => _apply(
                  () => ref
                      .read(notificationPreferencesProvider.notifier)
                      .update(prefs.copyWith(morningAzkarOffsetMinutes: value)),
                ),
          ),
        const Divider(height: 24),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.eveningAzkarEnabled,
          onChanged:
              _busy
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
            onSelected:
                (value) => _apply(
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
          onChanged:
              _busy
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
              onPressed:
                  _busy
                      ? null
                      : () => _pickTime(
                        hour: prefs.dailyAyahHour,
                        minute: prefs.dailyAyahMinute,
                        onPicked:
                            (hour, minute) => _apply(
                              () => ref
                                  .read(
                                    notificationPreferencesProvider.notifier,
                                  )
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
          onChanged:
              _busy
                  ? null
                  : (value) => _apply(
                    () => ref
                        .read(notificationPreferencesProvider.notifier)
                        .update(prefs.copyWith(wirdEnabled: value)),
                  ),
          title: Text(context.tr('wird_reminder')),
          subtitle: Text(_formatHourMinute(prefs.wirdHour, prefs.wirdMinute)),
        ),
        if (prefs.wirdEnabled) ...[
          if (!prefs.wirdAdaptive)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed:
                    _busy
                        ? null
                        : () => _pickTime(
                          hour: prefs.wirdHour,
                          minute: prefs.wirdMinute,
                          onPicked:
                              (hour, minute) => _apply(
                                () => ref
                                    .read(
                                      notificationPreferencesProvider.notifier,
                                    )
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
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: prefs.wirdAdaptive,
            onChanged:
                _busy
                    ? null
                    : (value) => _apply(
                      () => ref
                          .read(notificationPreferencesProvider.notifier)
                          .update(prefs.copyWith(wirdAdaptive: value)),
                    ),
            title: Text(context.tr('wird_adaptive')),
            subtitle: Text(context.tr('wird_adaptive_desc')),
          ),
        ],
      ],
    );
  }

  /// Friday, fasting days, and the Hijri occasions.
  Widget _occasionsCard(NotificationPreferences prefs) {
    return _card(
      title: context.tr('occasion_reminders'),
      icon: Icons.event_available,
      subtitle: context.tr('occasion_reminders_desc'),
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.surahRemindersEnabled,
          onChanged:
              _busy
                  ? null
                  : (value) => _apply(
                    () => ref
                        .read(notificationPreferencesProvider.notifier)
                        .update(prefs.copyWith(surahRemindersEnabled: value)),
                  ),
          title: Text(context.tr('surah_reminders')),
          subtitle: Text(context.tr('surah_reminders_desc')),
        ),
        if (prefs.surahRemindersEnabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: Text(context.tr('reminder_time'))),
                TextButton(
                  onPressed: _busy ? null : () => _pickSurahHour(prefs),
                  child: Text('${prefs.surahReminderHour}:00'),
                ),
              ],
            ),
          ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.fridayRemindersEnabled,
          onChanged:
              _busy
                  ? null
                  : (value) => _apply(
                    () => ref
                        .read(notificationPreferencesProvider.notifier)
                        .update(prefs.copyWith(fridayRemindersEnabled: value)),
                  ),
          title: Text(context.tr('friday_reminder')),
          subtitle: Text(context.tr('friday_reminder_desc')),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.fastingRemindersEnabled,
          onChanged:
              _busy
                  ? null
                  : (value) => _apply(
                    () => ref
                        .read(notificationPreferencesProvider.notifier)
                        .update(prefs.copyWith(fastingRemindersEnabled: value)),
                  ),
          title: Text(context.tr('fasting_reminder')),
          subtitle: Text(context.tr('fasting_reminder_desc')),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.islamicEventsEnabled,
          onChanged:
              _busy
                  ? null
                  : (value) => _apply(
                    () => ref
                        .read(notificationPreferencesProvider.notifier)
                        .update(prefs.copyWith(islamicEventsEnabled: value)),
                  ),
          title: Text(context.tr('islamic_events')),
          subtitle: Text(context.tr('islamic_events_desc')),
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
          onChanged:
              _busy
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
                  onPressed:
                      () => _pickTime(
                        hour: prefs.quietStartHour,
                        minute: 0,
                        onPicked:
                            (hour, _) => _apply(
                              () => ref
                                  .read(
                                    notificationPreferencesProvider.notifier,
                                  )
                                  .update(prefs.copyWith(quietStartHour: hour)),
                            ),
                      ),
                  icon: const Icon(Icons.nights_stay, size: 18),
                  label: Text(context.tr('quiet_from')),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed:
                      () => _pickTime(
                        hour: prefs.quietEndHour,
                        minute: 0,
                        onPicked:
                            (hour, _) => _apply(
                              () => ref
                                  .read(
                                    notificationPreferencesProvider.notifier,
                                  )
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
      case NotificationKind.event:
        return Icons.event;
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
      case NotificationKind.event:
        return context.tr('notif_kind_event');
      case NotificationKind.test:
        return context.tr('send_test');
    }
  }
}
