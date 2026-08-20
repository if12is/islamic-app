package com.islamicapp.islamic_app

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
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
            else -> result.notImplemented()
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
