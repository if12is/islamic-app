import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _gradle() => File('android/app/build.gradle.kts').readAsStringSync();

String _manifest() =>
    File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

void main() {
  group('The app keeps its identity', () {
    test('the application id is the one already installed on phones', () {
      // Android has no notion of a renamed app. A different applicationId is a
      // different app: everyone holding the old build got a second icon and an
      // empty start instead of an update, with their settings, bookmarks,
      // downloads and wird left behind in an app the new one cannot see.
      //
      // That has happened once, moving off `com.islamicapp.islamic_app`.
      // Changing it again would do the same to everyone a second time, so the
      // string is pinned here rather than left to a careless edit.
      expect(
        _gradle(),
        contains('applicationId = "com.if12is.fajr"'),
        reason:
            'Changing the application id orphans every installed copy of the '
            'app, along with everything the reader has saved in it.',
      );
    });

    test('the version code comes from CI, not from a literal', () {
      // The number Android compares to decide whether an APK is an upgrade.
      // It has gone backwards once already — run_number restarts at 1 when the
      // workflow file is renamed — which both hid the update and would have
      // made Android refuse it.
      expect(_gradle(), contains('ANDROID_VERSION_CODE'));
    });
  });

  group('The downloaded update can reach the installer', () {
    test('a provider claims the authority the updater asks for', () {
      // ota_update builds a content URI under `<applicationId>.ota_update_provider`
      // and hands it to Android's installer. With no provider registered for
      // that authority FileProvider throws before the install intent exists,
      // which is why a finished download ended with the app dropping to the
      // home screen and no message at all.
      expect(
        _manifest(),
        contains(r'android:authorities="${applicationId}.ota_update_provider"'),
      );
      expect(_manifest(), contains('sk.fourq.otaupdate.OtaUpdateFileProvider'));
      expect(_manifest(), contains('@xml/ota_file_paths'));
    });

    test('the declared path is where the updater actually writes', () {
      // The plugin writes to getFilesDir()/ota_update. FileProvider refuses —
      // by throwing — any file outside the roots declared here, so the folder
      // in the paths file has to match the folder in the plugin exactly.
      final paths =
          File(
            'android/app/src/main/res/xml/ota_file_paths.xml',
          ).readAsStringSync();

      expect(paths, contains('files-path'));
      expect(paths, contains('ota_update'));
    });

    test('the app may ask to install a package', () {
      expect(
        _manifest(),
        contains('android.permission.REQUEST_INSTALL_PACKAGES'),
      );
    });
  });
}
