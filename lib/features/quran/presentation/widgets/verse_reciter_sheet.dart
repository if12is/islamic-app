import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../data/services/verse_reciters.dart';

/// Pick a voice that is recorded ayah by ayah.
///
/// A separate sheet from the whole-surah picker on purpose. The two catalogues
/// are different corpora — a whole-surah recording has no seam at the ayah —
/// and offering a voice here that cannot be cut at the verse would mean a
/// video whose captions never change and a memorisation loop that 404s.
class VerseReciterSheet extends StatefulWidget {
  const VerseReciterSheet({super.key, required this.selectedId});

  final String selectedId;

  static Future<VerseReciter?> show(BuildContext context, String selectedId) {
    return showModalBottomSheet<VerseReciter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => VerseReciterSheet(selectedId: selectedId),
    );
  }

  @override
  State<VerseReciterSheet> createState() => _VerseReciterSheetState();
}

class _VerseReciterSheetState extends State<VerseReciterSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final selected = VerseReciters.resolve(widget.selectedId);
    final matches = VerseReciters.search(_query);

    return Directionality(
      textDirection: context.appTextDirection,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.94,
        minChildSize: 0.45,
        builder: (context, controller) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('reciter'),
                      style: AppTextStyles.display(
                        context,
                        fontSize: 19,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.translate(
                        Localizations.localeOf(context).languageCode,
                        'verse_reciter_count',
                        replacements: {'count': '${VerseReciters.all.length}'},
                      ),
                      style: AppTextStyles.caption(
                        context,
                        color: tokens.inkFaint,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GlassSearchField(
                      controller: _search,
                      hintText: context.tr('reciter_search_hint'),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    matches.isEmpty
                        ? Center(
                          child: Text(
                            context.tr('broadcast_none'),
                            style: AppTextStyles.caption(
                              context,
                              color: tokens.inkFaint,
                            ),
                          ),
                        )
                        : ListView.builder(
                          controller: controller,
                          padding: const EdgeInsets.only(bottom: 32),
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final reciter = matches[index];
                            return ListTile(
                              title: Text(reciter.nameAr),
                              subtitle:
                                  reciter.styleAr.isEmpty
                                      ? null
                                      : Text(reciter.styleAr),
                              trailing:
                                  reciter.id == selected
                                      ? Icon(
                                        Icons.check_rounded,
                                        color: tokens.brand,
                                      )
                                      : null,
                              onTap: () => Navigator.of(context).pop(reciter),
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}
