import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../data/broadcast_catalogue.dart';
import '../../domain/broadcast.dart';
import '../providers/radio_provider.dart';
import 'live_tv_page.dart';

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
  BroadcastKind _kind = BroadcastKind.radio;
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
            child: PillSelector<BroadcastKind>(
              scrollable: false,
              value: _kind,
              onChanged: (value) => setState(() => _kind = value),
              options: [
                PillOption(
                  value: BroadcastKind.radio,
                  label: context.tr('broadcasts_radio'),
                  icon: Icons.radio_rounded,
                ),
                PillOption(
                  value: BroadcastKind.tv,
                  label: context.tr('broadcasts_tv'),
                  icon: Icons.live_tv_rounded,
                ),
              ],
            ),
          ),
          if (_kind == BroadcastKind.radio)
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
            child: catalogue.when(
              loading:
                  () =>
                      const Center(child: CircularProgressIndicator.adaptive()),
              error:
                  (error, _) =>
                      _message(tokens, context.tr('broadcast_list_failed')),
              data: (all) => _list(tokens, all),
            ),
          ),
          if (radio.isOn) _nowPlaying(tokens, radio),
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
    final ofKind = BroadcastCatalogue.of(all, _kind);
    final matches =
        _kind == BroadcastKind.radio
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
      itemCount: ordered.length + (_kind == BroadcastKind.tv ? 1 : 0),
      itemBuilder: (context, index) {
        if (_kind == BroadcastKind.tv && index == ordered.length) {
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
