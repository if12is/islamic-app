package com.islamicapp.islamic_app.alarms

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.islamicapp.islamic_app.MainActivity
import com.islamicapp.islamic_app.R

/**
 * Shows one planned alert, with no Flutter engine running.
 *
 * The channels themselves are still created by the app on the Dart side, with
 * the adhan the user chose frozen into each one — so the sound, the vibration
 * and whether the user has silenced this category are all decided by the
 * channel this posts to, exactly as before.
 */
object AlarmNotifier {
    const val EXTRA_PAYLOAD = "notification_payload"
    const val EXTRA_ACTION = "notification_action"

    fun show(context: Context, item: PlanItem) {
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

        try {
            manager.notify(item.id, builder.build())
        } catch (error: SecurityException) {
            // Notifications turned off entirely: nothing to do here, and the
            // app's own checks already report it on screen.
        }
    }

    fun dismiss(context: Context, id: Int) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.cancel(id)
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
            if (item != null) {
                data = android.net.Uri.parse(
                    "prayer-alert://${item.id}/${actionId ?: "open"}"
                )
            }
        }
        return PendingIntent.getActivity(
            context,
            (item?.id ?: 0) + (actionId?.hashCode() ?: 0),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Whether a channel exists and is not silenced, for the doctor screen. */
    fun channelBlocked(context: Context, channelId: String): Boolean {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return false
        val channel = manager.getNotificationChannel(channelId) ?: return false
        return channel.importance == NotificationManager.IMPORTANCE_NONE
    }
}
