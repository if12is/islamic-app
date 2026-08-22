package com.islamicapp.islamic_app

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.PowerManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import android.speech.RecognizerIntent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Extends AudioServiceActivity so Quran recitation keeps playing in the
 * background with lock-screen and headset controls (just_audio_background).
 *
 * Also hosts the adhan-sound channel: Android will only play a notification
 * sound it can read itself, so a file the user picks is copied into the shared
 * MediaStore notifications collection and referenced by its content:// URI.
 */
class MainActivity : AudioServiceActivity() {

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleCall(call, result) }
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "importAudioFile" -> startImport(result)
            "pickSystemSound" -> startSystemPicker(result)
            "soundTitle" -> result.success(titleFor(call.argument<String>("uri")))
            "openSpeechSettings" -> result.success(openSpeechSettings())
            "isIgnoringBatteryOptimizations" ->
                result.success(isIgnoringBatteryOptimizations())
            "requestIgnoreBatteryOptimizations" ->
                result.success(requestIgnoreBatteryOptimizations())
            "openAppNotificationSettings" ->
                result.success(openAppNotificationSettings())
            "openAutostartSettings" -> result.success(openAutostartSettings())
            "deviceManufacturer" -> result.success(Build.MANUFACTURER ?: "")
            else -> result.notImplemented()
        }
    }

    /**
     * Open wherever this device lets someone add an offline voice pack.
     *
     * There is no single Android screen for it: some builds expose voice input
     * settings, some only the Google app's own speech settings, and some
     * neither. So the candidates are tried in order of usefulness and the
     * first one that resolves wins; the plain Settings app is the last resort,
     * which is still better than a dead button.
     */
    private fun openSpeechSettings(): Boolean {
        val candidates = listOf(
            Intent("com.android.settings.TTS_SETTINGS"),
            Intent(Settings.ACTION_VOICE_INPUT_SETTINGS),
            Intent(RecognizerIntent.ACTION_VOICE_SEARCH_HANDS_FREE),
            Intent(Settings.ACTION_INPUT_METHOD_SETTINGS),
            Intent(Settings.ACTION_SETTINGS),
        )

        for (intent in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                return try {
                    startActivity(intent)
                    true
                } catch (error: Exception) {
                    continue
                }
            }
        }
        return false
    }

    /**
     * Whether the system has stopped putting this app to sleep.
     *
     * This is the single biggest reason a scheduled adhan never sounds: Android
     * doze, and the far more aggressive vendor layers on top of it, drop exact
     * alarms for apps they consider idle. Nothing in the app can override that;
     * it can only ask, and then say plainly whether the answer was yes.
     */
    private fun isIgnoringBatteryOptimizations(): Boolean {
        val power = getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return false
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        if (isIgnoringBatteryOptimizations()) return true
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$packageName")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (error: Exception) {
            // Some builds hide this dialog; the settings list is the fallback.
            openIntent(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
    }

    private fun openAppNotificationSettings(): Boolean {
        return openIntent(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        ) || openIntent(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:$packageName"))
        )
    }

    /**
     * Open the vendor screen that decides whether this app may start itself.
     *
     * Xiaomi, Oppo, Vivo, Huawei and Samsung each keep their own list, none of
     * them reachable through a documented Android intent. An app left off that
     * list is force-stopped, and a force-stopped app has no alarms at all — so
     * these are worth trying even though every one of them is a guess.
     */
    private fun openAutostartSettings(): Boolean {
        val candidates = listOf(
            // Honor, since it split from Huawei: its own system manager, with
            // the startup list under a package of its own.
            Intent().setClassName(
                "com.hihonor.systemmanager",
                "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
            ),
            Intent().setClassName(
                "com.hihonor.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
            ),
            Intent().setClassName(
                "com.hihonor.systemmanager",
                "com.hihonor.systemmanager.optimize.process.ProtectActivity"
            ),
            // Huawei, and older Honor builds that still ship Huawei's manager.
            Intent().setClassName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
            ),
            Intent().setClassName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.optimize.process.ProtectActivity"
            ),
            // OnePlus: OxygenOS calls it "chain launch". Newer builds fold it
            // into the Oppo security centre, since the two now share a base.
            Intent().setClassName(
                "com.oneplus.security",
                "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
            ),
            Intent().setClassName(
                "com.oneplus.security",
                "com.oneplus.security.chainlaunch.view.ChainLaunchAppListAlarmActivity"
            ),
            // Xiaomi / Redmi / POCO
            Intent().setClassName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity"
            ),
            // Oppo / Realme — also the fallback for recent OnePlus.
            Intent().setClassName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.startupapp.StartupAppListActivity"
            ),
            Intent().setClassName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.permission.startup.StartupAppListActivity"
            ),
            Intent().setClassName(
                "com.oppo.safe",
                "com.oppo.safe.permission.startup.StartupAppListActivity"
            ),
            // Vivo
            Intent().setClassName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
            ),
            Intent().setClassName(
                "com.iqoo.secure",
                "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"
            ),
            // Samsung
            Intent().setClassName(
                "com.samsung.android.lool",
                "com.samsung.android.sm.ui.battery.BatteryActivity"
            ),
            // Letv, Asus and friends fall back to the app's own settings page.
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:$packageName")),
        )

        for (intent in candidates) {
            if (openIntent(intent)) return true
        }
        return false
    }

    /** Start [intent] if anything on this device can handle it. */
    private fun openIntent(intent: Intent): Boolean {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val resolved = packageManager.queryIntentActivities(
            intent,
            PackageManager.MATCH_DEFAULT_ONLY
        )
        if (resolved.isEmpty()) return false
        return try {
            startActivity(intent)
            true
        } catch (error: Exception) {
            false
        }
    }

    private fun startImport(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error(
                "unsupported",
                "Importing an adhan file needs Android 10 or newer",
                null
            )
            return
        }
        if (!claimPending(result)) return

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
        }
        startActivityForResult(intent, REQUEST_IMPORT)
    }

    private fun startSystemPicker(result: MethodChannel.Result) {
        if (!claimPending(result)) return

        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(
                RingtoneManager.EXTRA_RINGTONE_TYPE,
                RingtoneManager.TYPE_NOTIFICATION
            )
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, false)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
        }
        startActivityForResult(intent, REQUEST_PICK)
    }

    /** Only one picker can be open at a time. */
    private fun claimPending(result: MethodChannel.Result): Boolean {
        if (pendingResult != null) {
            result.error("busy", "Another picker is already open", null)
            return false
        }
        pendingResult = result
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != REQUEST_IMPORT && requestCode != REQUEST_PICK) {
            return
        }

        val result = pendingResult ?: return
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(null)
            return
        }

        when (requestCode) {
            REQUEST_IMPORT -> finishImport(data.data, result)
            REQUEST_PICK -> finishPick(data, result)
        }
    }

    private fun finishImport(source: Uri?, result: MethodChannel.Result) {
        if (source == null) {
            result.success(null)
            return
        }

        try {
            val name = displayNameFor(source) ?: "adhan.mp3"
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DISPLAY_NAME, name)
                put(
                    MediaStore.Audio.Media.MIME_TYPE,
                    contentResolver.getType(source) ?: "audio/mpeg"
                )
                put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
                put(MediaStore.Audio.Media.IS_MUSIC, 0)
                put(
                    MediaStore.Audio.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_NOTIFICATIONS
                )
            }

            val collection =
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val target = contentResolver.insert(collection, values)
            if (target == null) {
                result.error("copy_failed", "Could not create the sound file", null)
                return
            }

            contentResolver.openInputStream(source).use { input ->
                contentResolver.openOutputStream(target).use { output ->
                    if (input == null || output == null) {
                        throw IllegalStateException("Unreadable audio file")
                    }
                    input.copyTo(output)
                }
            }

            result.success(mapOf("uri" to target.toString(), "title" to name))
        } catch (error: Exception) {
            result.error("copy_failed", error.message, null)
        }
    }

    private fun finishPick(data: Intent, result: MethodChannel.Result) {
        val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            data.getParcelableExtra(
                RingtoneManager.EXTRA_RINGTONE_PICKED_URI,
                Uri::class.java
            )
        } else {
            @Suppress("DEPRECATION")
            data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        }

        if (uri == null) {
            result.success(null)
            return
        }

        result.success(
            mapOf("uri" to uri.toString(), "title" to (titleFor(uri.toString()) ?: ""))
        )
    }

    private fun displayNameFor(uri: Uri): String? {
        contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) {
                    return cursor.getString(index)
                }
            }
        }
        return null
    }

    private fun titleFor(uri: String?): String? {
        if (uri.isNullOrEmpty()) return null
        return try {
            RingtoneManager.getRingtone(this, Uri.parse(uri))?.getTitle(this)
        } catch (error: Exception) {
            null
        }
    }

    companion object {
        private const val CHANNEL = "islamic_app/adhan_sound"
        private const val REQUEST_IMPORT = 4201
        private const val REQUEST_PICK = 4202
    }
}
