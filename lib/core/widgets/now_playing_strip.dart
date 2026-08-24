import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/broadcasts/presentation/pages/broadcasts_page.dart';
import '../../features/broadcasts/presentation/providers/radio_provider.dart';
import '../../features/quran/data/services/quran_local_service.dart';
import '../../features/quran/presentation/pages/now_playing_page.dart';
import '../../features/quran/presentation/pages/surah_reader_page.dart';
import '../../features/quran/presentation/providers/quran_audio_provider.dart';
import '../../features/quran/presentation/providers/surah_audio_provider.dart';
import '../localization/app_localizations.dart';
import '../services/app_audio.dart';
import '../theme/app_text_styles.dart';
import '../theme/design_tokens.dart';

/// Who holds the shared player, as something the widget tree can watch.
///
/// The three controllers each change state when they gain or lose the player,
/// so watching them is usually enough — but only usually. This closes the gap
/// where the owner changes and the losing controller's state happens to come
/// out identical, which would leave the strip naming audio that has stopped.
final audioOwnerProvider = StreamProvider<AudioOwner>(
  (ref) => AppAudio.ownerChanges,
);

/// What is playing, on every screen, with a way back to it.
///
/// Without this the only route back to a running recitation was to remember
/// which screen had started it, or to pull down the notification shade — and a
/// media notification is a poor place to keep the one control someone reaches
/// for most. The strip follows the audio, not the screen: it appears wherever
/// you are as soon as anything is playing and disappears when it stops.
class NowPlayingStrip extends ConsumerWidget {
  const NowPlayingStrip({super.key});

  /// How tall it is, so the shell can leave room for it.
  static const double height = 58;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(audioOwnerProvider);
    final surah = ref.watch(surahAudioProvider);
    final verses = ref.watch(quranAudioProvider);
    final radio = ref.watch(radioProvider);

    final entry = _resolve(context, ref, surah, verses, radio);
    // AnimatedSize rather than a plain conditional: the bar sliding in under
    // the content reads as part of the screen, and appearing instantly reads
    // as a glitch.
    return AnimatedSize(
      duration: AppMotion.base,
      curve: AppMotion.enter,
      alignment: Alignment.bottomCenter,
      child:
          entry == null
              ? const SizedBox(width: double.infinity)
              : _Strip(entry: entry),
    );
  }

  /// Whichever source currently owns the shared player.
  ///
  /// Reading the owner rather than each controller's own `playing` flag is
  /// what keeps two strips from claiming the same audio: only one thing can
  /// hold the player, and it says so.
  _NowPlaying? _resolve(
    BuildContext context,
    WidgetRef ref,
    SurahPlaybackState surah,
    QuranAudioState verses,
    RadioState radio,
  ) {
    switch (AppAudio.owner) {
      case AudioOwner.radio:
        final station = radio.station;
        if (station == null) {
          return null;
        }
        return _NowPlaying(
          icon: Icons.radio_rounded,
          title: station.name,
          subtitle: context.tr(
            radio.connecting ? 'broadcast_connecting' : 'broadcast_live',
          ),
          playing: radio.playing,
          loading: radio.connecting,
          onToggle: ref.read(radioProvider.notifier).toggle,
          onStop: ref.read(radioProvider.notifier).stop,
          onOpen: () => BroadcastsPage.open(context),
        );

      case AudioOwner.surah:
        final number = surah.surahNumber;
        if (number == null) {
          return null;
        }
        final info = QuranLocalService.surahInfo(number);
        return _NowPlaying(
          icon: Icons.menu_book_rounded,
          title: 'سورة ${info.nameAr}',
          subtitle: SurahAudioController.displayNameFor(surah.reciterId),
          playing: surah.playing,
          loading: surah.loading,
          onToggle: ref.read(surahAudioProvider.notifier).toggle,
          onStop: ref.read(surahAudioProvider.notifier).stop,
          onOpen: () => NowPlayingPage.open(context),
        );

      case AudioOwner.verses:
        final key = verses.currentKey;
        if (key == null || !verses.hasQueue) {
          return null;
        }
        final parts = key.split(':');
        final surahNumber = int.tryParse(parts.first);
        final verseNumber = parts.length > 1 ? int.tryParse(parts[1]) : null;
        if (surahNumber == null) {
          return null;
        }
        final info = QuranLocalService.surahInfo(surahNumber);
        return _NowPlaying(
          icon: Icons.graphic_eq_rounded,
          title: 'سورة ${info.nameAr}',
          subtitle:
              verseNumber == null
                  ? ''
                  : '${context.tr('ayah_word')} $verseNumber',
          playing: verses.playing,
          loading: verses.loading,
          onToggle: ref.read(quranAudioProvider.notifier).toggle,
          onStop: ref.read(quranAudioProvider.notifier).stop,
          // Straight to the verse being recited, not the top of the surah.
          onOpen:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => SurahReaderPage(
                        surahNumber: surahNumber,
                        initialVerse: verseNumber,
                      ),
                ),
              ),
        );

      case AudioOwner.adhanPreview:
      case AudioOwner.none:
        return null;
    }
  }
}

/// One line of "this is playing".
class _NowPlaying {
  const _NowPlaying({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.loading,
    required this.onToggle,
    required this.onStop,
    required this.onOpen,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool playing;
  final bool loading;
  final Future<void> Function() onToggle;
  final Future<void> Function() onStop;
  final VoidCallback onOpen;
}

class _Strip extends StatelessWidget {
  const _Strip({required this.entry});

  final _NowPlaying entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Material(
        color: tokens.surfaceRaised,
        borderRadius: AppRadii.pillAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: entry.onOpen,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadii.pillAll,
              border: Border.all(color: tokens.line),
              boxShadow: AppShadows.lift(tokens.ink),
            ),
            child: SizedBox(
              height: NowPlayingStrip.height,
              child: Row(
                children: [
                  const SizedBox(width: AppSpacing.md),
                  Icon(entry.icon, size: 19, color: tokens.brand),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(context, fontSize: 13.5),
                        ),
                        if (entry.subtitle.isNotEmpty)
                          Text(
                            entry.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption(
                              context,
                              color: tokens.inkFaint,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr(entry.playing ? 'pause' : 'play'),
                    onPressed: entry.onToggle,
                    icon:
                        entry.loading
                            ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation(
                                  tokens.brand,
                                ),
                              ),
                            )
                            : Icon(
                              entry.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: tokens.brand,
                            ),
                  ),
                  IconButton(
                    tooltip: context.tr('stop'),
                    onPressed: entry.onStop,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 19,
                      color: tokens.inkFaint,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
