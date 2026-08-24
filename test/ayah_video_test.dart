import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/video_encode_plan.dart';
import 'package:islamic_app/features/quran/domain/ayah_video_spec.dart';

void main() {
  group('The running order of a video', () {
    test('each verse holds the screen for its own recitation', () {
      final timeline = VideoTimeline.fromDurations({
        1: const Duration(seconds: 4),
        2: const Duration(milliseconds: 2500),
        3: const Duration(seconds: 9),
      });

      expect(timeline.total, const Duration(milliseconds: 15500));
      expect(timeline.verseAt(Duration.zero), 1);
      expect(timeline.verseAt(const Duration(milliseconds: 3999)), 1);
      expect(timeline.verseAt(const Duration(seconds: 4)), 2);
      expect(timeline.verseAt(const Duration(seconds: 7)), 3);
    });

    test('past the end it stays on the last verse rather than going blank', () {
      final timeline = VideoTimeline.fromDurations({
        5: const Duration(seconds: 3),
        6: const Duration(seconds: 3),
      });
      expect(timeline.verseAt(const Duration(minutes: 1)), 6);
    });

    test('an unmeasurable verse still gets a turn', () {
      // Dropping it would silently skip an ayah, which is far worse than
      // holding on it a moment too long.
      final timeline = VideoTimeline.fromDurations({
        1: const Duration(seconds: 4),
        2: null,
        3: Duration.zero,
      }, fallback: const Duration(seconds: 6));

      expect(timeline.segments.length, 3);
      expect(timeline.segments[1].duration, const Duration(seconds: 6));
      expect(
        timeline.segments[2].duration,
        const Duration(seconds: 6),
        reason: 'a zero-length probe is a failure, not a measurement',
      );
    });

    test('a nonsense measurement is refused', () {
      final timeline = VideoTimeline.fromDurations({
        1: const Duration(hours: 2),
      });
      expect(timeline.segments.single.duration, const Duration(seconds: 6));
    });

    test('verses run in order however the map was built', () {
      final timeline = VideoTimeline.fromDurations({
        9: const Duration(seconds: 1),
        7: const Duration(seconds: 1),
        8: const Duration(seconds: 1),
      });
      expect(timeline.segments.map((segment) => segment.verseNumber), [
        7,
        8,
        9,
      ]);
      expect(timeline.starts, [
        Duration.zero,
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
    });

    test('an empty timeline answers rather than throwing', () {
      expect(VideoTimeline.empty.verseAt(Duration.zero), isNull);
      expect(VideoTimeline.empty.total, Duration.zero);
    });
  });

  group('The composition spec', () {
    const spec = AyahVideoSpec(
      surahNumber: 53,
      fromVerse: 24,
      toVerse: 26,
      reciterCode: 'ar.ahmedajamy',
    );

    test('knows its own passage', () {
      expect(spec.verseCount, 3);
      expect(spec.verseNumbers, [24, 25, 26]);
      expect(spec.isTooLong, isFalse);
    });

    test('a range dragged backwards is put the right way round', () {
      final flipped = spec.copyWith(fromVerse: 30, toVerse: 20);
      expect(flipped.fromVerse, 30);
      expect(flipped.toVerse, 30, reason: 'never an empty passage');
    });

    test('type size stays inside what the canvas can set', () {
      expect(spec.copyWith(fontSize: 5).fontSize, AyahVideoSpec.minFontSize);
      expect(spec.copyWith(fontSize: 900).fontSize, AyahVideoSpec.maxFontSize);
    });

    test('a passage past the limit is refused, not silently truncated', () {
      final long = spec.copyWith(toVerse: 24 + AyahVideoSpec.maxVerses);
      expect(long.isTooLong, isTrue);
    });

    test('the file name says which verses are in it', () {
      expect(spec.fileStem('an-najm'), 'an-najm_24-26');
      expect(spec.copyWith(toVerse: 24).fileStem('an-najm'), 'an-najm_24');
    });
  });

  group('Choosing a type size without being asked', () {
    test('the longest verse decides, not the average', () {
      final short = AyahVideoSpec.suggestedFontSize([
        'قُلْ هُوَ اللَّهُ أَحَدٌ',
      ]);
      final mixed = AyahVideoSpec.suggestedFontSize([
        'قُلْ هُوَ اللَّهُ أَحَدٌ',
        'x' * 700,
      ]);
      expect(mixed, lessThan(short));
    });

    test('a square gets smaller type than a story for the same text', () {
      final text = ['y' * 250];
      expect(
        AyahVideoSpec.suggestedFontSize(text, aspect: VideoAspect.square),
        lessThan(
          AyahVideoSpec.suggestedFontSize(text, aspect: VideoAspect.portrait),
        ),
      );
    });

    test('never leaves the range the slider can reach', () {
      for (final length in [1, 40, 200, 900, 5000]) {
        for (final aspect in VideoAspect.values) {
          final size = AyahVideoSpec.suggestedFontSize([
            'z' * length,
          ], aspect: aspect);
          expect(size, greaterThanOrEqualTo(AyahVideoSpec.minFontSize));
          expect(size, lessThanOrEqualTo(AyahVideoSpec.maxFontSize));
        }
      }
    });

    test('an empty passage does not divide by zero', () {
      expect(AyahVideoSpec.suggestedFontSize(const []), greaterThan(0));
    });
  });

  group('What is handed to the encoder', () {
    final timeline = VideoTimeline.fromDurations({
      1: const Duration(milliseconds: 4200),
      2: const Duration(milliseconds: 3100),
    });

    test('the last frame is listed twice, or the video ends early', () {
      // The concat demuxer ignores the duration of its final entry. Without
      // the repeat the closing verse flashes past in a single frame.
      final list = VideoEncodePlan.frameList(timeline, {
        1: '/tmp/f000.png',
        2: '/tmp/f001.png',
      });

      expect('file '.allMatches(list).length, 3);
      expect(list, contains('duration 4.200'));
      expect(list, contains('duration 3.100'));
      expect(list.trim().split('\n').last, "file '/tmp/f001.png'");
    });

    test('a verse with no frame is skipped in both lists together', () {
      final frames = VideoEncodePlan.frameList(timeline, {2: '/tmp/f001.png'});
      final audio = VideoEncodePlan.audioList(timeline, {2: '/tmp/a001.mp3'});

      expect('file '.allMatches(frames).length, 2);
      expect('file '.allMatches(audio).length, 1);
    });

    test('the command asks for what every player can actually open', () {
      final command = VideoEncodePlan.command(
        frameListPath: '/tmp/frames.txt',
        audioListPath: '/tmp/audio.txt',
        outputPath: '/tmp/out.mp4',
        aspect: VideoAspect.portrait,
        total: const Duration(seconds: 12),
      );

      // yuv420p and H.264/AAC are the combination that plays in WhatsApp
      // rather than showing a black rectangle.
      expect(command, contains('format=yuv420p'));
      expect(command, contains('-c:v libx264'));
      expect(command, contains('-c:a aac'));
      expect(command, contains('+faststart'));
      expect(command, contains('1080:1920'));
      expect(command, contains('-shortest'));
    });

    test('the fade never starts before the video does', () {
      final command = VideoEncodePlan.command(
        frameListPath: '/tmp/frames.txt',
        audioListPath: '/tmp/audio.txt',
        outputPath: '/tmp/out.mp4',
        aspect: VideoAspect.square,
        total: const Duration(milliseconds: 200),
      );
      expect(command, contains('fade=t=out:st=0.00'));
      expect(command, isNot(contains('st=-')));
    });
  });
}
