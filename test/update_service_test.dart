import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/update_service.dart';

void main() {
  Map<String, dynamic> release({required List<Map<String, dynamic>> assets}) {
    return {
      'tag_name': 'apk-latest',
      'name': 'Latest development APK (1.1.0+88)',
      'body': 'Rolling build',
      'html_url': 'https://github.com/if12is/islamic-app/releases/tag/apk-latest',
      'assets': assets,
    };
  }

  Map<String, dynamic> apk(String name, {int size = 40}) {
    return {
      'name': name,
      'size': size * 1000000,
      'browser_download_url': 'https://example.com/$name',
    };
  }

  test('picks the APK for this phone instead of the fat file', () {
    final parsed = UpdateService.parseRelease(
      release(
        assets: [
          apk('islamic-app-1.1.0-build88.apk', size: 150),
          apk('islamic-app-1.1.0-build88-armeabi-v7a.apk', size: 48),
          apk('islamic-app-1.1.0-build88-arm64-v8a.apk', size: 52),
          apk('islamic-app-latest-arm64-v8a.apk', size: 52),
        ],
      ),
      preferredAbis: const ['arm64-v8a', 'armeabi-v7a'],
    );

    expect(parsed, isNotNull);
    expect(parsed!.apkUrl, endsWith('islamic-app-1.1.0-build88-arm64-v8a.apk'));
    expect(parsed.apkBytes, 52000000);
    expect(parsed.buildNumber, 88);
    expect(parsed.versionName, '1.1.0');
  });

  test('falls back to a versioned APK when no ABI match exists', () {
    final parsed = UpdateService.parseRelease(
      release(
        assets: [
          apk('islamic-app-latest.apk', size: 150),
          apk('islamic-app-1.1.0-build88.apk', size: 150),
        ],
      ),
      preferredAbis: const ['arm64-v8a'],
    );

    expect(parsed!.apkUrl, endsWith('islamic-app-1.1.0-build88.apk'));
    expect(parsed.buildNumber, 88);
  });

  test('a higher build number is the only thing that counts as newer', () {
    const release = AppRelease(
      versionName: '1.1.0',
      buildNumber: 90,
      notes: '',
      pageUrl: '',
      apkUrl: 'https://example.com/app.apk',
      apkBytes: 1,
    );

    expect(UpdateService.isNewer(release, 89), isTrue);
    expect(UpdateService.isNewer(release, 90), isFalse);
    expect(UpdateService.isNewer(release, 91), isFalse);
  });

  test('formats a size someone can weigh against their data', () {
    expect(UpdateService.formatBytes(52 * 1000000), '52.0 MB');
    expect(UpdateService.formatBytes(0), '');
  });
}
