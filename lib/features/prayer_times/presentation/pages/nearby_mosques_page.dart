import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/geo.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../domain/nearby_mosque.dart';
import '../providers/nearby_mosques_provider.dart';
import '../widgets/mosque_map_view.dart';

/// The mosques around you: a map, and a list sorted by distance.
///
/// Two sources, because neither one is enough on its own. The list comes from
/// OpenStreetMap and is what knows how far each mosque is and which way to
/// walk — but OSM is drawn by volunteers, and in most Egyptian cities it is
/// nearly empty. The map above it is Google's, through the one part of Maps
/// Platform that is free and uncapped, and it shows the mosques OSM has never
/// been told about. Below both sits a button that hands the whole search to
/// whichever maps app is already installed, which is the only part that works
/// with no key at all.
class NearbyMosquesPage extends ConsumerStatefulWidget {
  const NearbyMosquesPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NearbyMosquesPage()));
  }

  @override
  ConsumerState<NearbyMosquesPage> createState() => _NearbyMosquesPageState();
}

class _NearbyMosquesPageState extends ConsumerState<NearbyMosquesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(nearbyMosquesProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final state = ref.watch(nearbyMosquesProvider);
    final language = Localizations.localeOf(context).languageCode;
    final coordinates = ref.watch(currentLocationCoordinatesProvider).value;

    return AppScaffold(
      title: 'nearby_mosques',
      showBack: true,
      actions: [
        IconButton(
          tooltip: context.tr('refresh'),
          icon: Icon(Icons.refresh_rounded, color: tokens.ink, size: 20),
          onPressed:
              state.loading
                  ? null
                  : () => ref
                      .read(nearbyMosquesProvider.notifier)
                      .load(refresh: true),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.navClearance,
        ),
        children: [
          PillSelector<int>(
            value: state.radiusMetres,
            onChanged:
                (value) =>
                    ref.read(nearbyMosquesProvider.notifier).setRadius(value),
            options: [
              for (final metres in MosqueSearch.radiusChoices)
                PillOption(value: metres, label: _radiusLabel(context, metres)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // The map goes above the list, and is drawn whatever the search
          // returned. It is the part that knows about the mosques Overpass
          // has never been told exist.
          if (MosqueMapView.isAvailable && coordinates != null) ...[
            MosqueMapView(
              latitude: coordinates.latitude,
              longitude: coordinates.longitude,
              radiusMetres: state.radiusMetres,
              language: language,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          if (state.loading)
            const _Waiting()
          else if (state.failure != null)
            _Problem(
              messageKey: MosqueLookupException(state.failure!).messageKey,
              onRetry:
                  () => ref
                      .read(nearbyMosquesProvider.notifier)
                      .load(refresh: true),
            )
          else if (state.searchedAndEmpty)
            _Empty(radiusMetres: state.radiusMetres)
          else ...[
            _Summary(state: state),
            const SizedBox(height: AppSpacing.md),
            for (final mosque in state.mosques) ...[
              _MosqueRow(
                mosque: mosque,
                language: language,
                fromLatitude: coordinates?.latitude,
                fromLongitude: coordinates?.longitude,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],

          // Offered whatever the search returned, not only when it returned
          // nothing. A short list is the more misleading case: it looks like
          // the whole answer, and in a thinly mapped city it is a fraction of
          // one. This says so, and hands the search to the app that has the
          // rest of it.
          if (!state.loading) ...[
            const SizedBox(height: AppSpacing.md),
            _SearchElsewhere(
              latitude: coordinates?.latitude,
              longitude: coordinates?.longitude,
              sparse: state.mosques.length < 4,
            ),
          ],

          if (state.mosques.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr('mosques_attribution'),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(
                context,
                color: tokens.inkFaint,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _radiusLabel(BuildContext context, int metres) {
    if (metres < 1000) {
      return '$metres ${context.tr('unit_metre')}';
    }
    return '${metres ~/ 1000} ${context.tr('unit_km')}';
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final NearbyMosquesState state;

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    final language = Localizations.localeOf(context).languageCode;
    final count = state.mosques.length;
    final capped = count >= MosqueSearch.maxShown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.translate(
            language,
            capped ? 'mosques_found_capped' : 'mosques_found',
            replacements: {'count': '$count'},
          ),
          style: AppTextStyles.caption(context),
        ),
        if (result.fromCache) ...[
          const SizedBox(height: AppSpacing.xs),
          // Saying when the list was gathered matters more than it looks: a
          // cached answer shown as live is a promise the app cannot keep once
          // a mosque has opened or closed since.
          Text(
            context.tr('mosques_from_cache'),
            style: AppTextStyles.caption(
              context,
              color: context.tokens.inkFaint,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _MosqueRow extends StatelessWidget {
  const _MosqueRow({
    required this.mosque,
    required this.language,
    required this.fromLatitude,
    required this.fromLongitude,
  });

  final NearbyMosque mosque;
  final String language;
  final double? fromLatitude;
  final double? fromLongitude;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final name = mosque.displayName(language);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: () => _open(context),
      child: Row(
        children: [
          _Arrow(bearing: mosque.bearing),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty
                      ? context.tr(
                        mosque.isMusalla ? 'musalla_unnamed' : 'mosque_unnamed',
                      )
                      : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(context, fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    _distance(context, mosque.distanceMetres),
                    context.tr(_octantKey(mosque.bearing)),
                    if (mosque.street.isNotEmpty) mosque.street,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(
                    context,
                    color: tokens.inkFaint,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (mosque.isMusalla) ...[
            const SizedBox(width: AppSpacing.sm),
            HintPill(text: context.tr('musalla'), tone: HintTone.neutral),
          ],
          const SizedBox(width: AppSpacing.xs),
          GhostIconButton(
            icon: Icons.directions_outlined,
            tooltip: context.tr('mosques_directions'),
            onTap: () => _open(context, directions: true),
          ),
        ],
      ),
    );
  }

  /// Hand the place to whatever maps app is installed.
  ///
  /// `geo:` is the intent every Android maps app registers for, so the user
  /// keeps their own choice of app. When nothing answers it — a phone with no
  /// maps app, or the web build — the OpenStreetMap page is the fallback, and
  /// that is a real page rather than a dead end.
  Future<void> _open(BuildContext context, {bool directions = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.tr('mosques_open_failed');

    final targets = <Uri>[
      if (directions && fromLatitude != null && fromLongitude != null)
        mosque.directionsUri(fromLatitude!, fromLongitude!),
      if (!directions) mosque.geoUri,
      mosque.webMapUri,
    ];

    for (final uri in targets) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {
        // Try the next one rather than reporting a failure that has a
        // perfectly good alternative waiting behind it.
      }
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failed)));
  }

  static String _distance(BuildContext context, double metres) {
    if (metres < 1000) {
      return '${metres.round()} ${context.tr('unit_metre')}';
    }
    return '${(metres / 1000).toStringAsFixed(1)} ${context.tr('unit_km')}';
  }

  static String _octantKey(double bearing) =>
      const [
        'compass_n',
        'compass_ne',
        'compass_e',
        'compass_se',
        'compass_s',
        'compass_sw',
        'compass_w',
        'compass_nw',
      ][Geo.compassOctant(bearing)];
}

/// A needle pointing the way, which reads faster than a compass word.
class _Arrow extends StatelessWidget {
  const _Arrow({required this.bearing});

  final double bearing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: tokens.brand.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      // The bearing is measured from north; the icon points up, which is
      // north on a north-up dial, so the rotation is the bearing itself.
      child: Transform.rotate(
        angle: bearing * math.pi / 180,
        child: Icon(Icons.navigation_rounded, size: 19, color: tokens.brand),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          const CircularProgressIndicator.adaptive(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.tr('mosques_searching'),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(context),
          ),
        ],
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.messageKey, required this.onRetry});

  final String messageKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 20,
                color: context.tokens.inkMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.tr(messageKey),
                  style: AppTextStyles.body(context, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: onRetry,
              child: Text(context.tr('retry')),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.radiusMetres});

  final int radiusMetres;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final distance =
        radiusMetres < 1000
            ? '$radiusMetres ${context.tr('unit_metre')}'
            : '${radiusMetres ~/ 1000} ${context.tr('unit_km')}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.translate(
              language,
              'mosques_none',
              replacements: {'distance': distance},
            ),
            style: AppTextStyles.body(context, fontSize: 13.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          // The distinction that matters: the area was not surveyed and found
          // empty, it was never drawn. Saying "no mosque near you" without
          // that would be a claim about the world made from a gap in a map.
          Text(
            context.tr('mosques_none_hint'),
            style: AppTextStyles.caption(context),
          ),
        ],
      ),
    );
  }
}

/// One tap to the maps app, which in most of the world knows more mosques than
/// OpenStreetMap does.
class _SearchElsewhere extends StatelessWidget {
  const _SearchElsewhere({
    required this.latitude,
    required this.longitude,
    required this.sparse,
  });

  final double? latitude;
  final double? longitude;

  /// Whether the list came back thin enough to be worth warning about.
  final bool sparse;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (latitude == null || longitude == null) {
      return const SizedBox.shrink();
    }

    return AppCard(
      accent: sparse ? tokens.gold.withValues(alpha: 0.12) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.travel_explore_rounded, size: 19, color: tokens.gold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.tr('mosques_search_maps_title'),
                  style: AppTextStyles.body(context, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr(
              sparse ? 'mosques_coverage_thin' : 'mosques_search_maps_desc',
            ),
            style: AppTextStyles.caption(context),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonalIcon(
              onPressed: () => _search(context),
              icon: const Icon(Icons.map_outlined, size: 17),
              label: Text(context.tr('mosques_search_maps')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _search(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.tr('mosques_open_failed');
    // The search term follows the reader's language: a maps app searching for
    // "mosque" in Egypt finds fewer than one searching for "مسجد".
    final term = context.tr('mosque_search_term');

    for (final uri in [
      MosqueSearch.mapsSearchUri(latitude!, longitude!, term: term),
      MosqueSearch.webSearchUri(latitude!, longitude!, term: term),
    ]) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {
        // Fall through to the next one.
      }
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failed)));
  }
}
