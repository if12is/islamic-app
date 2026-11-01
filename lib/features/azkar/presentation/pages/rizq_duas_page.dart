import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/islamic_icon.dart';
import '../../domain/rizq_duas.dart';

/// The provision and debt-relief supplications, each with its wording,
/// virtue, source, and a way to copy it.
class RizqDuasPage extends StatelessWidget {
  const RizqDuasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppScaffold(
      title: 'rizq_duas_title',
      showBack: true,
      body: ListView(
        padding: AppScaffold.scrollPadding,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIconBadge(
                      IslamicIcon.sparkles,
                      color: tokens.gold,
                      background: tokens.gold.withValues(alpha: 0.15),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        context.tr('rizq_duas_intro_title'),
                        style: AppTextStyles.display(
                          context,
                          fontSize: 18,
                          color: tokens.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.tr('rizq_duas_intro_text'),
                  style: AppTextStyles.body(context, color: tokens.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final dua in RizqDuas.all) ...[
            _DuaCard(dua: dua),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _DuaCard extends StatelessWidget {
  const _DuaCard({required this.dua});

  final RizqDua dua;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppCard(
      corners: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dua.textAr,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.start,
            style: AppTextStyles.quran(context, fontSize: 19, height: 1.8),
          ),
          if (dua.textEn.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              dua.textEn,
              textDirection: TextDirection.ltr,
              style: AppTextStyles.body(
                context,
                color: tokens.inkMuted,
                height: 1.6,
              ),
            ),
          ],
          if (dua.virtue.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              dua.virtue,
              textDirection: TextDirection.rtl,
              style: AppTextStyles.caption(context, color: tokens.inkMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.brand.withValues(alpha: 0.08),
                    borderRadius: AppRadii.smAll,
                  ),
                  child: Text(
                    dua.reference,
                    textDirection: TextDirection.rtl,
                    style: AppTextStyles.caption(
                      context,
                      fontSize: 11,
                      color: tokens.brand,
                    ),
                  ),
                ),
              ),
              GhostIconButton(
                icon: Icons.copy_outlined,
                tooltip: context.tr('copy'),
                onTap: () => _copy(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: '${dua.textAr}\n\n${dua.reference}'));
    AppLogger.info('Copied rizq dua ${dua.id}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('copied')),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
