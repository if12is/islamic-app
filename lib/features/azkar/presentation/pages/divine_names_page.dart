import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../domain/divine_names.dart';

/// The ninety-nine names, to read through or to search.
///
/// It opens on the hadith the count rests on, and says plainly that the listing
/// of the names is a narrator's and not part of the agreed-upon text. An app
/// that prints the list as if it were revelation teaches something false about
/// where it came from.
class DivineNamesPage extends StatefulWidget {
  const DivineNamesPage({super.key});

  @override
  State<DivineNamesPage> createState() => _DivineNamesPageState();
}

class _DivineNamesPageState extends State<DivineNamesPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final results = DivineNames.search(_search.text);

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        context.tr('divine_names'),
        style: AppTextStyles.display(context, fontSize: 18),
      ),
      body: ListView(
        padding: AppScaffold.scrollPadding,
        children: [
          _hadithCard(context, tokens),
          const SizedBox(height: AppSpacing.md),
          GlassSearchField(
            controller: _search,
            hintText: context.tr('divine_names_search_hint'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),

          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                context.tr('no_results'),
                textAlign: TextAlign.center,
                style: AppTextStyles.caption(context),
              ),
            )
          else
            for (final name in results) ...[
              _nameCard(context, tokens, name),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }

  Widget _hadithCard(BuildContext context, AppTokens tokens) {
    return AppCard(
      corners: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DivineNames.hadithAr,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: AppTextStyles.quran(context, fontSize: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            DivineNames.hadithSourceAr,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(
              context,
              fontSize: 11,
              color: tokens.gold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: tokens.groundAlt,
              borderRadius: AppRadii.mdAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: tokens.inkFaint),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    DivineNames.listingNoteAr,
                    style: AppTextStyles.caption(context, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameCard(BuildContext context, AppTokens tokens, DivineName name) {
    return AppCard(
      onTap: () => _copy(context, name),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The number is a place in the list, not a rank — kept quiet.
          SizedBox(
            width: 32,
            child: Text(
              _arabicNumber(context, name.number),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(
                context,
                fontSize: 13,
                color: tokens.inkFaint,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.arabic,
                  textDirection: TextDirection.rtl,
                  style: AppTextStyles.display(
                    context,
                    fontSize: 24,
                    color: tokens.brand,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name.transliteration,
                  style: AppTextStyles.caption(
                    context,
                    fontSize: 11,
                    color: tokens.inkFaint,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  name.meaningAr,
                  textDirection: TextDirection.rtl,
                  style: AppTextStyles.body(context, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, DivineName name) async {
    await Clipboard.setData(
      ClipboardData(text: '${name.arabic} — ${name.meaningAr}'),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('copied'))));
    }
  }

  static String _arabicNumber(BuildContext context, int value) {
    if (!context.isAppRtl) {
      return '$value';
    }
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return value
        .toString()
        .split('')
        .map((char) => digits[int.parse(char)])
        .join();
  }
}
