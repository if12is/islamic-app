import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../data/playlist_store.dart';
import '../../data/services/quran_local_service.dart';
import '../providers/surah_audio_provider.dart';
import 'now_playing_page.dart';

/// Listening lists: a run of surahs to put on and leave on.
///
/// One list can be marked as the daily listening wird, which is the only one
/// the app ever asks about — a screen that nags about six lists is a screen
/// people stop opening.
class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PlaylistsPage()));
  }

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  final PlaylistStore _store = PlaylistStore();
  List<Playlist> _playlists = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Finishing a list is the one thing worth recording, and only the
    // controller knows when the last surah ran out.
    ref.read(surahAudioProvider.notifier).onPlaylistFinished((id) async {
      await _store.markPlayed(id);
      if (mounted) {
        await _load();
      }
    });
  }

  Future<void> _load() async {
    final playlists = await _store.all();
    if (mounted) {
      setState(() {
        _playlists = playlists;
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final name = await _askName(context.tr('playlist_new'), '');
    if (name == null || name.isEmpty) {
      return;
    }
    final playlist = Playlist(
      id: PlaylistStore.mintId(DateTime.now()),
      name: name,
      surahs: const [],
    );
    await _store.save(playlist);
    await _load();
    if (mounted) {
      await _edit(playlist);
    }
  }

  Future<String?> _askName(String title, String initial) async {
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: dialogContext.tr('playlist_name_hint'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(dialogContext.tr('cancel')),
              ),
              FilledButton(
                onPressed:
                    () =>
                        Navigator.of(dialogContext).pop(controller.text.trim()),
                child: Text(dialogContext.tr('save')),
              ),
            ],
          ),
    );
    controller.dispose();
    return name;
  }

  Future<void> _edit(Playlist playlist) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PlaylistEditorPage(playlist: playlist, store: _store),
      ),
    );
    await _load();
  }

  Future<void> _play(Playlist playlist) async {
    if (playlist.isEmpty) {
      return;
    }
    await ref
        .read(surahAudioProvider.notifier)
        .playQueue(playlist.surahs, playlistId: playlist.id);
    if (mounted) {
      await NowPlayingPage.open(context);
    }
  }

  Future<void> _delete(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(dialogContext.tr('playlist_delete')),
            content: Text(playlist.name),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(dialogContext.tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(dialogContext.tr('delete')),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await _store.delete(playlist.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppScaffold(
      title: 'playlists',
      showBack: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(context.tr('playlist_new')),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : ListView(
                padding: AppScaffold.scrollPadding,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      context.tr('playlists_desc'),
                      style: AppTextStyles.caption(
                        context,
                        color: tokens.inkMuted,
                      ),
                    ),
                  ),
                  if (_playlists.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Text(
                        context.tr('playlists_empty'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption(
                          context,
                          color: tokens.inkFaint,
                        ),
                      ),
                    ),
                  for (final playlist in _playlists)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _row(playlist, tokens),
                    ),
                ],
              ),
    );
  }

  Widget _row(Playlist playlist, AppTokens tokens) {
    final doneToday = playlist.doneOn(DateTime.now());

    return AppCard(
      onTap: () => _edit(playlist),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconButton(
            tooltip: context.tr('play'),
            onPressed: playlist.isEmpty ? null : () => _play(playlist),
            icon: Icon(
              Icons.play_circle_fill_rounded,
              size: 34,
              color: playlist.isEmpty ? tokens.inkFaint : tokens.brand,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(context, fontSize: 15),
                      ),
                    ),
                    if (playlist.isDailyWird) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        doneToday
                            ? Icons.check_circle
                            : Icons.brightness_1_outlined,
                        size: 14,
                        color: doneToday ? tokens.brand : tokens.gold,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  playlist.isEmpty
                      ? context.tr('playlist_empty')
                      : '${playlist.surahs.length} '
                          '${context.tr('surah_word')}'
                          '${playlist.isDailyWird ? ' · ${context.tr('playlist_daily')}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(context, color: tokens.inkFaint),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('delete'),
            onPressed: () => _delete(playlist),
            icon: Icon(Icons.delete_outline, size: 20, color: tokens.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// Building a list: search the Mushaf, tap to add, drag to reorder.
class _PlaylistEditorPage extends StatefulWidget {
  const _PlaylistEditorPage({required this.playlist, required this.store});

  final Playlist playlist;
  final PlaylistStore store;

  @override
  State<_PlaylistEditorPage> createState() => _PlaylistEditorPageState();
}

class _PlaylistEditorPageState extends State<_PlaylistEditorPage> {
  final TextEditingController _search = TextEditingController();
  late Playlist _playlist = widget.playlist;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _persist(Playlist next) async {
    setState(() => _playlist = next);
    await widget.store.save(next);
  }

  List<QuranSurahInfo> get _matches {
    final all = QuranLocalService.surahs();
    if (_query.trim().isEmpty) {
      return all;
    }
    return QuranLocalService.searchSurahs(_query);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        _playlist.name,
        style: AppTextStyles.display(context, fontSize: 18, color: tokens.ink),
      ),
      body: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
            ),
            value: _playlist.isDailyWird,
            onChanged:
                (value) => _persist(_playlist.copyWith(isDailyWird: value)),
            title: Text(
              context.tr('playlist_daily'),
              style: AppTextStyles.body(context),
            ),
            subtitle: Text(
              context.tr('playlist_daily_desc'),
              style: AppTextStyles.caption(context, color: tokens.inkFaint),
            ),
          ),
          if (_playlist.surahs.isNotEmpty)
            SizedBox(
              height: 46,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                itemCount: _playlist.surahs.length,
                // onReorderItem, not onReorder: it hands back an index already
                // adjusted for the removal, so the off-by-one correction the
                // old callback needed is gone.
                onReorderItem: (from, to) {
                  final surahs = [..._playlist.surahs];
                  surahs.insert(to, surahs.removeAt(from));
                  _persist(_playlist.copyWith(surahs: surahs));
                },
                itemBuilder: (context, index) {
                  final number = _playlist.surahs[index];
                  return ReorderableDragStartListener(
                    key: ValueKey('$index-$number'),
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: InputChip(
                        label: Text(QuranLocalService.surahInfo(number).nameAr),
                        onDeleted: () {
                          final surahs = [..._playlist.surahs]..removeAt(index);
                          _persist(_playlist.copyWith(surahs: surahs));
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: GlassSearchField(
              controller: _search,
              hintText: context.tr('search_surah_hint'),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: AppScaffold.scrollPadding,
              itemCount: _matches.length,
              itemBuilder: (context, index) {
                final info = _matches[index];
                // A surah can appear twice on purpose — repeating al-Mulk at
                // the end of a list is a normal thing to want.
                final count =
                    _playlist.surahs.where((n) => n == info.id).length;

                return AppListRow(
                  dense: true,
                  badge: '${info.id}',
                  title: context.isAppRtl ? info.nameAr : info.nameEn,
                  meta:
                      '${info.versesCount} ${context.tr('verses')}'
                      '${count > 0 ? ' · ×$count' : ''}',
                  trailing: Icon(
                    Icons.add_circle_outline,
                    size: 20,
                    color: tokens.brand,
                  ),
                  onTap:
                      () => _persist(
                        _playlist.copyWith(
                          surahs: [..._playlist.surahs, info.id],
                        ),
                      ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
