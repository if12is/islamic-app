import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../data/bookmark_store.dart';
import '../providers/bookmarks_provider.dart';
import 'notes_page.dart';
import 'surah_reader_page.dart';

/// Everything the reader has saved: bookmarks, memorisation marks, and notes.
class BookmarksPage extends ConsumerStatefulWidget {
  const BookmarksPage({super.key});

  @override
  ConsumerState<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends ConsumerState<BookmarksPage> {
  BookmarkTag? _filter;

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(bookmarksProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('bookmarks')),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: context.tr('my_reflections'),
              icon: const Icon(Icons.edit_note),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const NotesPage()),
              ),
            ),
          ],
        ),
        body: bookmarks.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (items) {
            final filtered = _filter == null
                ? items
                : items.where((item) => item.tag == _filter).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ChoiceChip(
                                selected: _filter == null,
                                onSelected: (_) =>
                                    setState(() => _filter = null),
                                label: Text(context.tr('all')),
                              ),
                              for (final tag in BookmarkTag.values) ...[
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  selected: _filter == tag,
                                  onSelected: (_) =>
                                      setState(() => _filter = tag),
                                  label: Text(
                                    context.tr('bookmark_tag_${tag.name}'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (filtered.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bookmark_border,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('no_bookmarks_yet'),
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
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final bookmark = filtered[index];
                        return _bookmarkTile(bookmark, colorScheme);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bookmarkTile(QuranBookmark bookmark, ColorScheme colorScheme) {
    final tagColor = bookmarkTagColor(bookmark.tag, colorScheme);

    return Dismissible(
      key: ValueKey(bookmark.key),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) {
        ref
            .read(bookmarksProvider.notifier)
            .remove(bookmark.surahNumber, bookmark.verseNumber);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 6,
            height: 44,
            decoration: BoxDecoration(
              color: tagColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          title: Text(
            '${context.tr('surah_word')} ${bookmark.surahName} · '
            '${context.tr('ayah_word')} ${bookmark.verseNumber}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bookmark.preview.isNotEmpty)
                Text(
                  bookmark.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
              if (bookmark.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_note,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bookmark.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SurahReaderPage(
                surahNumber: bookmark.surahNumber,
                initialVerse: bookmark.verseNumber,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
