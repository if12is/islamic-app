import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../domain/zakat_calculator.dart';

/// Work out the zakat due on wealth, with the arithmetic left showing.
///
/// The prices are typed in rather than fetched. Gold moves daily and differs
/// by market; an app that quietly used yesterday's figure would hand someone a
/// number they might pay against, which is not a thing to be casual about.
class ZakatPage extends StatefulWidget {
  const ZakatPage({super.key});

  @override
  State<ZakatPage> createState() => _ZakatPageState();
}

class _ZakatPageState extends State<ZakatPage> {
  static const String _prefix = 'zakat_';

  final Map<String, TextEditingController> _fields = {
    for (final key in const [
      'cash',
      'savings',
      'goldGrams',
      'silverGrams',
      'businessGoods',
      'receivables',
      'debts',
      'goldPrice',
      'silverPrice',
    ])
      key: TextEditingController(),
  };

  NisabBasis _basis = NisabBasis.silver;
  DateTime? _hawlStart;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _prefs = prefs;
      for (final entry in _fields.entries) {
        final saved = prefs.getDouble('$_prefix${entry.key}');
        if (saved != null && saved != 0) {
          entry.value.text = _trim(saved);
        }
      }
      _basis =
          prefs.getString('${_prefix}basis') == NisabBasis.gold.name
              ? NisabBasis.gold
              : NisabBasis.silver;
      final start = prefs.getInt('${_prefix}hawlStart');
      _hawlStart =
          start == null ? null : DateTime.fromMillisecondsSinceEpoch(start);
    });
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    for (final entry in _fields.entries) {
      await prefs.setDouble('$_prefix${entry.key}', _value(entry.key));
    }
    await prefs.setString('${_prefix}basis', _basis.name);
  }

  double _value(String key) =>
      double.tryParse(_fields[key]!.text.trim().replaceAll(',', '')) ?? 0;

  static String _trim(double value) =>
      value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toString();

  ZakatAssets get _assets => ZakatAssets(
    cash: _value('cash'),
    savings: _value('savings'),
    goldGrams: _value('goldGrams'),
    silverGrams: _value('silverGrams'),
    businessGoods: _value('businessGoods'),
    receivables: _value('receivables'),
    debts: _value('debts'),
  );

  MetalPrices get _prices => MetalPrices(
    goldPerGram: _value('goldPrice'),
    silverPerGram: _value('silverPrice'),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final prices = _prices;
    final result = ZakatCalculator.calculate(
      assets: _assets,
      prices: prices,
      basis: _basis,
    );

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        context.tr('zakat'),
        style: AppTextStyles.display(context, fontSize: 18),
      ),
      body: ListView(
        padding: AppScaffold.scrollPadding,
        children: [
          _disclaimer(context, tokens),
          const SizedBox(height: AppSpacing.md),

          SectionHeader(
            title: context.tr('zakat_prices'),
            subtitle: context.tr('zakat_prices_desc'),
          ),
          AppCard(
            child: Column(
              children: [
                _field(context, 'goldPrice', 'zakat_gold_price'),
                const SizedBox(height: AppSpacing.sm),
                _field(context, 'silverPrice', 'zakat_silver_price'),
                const SizedBox(height: AppSpacing.md),
                _basisSelector(context),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(title: context.tr('zakat_assets')),
          AppCard(
            child: Column(
              children: [
                _field(context, 'cash', 'zakat_cash'),
                const SizedBox(height: AppSpacing.sm),
                _field(context, 'savings', 'zakat_savings'),
                const SizedBox(height: AppSpacing.sm),
                _field(context, 'goldGrams', 'zakat_gold_grams'),
                const SizedBox(height: AppSpacing.sm),
                _field(context, 'silverGrams', 'zakat_silver_grams'),
                const SizedBox(height: AppSpacing.sm),
                _field(context, 'businessGoods', 'zakat_business'),
                const SizedBox(height: AppSpacing.sm),
                _field(context, 'receivables', 'zakat_receivables'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(
            title: context.tr('zakat_debts'),
            subtitle: context.tr('zakat_debts_desc'),
          ),
          AppCard(child: _field(context, 'debts', 'zakat_debts_amount')),
          const SizedBox(height: AppSpacing.lg),

          _resultCard(context, tokens, result, prices),
          const SizedBox(height: AppSpacing.md),
          _hawlCard(context, tokens),
        ],
      ),
    );
  }

  Widget _disclaimer(BuildContext context, AppTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tokens.gold.withValues(alpha: 0.12),
        borderRadius: AppRadii.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.balance, size: 18, color: tokens.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.tr('zakat_disclaimer'),
              style: AppTextStyles.caption(context, color: tokens.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(BuildContext context, String key, String labelKey) {
    return TextField(
      controller: _fields[key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: context.tr(labelKey),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (_) {
        setState(() {});
        _save();
      },
    );
  }

  Widget _basisSelector(BuildContext context) {
    return PillSelector<NisabBasis>(
      compact: true,
      scrollable: false,
      value: _basis,
      onChanged: (value) {
        setState(() => _basis = value);
        _save();
      },
      options: [
        PillOption(
          value: NisabBasis.silver,
          label: context.tr('zakat_basis_silver'),
        ),
        PillOption(
          value: NisabBasis.gold,
          label: context.tr('zakat_basis_gold'),
        ),
      ],
    );
  }

  Widget _resultCard(
    BuildContext context,
    AppTokens tokens,
    ZakatResult result,
    MetalPrices prices,
  ) {
    if (!prices.isComplete) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.pending_outlined, size: 18, color: tokens.inkFaint),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.tr('zakat_need_prices'),
                style: AppTextStyles.caption(context),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      corners: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(result.isDue ? 'zakat_due' : 'zakat_not_due'),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(context, color: tokens.inkMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _money(result.isDue ? result.due : result.shortfall),
            textAlign: TextAlign.center,
            style: AppTextStyles.display(
              context,
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: result.isDue ? tokens.brand : tokens.inkMuted,
            ),
          ),
          if (!result.isDue) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr('zakat_shortfall'),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(context, color: tokens.inkFaint),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),

          // The working, so the number is checkable rather than magic.
          _line(context, 'zakat_total_assets', _money(result.totalAssets)),
          _line(context, 'zakat_debts_amount', '−${_money(_value('debts'))}'),
          _line(context, 'zakat_net', _money(result.netWealth)),
          _line(context, 'zakat_nisab', _money(result.nisab)),
          _line(context, 'zakat_rate', '٢٫٥٪'),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String labelKey, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr(labelKey),
              style: AppTextStyles.caption(context),
            ),
          ),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: AppTextStyles.body(context, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _hawlCard(BuildContext context, AppTokens tokens) {
    final start = _hawlStart;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('zakat_hawl'),
            style: AppTextStyles.display(context, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.tr('zakat_hawl_desc'),
            style: AppTextStyles.caption(context, color: tokens.inkFaint),
          ),
          const SizedBox(height: AppSpacing.md),
          if (start == null)
            OutlinedButton.icon(
              onPressed: _pickHawlStart,
              icon: const Icon(Icons.event, size: 18),
              label: Text(context.tr('zakat_set_hawl')),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    _daysMessage(context, start),
                    style: AppTextStyles.body(context, fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: _pickHawlStart,
                  child: Text(context.tr('change')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _daysMessage(BuildContext context, DateTime start) {
    final left = ZakatCalculator.daysUntilHawl(start);
    final language = Localizations.localeOf(context).languageCode;

    if (left <= 0) {
      return context.tr('zakat_hawl_complete');
    }
    return AppLocalizations.translate(
      language,
      'zakat_hawl_left',
      replacements: {'days': '$left'},
    );
  }

  Future<void> _pickHawlStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _hawlStart ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _hawlStart = picked);
    await _prefs?.setInt('${_prefix}hawlStart', picked.millisecondsSinceEpoch);
  }

  static String _money(double value) {
    final rounded = value.abs() < 0.005 ? 0.0 : value;
    return rounded
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+\.)'),
          (match) => '${match[1]},',
        );
  }
}
