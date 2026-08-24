import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../data/bookmark_store.dart';
import '../../data/services/quran_local_service.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/hifz_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../pages/ayah_video_studio_page.dart';
import '../pages/recitation_page.dart';
import 'ayah_share_card.dart';
import 'tafsir_sheet.dart';

/// Everything you can do with a single verse.
///
/// Opened by a long press, which is why a plain tap can stay a plain tap:
/// selecting a verse no longer silently overwrites the saved bookmark.
class AyahActionsSheet extends ConsumerStatefulWidget {
  const AyahActionsSheet({
    super.key,
    required this.verse,
    required this.onPlayFromHere,
  });

  final QuranVerse verse;
  final VoidCallback onPlayFromHere;

  static Future<void> show(
    BuildContext context, {
    required QuranVerse verse,
    required VoidCallback onPlayFromHere,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => AyahActionsSheet(verse: verse, onPlayFromHere: onPlayFromHere),
    );
  }

  @override
  ConsumerState<AyahActionsSheet> createState() => _AyahActionsSheetState();
}

class _AyahActionsSheetState extends ConsumerState<AyahActionsSheet> {
  QuranBookmark? _bookmark;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmark();
  }

  Future<void> _loadBookmark() async {
    final store = ref.read(bookmarkStoreProvider);
    final found = await store.find(
      widget.verse.surahNumber,
      widget.verse.numberInSurah,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _bookmark = found;
      _loading = false;
    });
  }

  Future<void> _toggleBookmark() async {
    final notifier = ref.read(bookmarksProvider.notifier);
    if (_bookmark != null) {
      await notifier.remove(
        widget.verse.surahNumber,
        widget.verse.numberInSurah,
      );
      if (mounted) {
        setState(() => _bookmark = null);
        _toast(context.tr('bookmark_removed'));
      }
      return;
    }

    await notifier.save(verse: widget.verse);
    await _loadBookmark();
    if (mounted) {
      _toast(context.tr('bookmark_added'));
    }
  }

  Future<void> _setTag(BookmarkTag tag) async {
    await ref
        .read(bookmarksProvider.notifier)
        .save(verse: widget.verse, tag: tag, note: _bookmark?.note ?? '');
    await _loadBookmark();
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _bookmark?.note ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(dialogContext.tr('add_note')),
            content: TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: dialogContext.tr('note_hint'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(dialogContext.tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(dialogContext.tr('save')),
              ),
            ],
          ),
    );

    if (saved == true) {
      await ref
          .read(bookmarksProvider.notifier)
          .save(
            verse: widget.verse,
            tag: _bookmark?.tag ?? BookmarkTag.reflect,
            note: controller.text.trim(),
          );
      await _loadBookmark();
      if (mounted) {
        _toast(context.tr('note_saved'));
      }
    }
    controller.dispose();
  }

  Future<void> _shareImage() async {
    final style = await showModalBottomSheet<AyahCardStyle>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    sheetContext.tr('choose_card_style'),
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                for (final style in AyahCardStyle.values)
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: _previewGradient(style),
                      ),
                    ),
                    title: Text(sheetContext.tr('card_style_${style.name}')),
                    onTap: () => Navigator.of(sheetContext).pop(style),
                  ),
              ],
            ),
          ),
    );

    if (style == null) {
      return;
    }

    final font = ref.read(readerSettingsProvider).font;
    if (mounted) {
      _toast(context.tr('preparing_image'));
    }

    final ok = await AyahSharing.shareImage(
      verse: widget.verse,
      style: style,
      font: font,
    );

    if (!ok && mounted) {
      _toast(context.tr('share_failed'));
    }
  }

  LinearGradient _previewGradient(AyahCardStyle style) {
    switch (style) {
      case AyahCardStyle.emerald:
        return const LinearGradient(
          colors: [Color(0xFF07231A), Color(0xFF0B6B4F)],
        );
      case AyahCardStyle.night:
        return const LinearGradient(
          colors: [Color(0xFF0B0F14), Color(0xFF1B2430)],
        );
      case AyahCardStyle.parchment:
        return const LinearGradient(
          colors: [Color(0xFFF6ECD8), Color(0xFFE6D2AE)],
        );
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final verse = widget.verse;
    final settings = ref.watch(readerSettingsProvider);
    final isBookmarked = _bookmark != null;

    return Directionality(
      textDirection: context.appTextDirection,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${context.tr('surah_word')} ${verse.surahNameAr} · '
                '${context.tr('ayah_word')} ${verse.numberInSurah}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                verse.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: settings.font.family,
                  fontSize: settings.fontSize * 0.7,
                  height: 1.9,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _action(
                    icon: Icons.play_circle_outline,
                    labelKey: 'play_from_here',
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onPlayFromHere();
                    },
                  ),
                  _action(
                    icon: Icons.menu_book,
                    labelKey: 'tafsir',
                    onTap: () {
                      Navigator.of(context).pop();
                      TafsirSheet.show(context, verse);
                    },
                  ),
                  _action(
                    icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    labelKey: isBookmarked ? 'remove_bookmark' : 'add_bookmark',
                    onTap: _loading ? null : _toggleBookmark,
                  ),
                  _action(
                    icon: Icons.edit_note,
                    labelKey: 'add_note',
                    onTap: _editNote,
                  ),
                  _action(
                    icon: Icons.mic_none,
                    labelKey: 'recite_title',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => RecitationPage(
                                surahNumber: verse.surahNumber,
                                fromAyah: verse.numberInSurah,
                                toAyah: verse.numberInSurah,
                              ),
                        ),
                      );
                    },
                  ),
                  _action(
                    icon: Icons.psychology_alt_outlined,
                    labelKey: 'hifz_add_verse',
                    onTap: () async {
                      final message = context.tr('hifz_added');
                      await ref
                          .read(hifzProvider.notifier)
                          .add(
                            surahNumber: verse.surahNumber,
                            fromAyah: verse.numberInSurah,
                            toAyah: verse.numberInSurah,
                          );
                      if (!mounted) {
                        return;
                      }
                      _toast(message);
                    },
                  ),
                  _action(
                    icon: Icons.copy,
                    labelKey: 'copy',
                    onTap: () async {
                      final message = context.tr('copied');
                      await Clipboard.setData(
                        ClipboardData(
                          text:
                              '${verse.text}\n﴿ ${verse.surahNameAr} — '
                              '${verse.numberInSurah} ﴾',
                        ),
                      );
                      if (!mounted) {
                        return;
                      }
                      _toast(message);
                    },
                  ),
                  _action(
                    icon: Icons.share,
                    labelKey: 'share_text',
                    onTap: () => AyahSharing.shareText(verse),
                  ),
                  _action(
                    icon: Icons.image,
                    labelKey: 'share_image',
                    onTap: _shareImage,
                  ),
                  _action(
                    icon: Icons.videocam_outlined,
                    labelKey: 'video_studio',
                    onTap: () {
                      Navigator.of(context).pop();
                      AyahVideoStudioPage.open(
                        context,
                        surahNumber: verse.surahNumber,
                        fromVerse: verse.numberInSurah,
                      );
                    },
                  ),
                ],
              ),
              if (isBookmarked) ...[
                const Divider(height: 32),
                Text(
                  context.tr('bookmark_tag'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final tag in BookmarkTag.values)
                      ChoiceChip(
                        selected: _bookmark?.tag == tag,
                        onSelected: (_) => _setTag(tag),
                        label: Text(context.tr('bookmark_tag_${tag.name}')),
                      ),
                  ],
                ),
                if ((_bookmark?.note ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _bookmark!.note,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String labelKey,
    required VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 104,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: colorScheme.primary, size: 24),
              const SizedBox(height: 8),
              Text(
                context.tr(labelKey),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
