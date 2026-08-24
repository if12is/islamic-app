import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../data/services/quran_local_service.dart';
import '../providers/quran_audio_provider.dart';
import '../providers/reader_settings_provider.dart';

/// Full playback controls: reciter, speed, repetition, and sleep timer.
///
/// The repeat range is expressed in verses of the passage the reader has open,
/// which is how memorisation actually works — "these three verses, ten times".
class PlayerSheet extends ConsumerStatefulWidget {
  const PlayerSheet({super.key, required this.verses});

  /// The passage currently open in the reader.
  final List<QuranVerse> verses;

  static Future<void> show(BuildContext context, List<QuranVerse> verses) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PlayerSheet(verses: verses),
    );
  }

  @override
  ConsumerState<PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends ConsumerState<PlayerSheet> {
  static const List<int> _repeatCounts = [1, 3, 5, 7, 10];
  static const List<int> _sleepMinutes = [15, 30, 45, 60];

  int _fromIndex = 0;
  int _toIndex = 0;
  int _repeatCount = 3;

  @override
  void initState() {
    super.initState();

    final audio = ref.read(quranAudioProvider);
    final current = audio.currentIndex ?? 0;
    _fromIndex = current.clamp(0, _maxIndex);
    _toIndex = (_fromIndex + 2).clamp(_fromIndex, _maxIndex);
  }

  int get _maxIndex => widget.verses.isEmpty ? 0 : widget.verses.length - 1;

  String _verseLabel(int index) {
    if (widget.verses.isEmpty) {
      return '-';
    }
    final verse = widget.verses[index.clamp(0, _maxIndex)];
    return '${verse.surahNameAr} ${verse.numberInSurah}';
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(quranAudioProvider);
    final controller = ref.read(quranAudioProvider.notifier);
    final settings = ref.watch(readerSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: context.appTextDirection,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.95,
        minChildSize: 0.45,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(
                context.tr('player'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),

              // Transport
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 32,
                    tooltip: context.tr('previous'),
                    icon: const Icon(Icons.skip_previous),
                    onPressed: audio.hasQueue ? controller.previous : null,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      if (audio.hasQueue) {
                        controller.toggle();
                        return;
                      }
                      controller.playVerses(
                        widget.verses,
                        startIndex: _fromIndex,
                        reciterCode: settings.reciterCode,
                      );
                    },
                    icon: Icon(
                      audio.playing ? Icons.pause : Icons.play_arrow,
                      size: 20,
                    ),
                    label: Text(
                      audio.playing ? context.tr('pause') : context.tr('play'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 32,
                    tooltip: context.tr('next'),
                    icon: const Icon(Icons.skip_next),
                    onPressed: audio.hasQueue ? controller.next : null,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 28,
                    tooltip: context.tr('stop'),
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: audio.hasQueue ? controller.stop : null,
                  ),
                ],
              ),
              if (audio.currentKey != null)
                Center(
                  child: Text(
                    audio.currentKey!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),

              const Divider(height: 32),

              // Speed
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('playback_speed'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text('${audio.speed.toStringAsFixed(2)}×'),
                ],
              ),
              Slider(
                value: audio.speed.clamp(0.5, 2.0),
                min: 0.5,
                max: 2.0,
                divisions: 6,
                label: '${audio.speed.toStringAsFixed(2)}×',
                onChanged: controller.setSpeed,
              ),

              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: audio.repeatVerse,
                onChanged: controller.setRepeatVerse,
                title: Text(context.tr('repeat_verse')),
                subtitle: Text(context.tr('repeat_verse_desc')),
              ),

              const Divider(height: 32),

              // Repeat range
              Text(
                context.tr('repeat_range'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('repeat_range_desc'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _rangeSlider(
                labelKey: 'range_from',
                value: _fromIndex,
                display: _verseLabel(_fromIndex),
                onChanged:
                    (value) => setState(() {
                      _fromIndex = value;
                      if (_toIndex < _fromIndex) {
                        _toIndex = _fromIndex;
                      }
                    }),
              ),
              _rangeSlider(
                labelKey: 'range_to',
                value: _toIndex,
                display: _verseLabel(_toIndex),
                onChanged:
                    (value) => setState(() {
                      _toIndex = value;
                      if (_fromIndex > _toIndex) {
                        _fromIndex = _toIndex;
                      }
                    }),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('repeat_times'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final count in _repeatCounts)
                    ChoiceChip(
                      selected: _repeatCount == count,
                      onSelected: (_) => setState(() => _repeatCount = count),
                      label: Text('$count×'),
                    ),
                  ChoiceChip(
                    selected: _repeatCount == 0,
                    onSelected: (_) => setState(() => _repeatCount = 0),
                    label: Text(context.tr('repeat_endless')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed:
                      widget.verses.isEmpty
                          ? null
                          : () {
                            controller.playRange(
                              widget.verses,
                              fromIndex: _fromIndex,
                              toIndex: _toIndex,
                              repeatCount: _repeatCount,
                              reciterCode: settings.reciterCode,
                            );
                            Navigator.of(context).pop();
                          },
                  icon: const Icon(Icons.repeat, size: 18),
                  label: Text(context.tr('start_repeat')),
                ),
              ),
              if (audio.isRepeatingRange)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '${audio.rangeLabel} · '
                    '${audio.repeatsDone}/${audio.repeatTarget}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),

              const Divider(height: 32),

              // Sleep timer
              Text(
                context.tr('sleep_timer'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    selected: !audio.hasSleepTimer,
                    onSelected: (_) => controller.setSleepTimer(null),
                    label: Text(context.tr('minutes_off')),
                  ),
                  for (final minutes in _sleepMinutes)
                    ChoiceChip(
                      selected: false,
                      onSelected:
                          (_) => controller.setSleepTimer(
                            Duration(minutes: minutes),
                          ),
                      label: Text(
                        AppLocalizations.translate(
                          Localizations.localeOf(context).languageCode,
                          'minutes_value',
                          replacements: {'minutes': minutes.toString()},
                        ),
                      ),
                    ),
                  ChoiceChip(
                    selected: audio.stopAtEndOfQueue,
                    onSelected: (_) => controller.stopAtEndOfPassage(),
                    label: Text(context.tr('end_of_passage')),
                  ),
                ],
              ),
              if (audio.sleepTimerRemaining != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '${context.tr('sleep_timer')}: '
                    '${audio.sleepTimerRemaining!.inMinutes + 1} '
                    '${context.tr('minutes_short')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),

              const Divider(height: 32),
              DropdownButtonFormField<String>(
                initialValue: QuranReciter.verseAudioCode(settings.reciterCode),
                isExpanded: true,
                decoration: InputDecoration(labelText: context.tr('reciter')),
                items: [
                  for (final reciter in QuranReciter.all)
                    DropdownMenuItem(
                      value: reciter.code,
                      child: Text(
                        context.isAppRtl ? reciter.nameAr : reciter.nameEn,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  ref.read(readerSettingsProvider.notifier).setReciter(value);
                  controller.setReciter(value);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _rangeSlider({
    required String labelKey,
    required int value,
    required String display,
    required void Function(int value) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(context.tr(labelKey))),
            Text(display, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(0, _maxIndex.toDouble()),
          min: 0,
          max: _maxIndex.toDouble().clamp(1, double.infinity),
          divisions: _maxIndex > 0 ? _maxIndex : 1,
          onChanged: (raw) => onChanged(raw.round()),
        ),
      ],
    );
  }
}
