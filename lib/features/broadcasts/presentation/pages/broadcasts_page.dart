import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/arabic_numerals.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/now_playing_strip.dart';
import '../../data/broadcast_catalogue.dart';
import '../../data/recordings_catalogue.dart';
import '../../domain/broadcast.dart';
import '../../domain/recording.dart';
import '../providers/radio_provider.dart';
import 'live_tv_page.dart';
import 'recording_collection_page.dart';

/// Which list the Broadcasts page is showing. Kept apart from [BroadcastKind]
/// because recordings are not a live stream.
enum _BroadcastShelf { radio, tv, recordings }

/// Live radio and the two Qur'an television channels.
///
/// Radio is audio, so it behaves like a recitation: it keeps playing when the
/// screen closes and shows in the notification. Television is not, so it plays
/// on its own page and stops when that page does — a video running unseen is
/// only a drained battery.
class BroadcastsPage extends ConsumerStatefulWidget {
  const BroadcastsPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BroadcastsPage()));
  }

  @override
  ConsumerState<BroadcastsPage> createState() => _BroadcastsPageState();
}

class _BroadcastsPageState extends ConsumerState<BroadcastsPage> {
  final TextEditingController _search = TextEditingController();
  _BroadcastShelf _shelf = _BroadcastShelf.radio;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final catalogue = ref.watch(broadcastsProvider);
    final radio = ref.watch(radioProvider);

    return AppScaffold(
      title: 'broadcasts',
      showBack: true,
      actions: [
        IconButton(
          tooltip: context.tr('reciter_refresh'),
          icon: Icon(Icons.refresh_rounded, color: tokens.ink, size: 20),
          onPressed: () {
            BroadcastCatalogue.load(refresh: true);
            ref.invalidate(broadcastsProvider);
          },
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: PillSelector<_BroadcastShelf>(
              value: _shelf,
              onChanged: (value) => setState(() => _shelf = value),
              options: [
                PillOption(
                  value: _BroadcastShelf.radio,
                  label: context.tr('broadcasts_radio'),
                  icon: Icons.radio_rounded,
                ),
                PillOption(
                  value: _BroadcastShelf.tv,
                  label: context.tr('broadcasts_tv'),
                  icon: Icons.live_tv_rounded,
                ),
                PillOption(
                  value: _BroadcastShelf.recordings,
                  label: context.tr('broadcasts_recordings'),
                  icon: Icons.album_rounded,
                ),
              ],
            ),
          ),
          if (_shelf == _BroadcastShelf.radio)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: GlassSearchField(
                controller: _search,
                hintText: context.tr('broadcasts_search_hint'),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          Expanded(
            child:
                _shelf == _BroadcastShelf.recordings
                    ? _recordingsShelf(tokens)
                    : catalogue.when(
                      loading:
                          () => const Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                      error:
                          (error, _) => _message(
                            tokens,
                            context.tr('broadcast_list_failed'),
                          ),
                      data: (all) => _list(tokens, all),
                    ),
          ),
          if (radio.isOn)
            _nowPlaying(tokens, radio)
          else
            // Anything else playing — a recording from the shelf above, most
            // likely. This page is pushed over the shell, so the strip the
            // shell keeps above the navigation bar is hidden underneath it,
            // and stepping back from a collection would otherwise leave a
            // ninety-minute night playing with no control on screen.
            const SafeArea(top: false, child: NowPlayingStrip()),
        ],
      ),
    );
  }

  Widget _message(AppTokens tokens, String text) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.caption(context, color: tokens.inkFaint),
      ),
    ),
  );

  Widget _list(AppTokens tokens, List<Broadcast> all) {
    final kind =
        _shelf == _BroadcastShelf.tv ? BroadcastKind.tv : BroadcastKind.radio;
    final ofKind = BroadcastCatalogue.of(all, kind);
    final matches =
        kind == BroadcastKind.radio
            ? BroadcastCatalogue.search(ofKind, _query)
            : ofKind;

    if (matches.isEmpty) {
      return _message(tokens, context.tr('broadcast_none'));
    }

    // Pinned first, then the catalogue's own order.
    final ordered = [
      ...matches.where((item) => item.pinned),
      ...matches.where((item) => !item.pinned),
    ];

    return ListView.builder(
      padding: AppScaffold.scrollPadding,
      itemCount: ordered.length + (kind == BroadcastKind.tv ? 1 : 0),
      itemBuilder: (context, index) {
        if (kind == BroadcastKind.tv && index == ordered.length) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              context.tr('broadcast_tv_note'),
              style: AppTextStyles.caption(context, color: tokens.inkFaint),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _row(tokens, ordered[index]),
        );
      },
    );
  }

  Widget _recordingsShelf(AppTokens tokens) {
    final rare = RecordingsCatalogue.of(RecordingCategory.rare);
    final taraweeh = RecordingsCatalogue.of(RecordingCategory.taraweeh);
    final stations = ref.watch(broadcastsProvider).asData?.value ?? const [];
    final byId = {for (final station in stations) station.id: station};
    final live = [
      for (final id in RecordingsCatalogue.liveRadioIds)
        if (byId[id] case final station?) station,
    ];

    return SingleChildScrollView(
      padding: AppScaffold.scrollPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: context.tr('recordings_rare_section')),
          for (final collection in rare) _collectionCard(tokens, collection),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: context.tr('recordings_taraweeh_section')),
          for (final collection in taraweeh)
            _collectionCard(tokens, collection),
          if (live.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(title: context.tr('recordings_live_section')),
            for (final station in live)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _row(tokens, station),
              ),
          ],
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.md,
            ),
            child: Text(
              context.tr('recordings_source_note'),
              style: AppTextStyles.caption(context, color: tokens.inkFaint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _collectionCard(AppTokens tokens, RecordingCollection collection) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => RecordingCollectionPage.open(context, collection),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizeDigits(context, collection.reciterAr),
              style: AppTextStyles.display(context, fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              localizeDigits(context, collection.titleAr),
              style: AppTextStyles.body(context, fontSize: 14),
            ),
            if (collection.subtitleAr.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                localizeDigits(context, collection.subtitleAr),
                style: AppTextStyles.caption(
                  context,
                  color: tokens.inkMuted,
                  fontSize: 12,
                ),
              ),
            ],
            if (collection.noteAr.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                localizeDigits(context, collection.noteAr),
                style: AppTextStyles.caption(
                  context,
                  color: tokens.inkFaint,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(AppTokens tokens, Broadcast station) {
    final radio = ref.watch(radioProvider);
    final isCurrent = radio.station?.id == station.id;
    final isTv = station.kind == BroadcastKind.tv;

    return AppCard(
      accent: station.pinned ? tokens.brand.withValues(alpha: 0.07) : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap:
          isTv
              ? () => LiveTvPage.open(context, station)
              : () => ref.read(radioProvider.notifier).play(station),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (station.pinned ? tokens.gold : tokens.brand).withValues(
                alpha: 0.14,
              ),
              borderRadius: AppRadii.smAll,
            ),
            child:
                isCurrent && radio.connecting
                    ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(tokens.brand),
                      ),
                    )
                    : Icon(
                      isTv
                          ? Icons.live_tv_rounded
                          : isCurrent && radio.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: station.pinned ? tokens.gold : tokens.brand,
                    ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(context, fontSize: 14),
                ),
                if (station.noteAr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    station.noteAr,
                    style: AppTextStyles.caption(
                      context,
                      color: tokens.inkFaint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isCurrent && radio.playing) _LiveDot(colour: tokens.brand),
        ],
      ),
    );
  }

  Widget _nowPlaying(AppTokens tokens, RadioState radio) {
    final station = radio.station!;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.lg),
        ),
        boxShadow: AppShadows.lift(tokens.ink),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: context.tr(radio.playing ? 'pause' : 'play'),
            iconSize: 38,
            icon: Icon(
              radio.playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: tokens.brand,
            ),
            onPressed: ref.read(radioProvider.notifier).toggle,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(context, fontSize: 14),
                ),
                Text(
                  context.tr(
                    radio.connecting
                        ? 'broadcast_connecting'
                        : 'broadcast_live',
                  ),
                  style: AppTextStyles.caption(
                    context,
                    color: radio.connecting ? tokens.inkFaint : tokens.brand,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('stop'),
            icon: Icon(Icons.stop_circle_outlined, color: tokens.inkMuted),
            onPressed: ref.read(radioProvider.notifier).stop,
          ),
        ],
      ),
    );
  }
}

/// A slow pulse, so "live" is visible without a word for it.
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.colour});

  final Color colour;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(_controller),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.colour),
      ),
    );
  }
}
