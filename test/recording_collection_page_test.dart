import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/localization/app_localizations.dart';
import 'package:islamic_app/core/theme/app_theme.dart';
import 'package:islamic_app/core/theme/design_tokens.dart';
import 'package:islamic_app/core/utils/arabic_numerals.dart';
import 'package:islamic_app/features/broadcasts/domain/recording.dart';
import 'package:islamic_app/features/broadcasts/presentation/pages/recording_collection_page.dart';
import 'package:islamic_app/features/broadcasts/presentation/providers/recordings_provider.dart';
import 'package:islamic_app/features/quran/presentation/providers/quran_audio_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _collection = RecordingCollection(
  id: 'test-nights',
  titleAr: 'تراويح الاختبار',
  reciterAr: 'إمام الاختبار',
  category: RecordingCategory.taraweeh,
  source: RecordingSource.archive,
  identifier: 'test-nights',
  layout: TrackLayout.night,
);

final _tracks = [
  for (var i = 0; i < 40; i++)
    RecordingTrack(
      id: 't$i',
      titleAr: 'التسجيل ${i + 1}',
      url: 'https://example.com/$i.mp3',
      subtitleAr: 'جزء ${i + 1}',
      group: 'الليلة ${(i ~/ 4) + 1}',
      order: i,
    ),
];

class _SilentPlayer extends Fake implements AudioPlayer {
  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Duration? get duration => Duration.zero;
}

class _RecordingPlaySpy extends RecordingsController {
  _RecordingPlaySpy({RecordingsState seed = const RecordingsState()})
    : _seed = seed;

  final RecordingsState _seed;
  final playCalls =
      <
        ({
          RecordingCollection collection,
          List<RecordingTrack> tracks,
          int index,
        })
      >[];

  @override
  RecordingsState build() => _seed;

  @override
  Future<void> play(
    RecordingCollection collection,
    List<RecordingTrack> tracks,
    int index,
  ) async {
    playCalls.add((collection: collection, tracks: tracks, index: index));
  }

  @override
  Future<void> stop() async {
    state = const RecordingsState();
  }
}

Widget _wrap(_RecordingPlaySpy spy) {
  return ProviderScope(
    overrides: [
      recordingTracksProvider.overrideWith((ref, id) async => _tracks),
      recordingsProvider.overrideWith(() => spy),
      quranAudioPlayerProvider.overrideWithValue(_SilentPlayer()),
    ],
    child: MaterialApp(
      theme: AppTheme.from(AppTokens.light),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RecordingCollectionPage(collection: _collection),
    ),
  );
}

Future<_RecordingPlaySpy> _pump(
  WidgetTester tester, {
  RecordingsState? playback,
}) async {
  final spy = _RecordingPlaySpy(seed: playback ?? const RecordingsState());
  await tester.pumpWidget(_wrap(spy));
  await tester.pumpAndSettle();
  return spy;
}

String _shown(String text) => localizeDigitsFor('ar', text);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'a long collection shows a search field that folds Arabic digits',
    (tester) async {
      await _pump(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text(AppLocalizations.translate('ar', 'recordings_search_hint')),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '٢٧');
      await tester.pumpAndSettle();

      expect(find.text(_shown('التسجيل 27')), findsOneWidget);
      expect(find.text(_shown('التسجيل 1')), findsNothing);
      expect(
        find.text(AppLocalizations.translate('ar', 'recordings_search_empty')),
        findsNothing,
      );
    },
  );

  testWidgets('a group chip filters the list to that night', (tester) async {
    await _pump(tester);

    expect(find.byType(ChoiceChip), findsWidgets);
    expect(
      find.widgetWithText(ChoiceChip, AppLocalizations.translate('ar', 'all')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ChoiceChip, _shown('الليلة 3')));
    await tester.pumpAndSettle();

    expect(find.text(_shown('التسجيل 9')), findsOneWidget);
    expect(find.text(_shown('التسجيل 12')), findsOneWidget);
    expect(find.text(_shown('التسجيل 1')), findsNothing);
    expect(find.text(_shown('التسجيل 13')), findsNothing);
  });

  testWidgets('tapping a filtered row plays the full-list index', (
    tester,
  ) async {
    final spy = await _pump(tester);

    await tester.enterText(find.byType(TextField), '٢٧');
    await tester.pumpAndSettle();

    await tester.tap(find.text(_shown('التسجيل 27')));
    await tester.pumpAndSettle();

    expect(spy.playCalls, hasLength(1));
    expect(spy.playCalls.single.index, 26);
    expect(spy.playCalls.single.tracks, _tracks);
    expect(spy.playCalls.single.tracks.length, 40);
    expect(spy.playCalls.single.collection.id, _collection.id);
  });

  testWidgets('the player bar shows a stop button for the current track', (
    tester,
  ) async {
    await _pump(
      tester,
      playback: RecordingsState(
        collection: _collection,
        tracks: _tracks,
        index: 0,
        playing: true,
      ),
    );

    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(
      find.byTooltip(AppLocalizations.translate('ar', 'stop')),
      findsOneWidget,
    );
  });
}
