import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../quran/presentation/providers/quran_audio_provider.dart';
import '../../../quran/presentation/providers/reader_settings_provider.dart';
import '../../domain/ruqyah_passages.dart';

/// The ruqyah, read straight through without stopping.
///
/// The point of this screen is that it does not need touching once it starts:
/// someone reading over a sick person, or over themselves at night, should not
/// have to tap between surahs. So it is one queue, with a repeat count and a
/// verse that lights as it is recited.
class RuqyahPage extends ConsumerStatefulWidget {
  const RuqyahPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RuqyahPage()));
  }

  @override
  ConsumerState<RuqyahPage> createState() => _RuqyahPageState();
}

class _RuqyahPageState extends ConsumerState<RuqyahPage> {
  static const List<int> _repeatChoices = [1, 3, 7, 0];

  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _verseKeys = {};

  /// Reading the longer set as well as the narrated one.
  bool _includeChosen = false;
  int _repeat = 3;
  String? _lastFollowed;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<RuqyahPassage> get _passages =>
      _includeChosen ? RuqyahPassages.all : RuqyahPassages.narrated;

  Future<void> _start() async {
    final verses = RuqyahPassages.versesOf(_passages);
    final code = QuranReciter.verseAudioCode(
      ref.read(readerSettingsProvider).reciterCode,
    );

    await ref
        .read(quranAudioProvider.notifier)
        .playRange(
          verses,
          fromIndex: 0,
          toIndex: verses.length - 1,
          repeatCount: _repeat,
          reciterCode: code,
        );
  }

  /// Bring the verse being recited into view, once per verse.
  void _follow(String? key) {
    if (key == null || key == _lastFollowed) {
      return;
    }
    _lastFollowed = key;

    final target = _verseKeys[key]?.currentContext;
    if (target == null) {
      return;
    }
    Scrollable.ensureVisible(
      target,
      duration: AppMotion.slow,
      curve: AppMotion.enter,
      alignment: 0.3,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final audio = ref.watch(quranAudioProvider);
    final controller = ref.read(quranAudioProvider.notifier);
    final settings = ref.watch(readerSettingsProvider);

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _follow(audio.currentKey),
    );

    return AppScaffold(
      title: 'ruqyah',
      showBack: true,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: AppScaffold.scrollPadding,
              children: [
                _intro(tokens),
                const SizedBox(height: AppSpacing.lg),
                for (final passage in _passages) ...[
                  _passageCard(passage, tokens, audio, settings),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
          _controls(tokens, audio, controller),
        ],
      ),
    );
  }

  Widget _intro(AppTokens tokens) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 20, color: tokens.brand),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.tr('ruqyah'),
                  style: AppTextStyles.display(
                    context,
                    fontSize: 17,
                    color: tokens.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr('ruqyah_note'),
            style: AppTextStyles.caption(context, color: tokens.inkMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _includeChosen,
            onChanged: (value) => setState(() => _includeChosen = value),
            title: Text(
              context.tr('ruqyah_include_chosen'),
              style: AppTextStyles.body(context),
            ),
            subtitle: Text(
              context.tr('ruqyah_include_chosen_desc'),
              style: AppTextStyles.caption(context, color: tokens.inkFaint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passageCard(
    RuqyahPassage passage,
    AppTokens tokens,
    QuranAudioState audio,
    ReaderSettings settings,
  ) {
    final verses = passage.verses;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  passage.titleAr,
                  style: AppTextStyles.display(
                    context,
                    fontSize: 15,
                    color: tokens.brand,
                  ),
                ),
              ),
              // Say which footing each passage stands on, in the list, not in
              // a note at the bottom nobody scrolls to.
              _basisChip(passage.basis, tokens),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final verse in verses)
            Padding(
              key: _verseKeys.putIfAbsent(verse.key, GlobalKey.new),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AnimatedContainer(
                duration: AppMotion.base,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color:
                      audio.currentKey == verse.key
                          ? tokens.gold.withValues(alpha: 0.16)
                          : Colors.transparent,
                  borderRadius: AppRadii.smAll,
                ),
                child: Text(
                  '${verse.text} ﴿${verse.numberInSurah}﴾',
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: settings.font.family,
                    fontSize: settings.fontSize * 0.72,
                    height: settings.lineHeight,
                    color: tokens.ink,
                  ),
                ),
              ),
            ),
          if (passage.noteAr.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              passage.noteAr,
              textDirection: TextDirection.rtl,
              style: AppTextStyles.caption(context, color: tokens.inkFaint),
            ),
          ],
        ],
      ),
    );
  }

  Widget _basisChip(RuqyahBasis basis, AppTokens tokens) {
    final narrated = basis == RuqyahBasis.narrated;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: (narrated ? tokens.brand : tokens.gold).withValues(alpha: 0.14),
        borderRadius: AppRadii.pillAll,
      ),
      child: Text(
        context.tr(narrated ? 'ruqyah_narrated' : 'ruqyah_chosen'),
        style: AppTextStyles.caption(
          context,
          color: narrated ? tokens.brand : tokens.gold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _controls(
    AppTokens tokens,
    QuranAudioState audio,
    QuranAudioController controller,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.lg),
        ),
        boxShadow: AppShadows.lift(tokens.ink),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                context.tr('ruqyah_repeat'),
                style: AppTextStyles.caption(context, color: tokens.inkMuted),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: PillSelector<int>(
                  compact: true,
                  value: _repeat,
                  onChanged: (value) => setState(() => _repeat = value),
                  options: [
                    for (final count in _repeatChoices)
                      PillOption(
                        value: count,
                        label:
                            count == 0
                                ? context.tr('repeat_endless')
                                : '$count×',
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      audio.hasQueue && audio.playing
                          ? controller.toggle
                          : (audio.hasQueue ? controller.toggle : _start),
                  icon: Icon(
                    audio.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 20,
                  ),
                  label: Text(
                    context.tr(audio.playing ? 'pause' : 'ruqyah_start'),
                  ),
                ),
              ),
              if (audio.hasQueue) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: context.tr('stop'),
                  onPressed: controller.stop,
                  icon: Icon(
                    Icons.stop_circle_outlined,
                    color: tokens.inkMuted,
                  ),
                ),
              ],
            ],
          ),
          if (audio.isRepeatingRange)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '${audio.repeatsDone}/${audio.repeatTarget}',
                style: AppTextStyles.caption(context, color: tokens.gold),
              ),
            ),
        ],
      ),
    );
  }
}
