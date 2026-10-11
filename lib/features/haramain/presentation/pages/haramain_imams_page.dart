import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/arabic_numerals.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../domain/haramain_roster.dart';
import '../../domain/haramain_week.dart';
import '../providers/haramain_provider.dart';

/// Who leads each of the five prayers this week at the two Holy Mosques.
///
/// One imam per prayer for the whole week — that is what is announced, so
/// that is all the page claims. Muezzins are not published anywhere the app
/// can read, and are not mentioned.
class HaramainImamsPage extends ConsumerWidget {
  const HaramainImamsPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const HaramainImamsPage()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final state = ref.watch(haramainProvider);
    final week = state.week;

    return AppScaffold(
      title: 'haramain_title',
      showBack: true,
      body: Column(
        children: [
          // A thin bar rather than a spinner, so the cached week stays
          // readable while the refresh runs behind it.
          if (state.loading && week != null)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child:
                week != null
                    ? _WeekView(week: week)
                    : state.loading
                    ? const Center(child: CircularProgressIndicator.adaptive())
                    : _Unavailable(
                      onRetry:
                          () => ref.read(haramainProvider.notifier).retry(),
                      tokens: tokens,
                    ),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry, required this.tokens});

  final VoidCallback onRetry;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: tokens.inkFaint),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr('haramain_unavailable'),
              textAlign: TextAlign.center,
              style: AppTextStyles.body(context, color: tokens.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              onPressed: onRetry,
              child: Text(context.tr('retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({required this.week});

  final HaramainWeek week;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final language = Localizations.localeOf(context).languageCode;
    final range = AppLocalizations.translate(
      language,
      'haramain_week_range',
      replacements: {
        'from': week.startHijri,
        'to': week.endHijri,
        'year': '${week.hijriYear}',
      },
    );
    final stale = week.hasEndedAt(DateTime.now());

    return SingleChildScrollView(
      padding: AppScaffold.scrollPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('haramain_each_prayer'),
                  style: AppTextStyles.display(context, fontSize: 20),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  localizeDigits(context, range),
                  style: AppTextStyles.body(context, color: tokens.inkMuted),
                ),
                if (stale) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.tr('haramain_stale'),
                    style: AppTextStyles.caption(
                      context,
                      color: tokens.gold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final mosque in HaramainMosque.values) ...[
            SectionHeader(
              title: context.tr(
                mosque == HaramainMosque.haram
                    ? 'haramain_haram'
                    : 'haramain_nabawi',
              ),
            ),
            _MosqueCard(entries: week.of(mosque)),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            AppLocalizations.translate(
              language,
              'haramain_updated',
              replacements: {
                'time': localizeDigits(context, _stamp(week.fetchedAt)),
              },
            ),
            style: AppTextStyles.caption(
              context,
              color: tokens.inkFaint,
              fontSize: 13,
            ),
          ),
          _SourceLink(url: week.sourceUrl),
        ],
      ),
    );
  }

  /// «11/10 21:45» in the phone's own clock. Written by hand rather than with
  /// intl's date formats, which need the locale's data loaded first.
  static String _stamp(DateTime when) {
    final local = when.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.day}/${local.month} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _MosqueCard extends StatelessWidget {
  const _MosqueCard({required this.entries});

  final Map<HaramainPrayer, ImamEntry> entries;

  static const Map<HaramainPrayer, String> _prayerKeys = {
    HaramainPrayer.fajr: 'fajr',
    HaramainPrayer.dhuhr: 'dhuhr',
    HaramainPrayer.asr: 'asr',
    HaramainPrayer.maghrib: 'maghrib',
    HaramainPrayer.isha: 'isha',
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final english = Localizations.localeOf(context).languageCode != 'ar';

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          for (final prayer in HaramainPrayer.values)
            if (entries[prayer] case final entry?)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        context.tr(_prayerKeys[prayer]!),
                        style: AppTextStyles.body(
                          context,
                          fontSize: 17,
                          color: tokens.inkMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        _nameFor(entry, english),
                        style: AppTextStyles.display(context, fontSize: 20),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static String _nameFor(ImamEntry entry, bool english) {
    if (english) {
      final imam = haramainImamById(entry.rosterId);
      if (imam != null) {
        return imam.nameEn;
      }
    }
    return entry.displayName;
  }
}

class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.url});

  final String url;

  /// The source is named after the host the week came from; a week stored
  /// before Shahd Now was added has an Al-Madina link and keeps its name.
  static String _sourceKey(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.endsWith('shahdnow.sa')
        ? 'haramain_source_shahd'
        : 'haramain_source';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: InkWell(
        onTap: () => _open(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  context.tr(_sourceKey(url)),
                  style: AppTextStyles.body(
                    context,
                    fontSize: 15,
                    color: tokens.brand,
                  ).copyWith(decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.open_in_new_rounded, size: 16, color: tokens.brand),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.tr('haramain_open_failed');
    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        messenger.showSnackBar(SnackBar(content: Text(failed)));
      }
    } on Object catch (error, stackTrace) {
      AppLogger.error('Failed to open the imams article', error, stackTrace);
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}
