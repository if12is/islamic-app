import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../data/salawat_store.dart';
import '../../domain/salawat_forms.dart';

/// A counter for the prayer upon the Prophet ﷺ, with the wording in front of
/// you rather than left to memory.
///
/// The count is a record, not a target. No number here unlocks anything, and
/// the screen sets no goal — the narration promises tenfold for one, which is
/// already the whole point.
class SalawatPage extends StatefulWidget {
  const SalawatPage({super.key});

  @override
  State<SalawatPage> createState() => _SalawatPageState();
}

class _SalawatPageState extends State<SalawatPage> {
  SharedPreferences? _prefs;
  SalawatForm _form = SalawatForms.all.first;
  int _total = 0;
  int _today = 0;

  bool get _isFriday => DateTime.now().weekday == DateTime.friday;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _prefs = prefs;
      _form = SalawatForms.byId(SalawatStore.formId(prefs));
      _total = SalawatStore.total(prefs);
      _today = SalawatStore.today(prefs);
    });
  }

  Future<void> _count() async {
    HapticFeedback.lightImpact();
    final prefs = _prefs;
    final next =
        prefs == null ? _total + 1 : await SalawatStore.increment(prefs);

    if (!mounted) {
      return;
    }
    setState(() {
      _total = next;
      _today++;
    });
    if (next % 100 == 0) {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        context.tr('salawat'),
        style: AppTextStyles.display(context, fontSize: 18),
      ),
      body: ListView(
        padding: AppScaffold.scrollPadding,
        children: [
          _virtueCard(context, tokens),
          if (_isFriday) ...[
            const SizedBox(height: AppSpacing.md),
            _fridayCard(context, tokens),
          ],
          const SizedBox(height: AppSpacing.lg),

          _counter(context, tokens),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(
            title: context.tr('salawat_forms'),
            subtitle: context.tr('salawat_forms_desc'),
          ),
          for (final form in SalawatForms.all) ...[
            _formCard(context, tokens, form),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _virtueCard(BuildContext context, AppTokens tokens) {
    return AppCard(
      corners: true,
      child: Column(
        children: [
          Text(
            SalawatForms.virtueAr,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: AppTextStyles.quran(context, fontSize: 19),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            SalawatForms.virtueSourceAr,
            style: AppTextStyles.caption(
              context,
              fontSize: 11,
              color: tokens.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fridayCard(BuildContext context, AppTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tokens.brand.withValues(alpha: 0.12),
        borderRadius: AppRadii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            SalawatForms.fridayAr,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: AppTextStyles.body(context, fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            SalawatForms.fridaySourceAr,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(
              context,
              fontSize: 11,
              color: tokens.brand,
            ),
          ),
        ],
      ),
    );
  }

  Widget _counter(BuildContext context, AppTokens tokens) {
    return Column(
      children: [
        Text(
          _form.textAr,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: AppTextStyles.quran(context, fontSize: 20),
        ),
        const SizedBox(height: AppSpacing.lg),

        GestureDetector(
          onTap: _count,
          child: Container(
            width: 176,
            height: 176,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [tokens.brand, tokens.brandDeep],
              ),
              boxShadow: AppShadows.glow(tokens.brand, alpha: 0.28),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.tr('salawat_today'),
                  style: AppTextStyles.caption(
                    context,
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _digits(context, _today),
                    style: const TextStyle(
                      fontFamily: AppTextStyles.displayFamily,
                      fontSize: 52,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${context.tr('salawat_total')}: ${_digits(context, _total)}',
          style: AppTextStyles.caption(context, color: tokens.inkMuted),
        ),
      ],
    );
  }

  Widget _formCard(BuildContext context, AppTokens tokens, SalawatForm form) {
    final selected = form.id == _form.id;

    return AppCard(
      onTap: () async {
        setState(() => _form = form);
        final prefs = _prefs;
        if (prefs != null) {
          await SalawatStore.setFormId(prefs, form.id);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: selected ? tokens.brand : tokens.inkFaint,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  form.sourceAr,
                  style: AppTextStyles.caption(
                    context,
                    fontSize: 11,
                    color: tokens.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            form.textAr,
            textDirection: TextDirection.rtl,
            style: AppTextStyles.quran(context, fontSize: 17),
          ),
          if (form.noteAr != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              form.noteAr!,
              textDirection: TextDirection.rtl,
              style: AppTextStyles.caption(context, color: tokens.inkFaint),
            ),
          ],
        ],
      ),
    );
  }

  static String _digits(BuildContext context, int value) {
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
