import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/update_service.dart';

/// A Dio that answers every request the same way, so the check can be run
/// against a network that is down, rate-limited, or empty.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.status, this.body, this.throwOn});

  final int? status;
  final String? body;
  final DioExceptionType? throwOn;

  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (throwOn != null) {
      throw DioException(requestOptions: options, type: throwOn!);
    }
    return ResponseBody.fromString(
      body ?? '{}',
      status!,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioThat(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(validateStatus: (code) => code == 200));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('A check that could not reach GitHub', () {
    // The bug this exists for: every failure returned null, and the caller
    // read null as "nothing newer", so a phone with no signal was told it was
    // on the latest build for as long as it stayed offline.
    test('throws rather than reporting that there is nothing newer', () async {
      final adapter = _FakeAdapter(throwOn: DioExceptionType.connectionError);

      await expectLater(
        UpdateService.fetchLatest(
          client: _dioThat(adapter),
          preferredAbis: const ['arm64-v8a'],
        ),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.reason,
            'reason',
            UpdateCheckFailure.offline,
          ),
        ),
      );
    });

    test('both addresses are tried before it gives up', () async {
      final adapter = _FakeAdapter(throwOn: DioExceptionType.connectionError);

      await UpdateService.fetchLatest(
        client: _dioThat(adapter),
        preferredAbis: const ['arm64-v8a'],
      ).catchError((Object _) => null);

      // The rolling tag, then the kept versioned release.
      expect(adapter.calls, 2);
    });

    test('a timeout is offline, not a missing release', () async {
      final adapter = _FakeAdapter(throwOn: DioExceptionType.receiveTimeout);

      await expectLater(
        UpdateService.fetchLatest(
          client: _dioThat(adapter),
          preferredAbis: const [],
        ),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.reason,
            'reason',
            UpdateCheckFailure.offline,
          ),
        ),
      );
    });
  });

  group('Naming what actually went wrong', () {
    test('404 is a missing release, not a dead network', () {
      expect(UpdateService.failureFor(404), UpdateCheckFailure.notFound);
    });

    test('403 and 429 are the hourly limit', () {
      expect(UpdateService.failureFor(403), UpdateCheckFailure.rateLimited);
      expect(UpdateService.failureFor(429), UpdateCheckFailure.rateLimited);
    });

    test('a server fault is treated as unreachable', () {
      expect(UpdateService.failureFor(500), UpdateCheckFailure.offline);
      expect(UpdateService.failureFor(503), UpdateCheckFailure.offline);
    });

    test('no status at all is offline', () {
      expect(UpdateService.failureFor(null), UpdateCheckFailure.offline);
    });

    test('every reason has something to say', () {
      for (final reason in UpdateCheckFailure.values) {
        final exception = UpdateCheckException(reason);
        expect(exception.messageKey, startsWith('update_check_'));
      }
    });
  });

  group('A release with nothing to compare', () {
    test('a payload with no version is refused, not read as build 0', () async {
      // Build 0 is never greater than what is installed, so accepting it
      // would report every release as old — the same lie by another route.
      final adapter = _FakeAdapter(
        status: 200,
        body: '{"tag_name":"apk-latest","name":"nightly","assets":[]}',
      );

      await expectLater(
        UpdateService.fetchLatest(
          client: _dioThat(adapter),
          preferredAbis: const [],
        ),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.reason,
            'reason',
            UpdateCheckFailure.unreadable,
          ),
        ),
      );
    });
  });

  group('Finding the build number among the candidates', () {
    Map<String, dynamic> release(
      String name,
      String tag,
      List<String> assetNames,
    ) => {
      'tag_name': tag,
      'name': name,
      'assets': [
        for (final assetName in assetNames)
          {
            'name': assetName,
            'size': 1000,
            'browser_download_url': 'https://example.com/$assetName',
          },
      ],
    };

    test('an asset without one does not stop the search', () {
      // The asset name is checked first, so a filename carrying only the
      // marketing version used to win and set the build number to zero —
      // which reads as "older than what you have" for every release.
      final parsed = UpdateService.parseRelease(
        release('Latest development APK (1.2.0+91)', 'apk-latest', [
          'islamic-app-1.2.0-arm64-v8a.apk',
        ]),
        preferredAbis: const ['arm64-v8a'],
      );

      expect(parsed, isNotNull);
      expect(parsed!.versionName, '1.2.0');
      expect(parsed.buildNumber, 91);
    });

    test('the asset still wins when it carries one', () {
      final parsed = UpdateService.parseRelease(
        release('Latest development APK (1.2.0+91)', 'apk-latest', [
          'islamic-app-1.2.0-build93-arm64-v8a.apk',
        ]),
        preferredAbis: const ['arm64-v8a'],
      );

      expect(parsed!.buildNumber, 93);
    });

    test('with no build number anywhere it is zero and never looks newer', () {
      final parsed = UpdateService.parseRelease(
        release('Release 1.2.0', 'v1.2.0', ['islamic-app-1.2.0.apk']),
      );

      expect(parsed!.buildNumber, 0);
      expect(UpdateService.isNewer(parsed, 0), isFalse);
      expect(UpdateService.isNewer(parsed, 25), isFalse);
    });
  });

  group('The real payload this repository publishes', () {
    test('reads the build number out of the rolling release', () {
      // Exactly what GitHub returned for apk-latest, so a change in the
      // workflow's file naming fails here rather than in someone's hands.
      final parsed = UpdateService.parseRelease(
        {
          'tag_name': 'apk-latest',
          'name': 'Latest development APK (1.1.0+25)',
          'body': '',
          'html_url': 'https://github.com/if12is/islamic-app/releases',
          'assets': [
            {
              'name': 'islamic-app-1.1.0-build25-arm64-v8a.apk',
              'size': 86395177,
              'browser_download_url': 'https://example.com/a.apk',
            },
            {
              'name': 'islamic-app-1.1.0-build25-armeabi-v7a.apk',
              'size': 93235533,
              'browser_download_url': 'https://example.com/b.apk',
            },
            {
              'name': 'islamic-app-latest-arm64-v8a.apk',
              'size': 86395177,
              'browser_download_url': 'https://example.com/c.apk',
            },
          ],
        },
        preferredAbis: const ['arm64-v8a', 'armeabi-v7a'],
      );

      expect(parsed, isNotNull);
      expect(parsed!.versionName, '1.1.0');
      expect(parsed.buildNumber, 25);
      expect(parsed.apkUrl, 'https://example.com/a.apk');
      expect(UpdateService.isNewer(parsed, 24), isTrue);
      expect(UpdateService.isNewer(parsed, 25), isFalse);
    });
  });

  group('The build that is actually published right now', () {
    // Captured from api.github.com/repos/if12is/islamic-app/releases/tags/
    // apk-latest while chasing a report that the check always said "you are
    // up to date". It did — and it was right: the phone held build 30 and 30
    // was the newest published. The parser was never the fault, so this pins
    // that so the next report can be aimed somewhere useful.
    final live = <String, dynamic>{
      'tag_name': 'apk-latest',
      'name': 'Latest development APK (1.1.0+30)',
      'body': '',
      'html_url': 'https://github.com/if12is/islamic-app/releases',
      'assets': [
        {
          'name': 'islamic-app-1.1.0-build30-arm64-v8a.apk',
          'size': 86659118,
          'browser_download_url': 'https://example.com/a.apk',
        },
        {
          'name': 'islamic-app-1.1.0-build30-armeabi-v7a.apk',
          'size': 93532242,
          'browser_download_url': 'https://example.com/b.apk',
        },
        {
          'name': 'islamic-app-latest-arm64-v8a.apk',
          'size': 86659118,
          'browser_download_url': 'https://example.com/c.apk',
        },
        {
          'name': 'islamic-app-latest-armeabi-v7a.apk',
          'size': 93532242,
          'browser_download_url': 'https://example.com/d.apk',
        },
      ],
    };

    test('the build number is read out of the versioned asset', () {
      final parsed = UpdateService.parseRelease(
        live,
        preferredAbis: const ['arm64-v8a', 'armeabi-v7a'],
      );
      expect(parsed!.buildNumber, 30);
      expect(parsed.versionName, '1.1.0');
    });

    test('the unversioned "latest" asset never wins the pick', () {
      // It carries no build number, so choosing it would read as build 0 and
      // report every release as older than what is installed.
      final parsed = UpdateService.parseRelease(
        live,
        preferredAbis: const ['arm64-v8a'],
      );
      expect(parsed!.apkUrl, 'https://example.com/a.apk');
    });

    test('the phone gets the APK built for its own CPU', () {
      final arm32 = UpdateService.parseRelease(
        live,
        preferredAbis: const ['armeabi-v7a'],
      );
      expect(arm32!.apkUrl, 'https://example.com/b.apk');
    });

    test('older builds are offered it, and build 30 is not', () {
      final parsed =
          UpdateService.parseRelease(live, preferredAbis: const ['arm64-v8a'])!;
      for (final installed in [3, 25, 29]) {
        expect(
          UpdateService.isNewer(parsed, installed),
          isTrue,
          reason: 'build $installed should be offered build 30',
        );
      }
      expect(UpdateService.isNewer(parsed, 30), isFalse);
      // A phone ahead of the release — a local build, or a run that published
      // late — is not told to downgrade.
      expect(UpdateService.isNewer(parsed, 31), isFalse);
    });

    test('a release carries a label with both halves in it', () {
      // The screen shows this against the installed one, so a reader can see
      // the comparison rather than being asked to trust it.
      final parsed =
          UpdateService.parseRelease(live, preferredAbis: const ['arm64-v8a'])!;
      expect(parsed.label, '1.1.0 (30)');
    });
  });
}
