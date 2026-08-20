import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/bookmark_store.dart';
import '../../data/services/quran_local_service.dart';
import '../providers/bookmarks_provider.dart';
import 'surah_reader_page.dart';

/// Everything the reader has written down, in one place.
///
/// Notes live on bookmarks, so this screen is a filtered view of them — with
/// search, ordering, editing, and a plain-text export the user owns.
class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

enum _NotesOrder { newest, mushaf }

class _NotesPageState extends ConsumerState<NotesPage> {
  final TextEditingController _searchController = TextEditingController();
  _NotesOrder _order = _NotesOrder.newest;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QuranBookmark> _visibleNotes(List<QuranBookmark> all) {
    final needle = QuranLocalService.normalizeArabic(_query);
    final notes =
        all.where((bookmark) {
          if (bookmark.note.trim().isEmpty) {
            return false;
          }
          if (needle.isEmpty) {
            return true;
          }
          return QuranLocalService.normalizeArabic(
                bookmark.note,
              ).contains(needle) ||
              QuranLocalService.normalizeArabic(
                bookmark.surahName,
              ).contains(needle) ||
              QuranLocalService.normalizeArabic(
                bookmark.preview,
              ).contains(needle);
        }).toList();

    if (_order == _NotesOrder.mushaf) {
      notes.sort((a, b) {
        final bySurah = a.surahNumber.compareTo(b.surahNumber);
        return bySurah != 0 ? bySurah : a.verseNumber.compareTo(b.verseNumber);
      });
    } else {
      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return notes;
  }

  Future<void> _export(List<QuranBookmark> notes) async {
    if (notes.isEmpty) {
      return;
    }

    final buffer =
        StringBuffer()
          ..writeln('# ${context.tr('my_reflections')}')
          ..writeln();

    for (final note in notes) {
      final verse = QuranLocalService.verse(note.surahNumber, note.verseNumber);
      buffer
        ..writeln('## ${note.surahName} — ${note.verseNumber}')
        ..writeln()
        ..writeln('> ${verse.text}')
        ..writeln()
        ..writeln(note.note)
        ..writeln()
        ..writeln('---')
        ..writeln();
    }

    await SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  Future<void> _editNote(QuranBookmark bookmark) async {
    final controller = TextEditingController(text: bookmark.note);
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(dialogContext.tr('add_note')),
            content: TextField(
              controller: controller,
              maxLines: 5,
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
      final verse = QuranLocalService.verse(
        bookmark.surahNumber,
        bookmark.verseNumber,
      );
      await ref
          .read(bookmarksProvider.notifier)
          .save(verse: verse, tag: bookmark.tag, note: controller.text.trim());
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(bookmarksProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return AppScaffold(
      showBack: true,
      titleWidget: Text(context.tr('my_reflections')),
      actions: [
        IconButton(
          tooltip: context.tr('sort'),
          icon: const Icon(Icons.swap_vert),
          onPressed:
              () => setState(() {
                _order =
                    _order == _NotesOrder.newest
                        ? _NotesOrder.mushaf
                        : _NotesOrder.newest;
              }),
        ),
        IconButton(
          tooltip: context.tr('export_notes'),
          icon: const Icon(Icons.ios_share),
          onPressed: () => _export(_visibleNotes(bookmarks.value ?? const [])),
        ),
      ],
      body: bookmarks.when(
        loading:
            () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (all) {
          final notes = _visibleNotes(all);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: context.tr('search_notes_hint'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      _order == _NotesOrder.newest
                          ? context.tr('sort_newest')
                          : context.tr('sort_mushaf'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const Spacer(),
                    Text(
                      '${notes.length}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              if (notes.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('no_notes_yet'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder:
                        (context, index) =>
                            _noteCard(notes[index], colorScheme),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _noteCard(QuranBookmark bookmark, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 18,
                decoration: BoxDecoration(
                  color: bookmarkTagColor(bookmark.tag, colorScheme),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${context.tr('surah_word')} ${bookmark.surahName} · '
                  '${context.tr('ayah_word')} ${bookmark.verseNumber}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: context.tr('add_note'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _editNote(bookmark),
              ),
            ],
          ),
          if (bookmark.preview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              bookmark.preview,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 16,
                height: 1.9,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(bookmark.note, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (_) => SurahReaderPage(
                            surahNumber: bookmark.surahNumber,
                            initialVerse: bookmark.verseNumber,
                          ),
                    ),
                  ),
              icon: const Icon(Icons.menu_book, size: 18),
              label: Text(context.tr('open_in_reader')),
            ),
          ),
        ],
      ),
    );
  }
}
