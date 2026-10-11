package com.islamicapp.islamic_app.alarms

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.islamicapp.islamic_app.MainActivity
import com.islamicapp.islamic_app.R

/**
 * Shows one planned alert, with no Flutter engine running.
 *
 * From Android 8 the channels decide the sound: they are created by the app
 * on the Dart side, with the adhan the user chose frozen into each one — so
 * the sound, the vibration and whether the user has silenced this category
 * are all decided by the channel this posts to, exactly as before. Android 7
 * has no channels and ignores the id, so there the alert carries its own
 * sound and vibration, as the notification plugin's did.
 */
object AlarmNotifier {
    const val EXTRA_PAYLOAD = "notification_payload"
    const val EXTRA_ACTION = "notification_action"
    const val EXTRA_NOTIFICATION_ID = "notification_id"

    private val adhanVibration = longArrayOf(0, 600, 400, 600, 400, 600)

    /** Post [item]. False when the system refused it outright. */
    fun show(context: Context, item: PlanItem): Boolean {
        val manager = NotificationManagerCompat.from(context)

        val builder = NotificationCompat.Builder(context, item.channel)
            .setSmallIcon(R.drawable.ic_stat_fajr)
            .setContentTitle(item.title)
            .setContentText(item.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(item.body))
            .setAutoCancel(true)
            .setWhen(item.at)
            .setShowWhen(true)
            .setContentIntent(openAppPending(context, item))
            .setCategory(
                if (item.alarm) NotificationCompat.CATEGORY_ALARM
                else NotificationCompat.CATEGORY_REMINDER
            )
            .setPriority(
                if (item.silent) NotificationCompat.PRIORITY_LOW
                else NotificationCompat.PRIORITY_HIGH
            )
            .setVisibility(
                if (item.silent) NotificationCompat.VISIBILITY_SECRET
                else NotificationCompat.VISIBILITY_PUBLIC
            )

        if (item.silent) {
            builder.setSilent(true)
        } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            soundFor(context, item.sound)?.let { sound ->
                builder.setSound(
                    sound,
                    if (item.alarm) AudioManager.STREAM_ALARM else AudioManager.STREAM_NOTIFICATION,
                )
            }
            if (item.vibrate) {
                builder.setVibrate(adhanVibration)
            }
        }

        // The adhan is what the user is waiting for, so on a locked screen it
        // asks for the screen rather than the shade. Android only honours this
        // for an app allowed to use it; where it is not, it is simply ignored.
        if (item.fullScreen) {
            builder.setFullScreenIntent(openAppPending(context, item), true)
        }

        for (action in item.actions) {
            builder.addAction(
                NotificationCompat.Action.Builder(
                    0,
                    action.label,
                    openAppPending(context, item, action.id),
                ).build()
            )
        }

        return try {
            manager.notify(item.id, builder.build())
            true
        } catch (error: SecurityException) {
            // Notifications turned off entirely, on a version that says so.
            false
        }
    }

    /** `raw:<name>`, a content URI, `default`, or nothing. */
    private fun soundFor(context: Context, sound: String): Uri? = when {
        sound.isEmpty() -> null
        sound == "default" -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        sound.startsWith("raw:") -> {
            val name = sound.removePrefix("raw:")
            val res = context.resources.getIdentifier(name, "raw", context.packageName)
            if (res == 0) null
            else Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://${context.packageName}/$res")
        }
        else -> Uri.parse(sound)
    }

    fun dismiss(context: Context, id: Int) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.cancel(id)
    }

    fun notificationsEnabled(context: Context): Boolean =
        NotificationManagerCompat.from(context).areNotificationsEnabled()

    /**
     * Whether an alert on [channelId] would actually reach the user: the app
     * may post at all, and that kind of alert has not been switched off.
     */
    fun canReachUser(context: Context, channelId: String): Boolean {
        if (!notificationsEnabled(context)) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return true
        val channel = manager.getNotificationChannel(channelId) ?: return false
        return channel.importance != NotificationManager.IMPORTANCE_NONE
    }

    /** Opens the app, carrying what was tapped so the right screen comes up. */
    fun openAppPending(
        context: Context,
        item: PlanItem? = null,
        actionId: String? = null,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            item?.payload?.let { putExtra(EXTRA_PAYLOAD, it) }
            actionId?.let { putExtra(EXTRA_ACTION, it) }
            // An action button does not dismiss its notification by itself
            // the way a tap on the body does; the activity does it on arrival.
            if (item != null) {
                putExtra(EXTRA_NOTIFICATION_ID, item.id)
                data = Uri.parse("prayer-alert://${item.id}/${actionId ?: "open"}")
            }
        }
        return PendingIntent.getActivity(
            context,
            (item?.id ?: 0) + (actionId?.hashCode() ?: 0),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
