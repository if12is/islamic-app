package com.islamicapp.islamic_app.alarms

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.islamicapp.islamic_app.R
import org.json.JSONArray
import org.json.JSONObject

/**
 * The next prayer, held in the status bar for as long as the user wants it.
 *
 * It is useful on its own — a glance shows which prayer is next and the time
 * left — but the reason it exists is what it does to the app's standing.
 * A vendor battery manager (Honor's above all) force-stops apps it thinks
 * nobody is using, and a force-stopped app loses every alarm it holds: the
 * adhan never sounds, and nothing from inside the app can bring it back. An
 * app running a foreground service is one the user can see working, and
 * those managers leave it alone. So this is opt-in, and it is the strongest
 * protection for the alarms short of the phone's own settings.
 *
 * It does no work of its own. The countdown is the system's chronometer,
 * which ticks without waking the app; the notification is rewritten only when
 * a prayer passes, noticed by the minute tick while the screen is on and by
 * the alarm engine each time an alert fires.
 */
class NextPrayerService : Service() {

    private var ticking: BroadcastReceiver? = null
    private var shownAt = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val next = NextPrayer.next(this)
        if (next == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            ServiceCompat.startForeground(
                this,
                NextPrayer.NOTIFICATION_ID,
                NextPrayer.notification(this, next),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                } else {
                    0
                },
            )
        } catch (error: Exception) {
            // Not allowed to come to the foreground from here: the alarms
            // carry on without it, and the next app open tries again.
            Log.w(TAG, "Could not show the next prayer: ${error.message}")
            PrayerPlan.log(this, "ongoing failed", error.javaClass.simpleName)
            stopSelf()
            return START_NOT_STICKY
        }
        shownAt = next.at
        listen()
        return START_STICKY
    }

    /** The minute tick arrives only while the device is awake — exactly
     *  when someone could be looking at a countdown that has run out. */
    private fun listen() {
        if (ticking != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val next = NextPrayer.next(context)
                if (next == null) {
                    stopSelf()
                } else if (next.at != shownAt || intent.action != Intent.ACTION_TIME_TICK) {
                    shownAt = next.at
                    NextPrayer.post(context, next)
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_TIME_TICK)
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        ContextCompat.registerReceiver(this, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        ticking = receiver
    }

    override fun onDestroy() {
        ticking?.let {
            try {
                unregisterReceiver(it)
            } catch (error: Exception) {
                // Already gone.
            }
        }
        ticking = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "PrayerAlarms"
    }
}

/** One prayer the status bar can show: when, and how to say it. */
data class UpcomingPrayer(val at: Long, val title: String)

/**
 * The stored list of prayer times behind [NextPrayerService], and the one
 * place that starts, refreshes and stops it.
 *
 * Dart writes the list — names and times in the user's language, six weeks
 * of them — so the service never has to calculate or translate anything.
 */
object NextPrayer {
    const val NOTIFICATION_ID = 7_700_001
    private const val CHANNEL = "next_prayer"
    private const val PREFS = "next_prayer"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_LABEL = "label"
    private const val KEY_CHANNEL_NAME = "channel_name"
    private const val KEY_ENTRIES = "entries"

    /** Store what Dart sent, then bring the service in line with it. */
    fun configure(context: Context, raw: String) {
        val json = try {
            JSONObject(raw)
        } catch (error: Exception) {
            JSONObject()
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_ENABLED, json.optBoolean("enabled", false))
            .putString(KEY_LABEL, json.optString("label"))
            .putString(KEY_CHANNEL_NAME, json.optString("channelName"))
            .putString(KEY_ENTRIES, (json.optJSONArray("entries") ?: JSONArray()).toString())
            .apply()
        sync(context)
    }

    fun enabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)

    /**
     * Start the service, refresh what it shows, or stop it — whichever the
     * stored setting and the list call for. Safe to call from anywhere and
     * as often as anything changes.
     */
    fun sync(context: Context) {
        val app = context.applicationContext
        val intent = Intent(app, NextPrayerService::class.java)
        if (!enabled(app) || next(app) == null) {
            app.stopService(intent)
            return
        }
        try {
            ContextCompat.startForegroundService(app, intent)
        } catch (error: Exception) {
            // Android 12 and up refuse a foreground start from the background
            // outside a few exemptions (an alarm firing is one, so is the app
            // being exempt from battery optimisation). Refused here, it is
            // started on the next alarm or app open.
            Log.w("PrayerAlarms", "Next prayer not started: ${error.message}")
            PrayerPlan.log(app, "ongoing refused", error.javaClass.simpleName)
        }
    }

    fun next(context: Context): UpcomingPrayer? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_ENTRIES, "[]") ?: "[]"
        val now = System.currentTimeMillis()
        return try {
            val array = JSONArray(raw)
            var best: UpcomingPrayer? = null
            for (index in 0 until array.length()) {
                val entry = array.optJSONObject(index) ?: continue
                val at = entry.optLong("at", 0L)
                if (at <= now) continue
                if (best == null || at < best.at) {
                    best = UpcomingPrayer(at, entry.optString("title"))
                }
            }
            best
        } catch (error: Exception) {
            null
        }
    }

    fun post(context: Context, next: UpcomingPrayer) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        try {
            manager?.notify(NOTIFICATION_ID, notification(context, next))
        } catch (error: Exception) {
            Log.w("PrayerAlarms", "Could not refresh the next prayer: ${error.message}")
        }
    }

    fun notification(context: Context, next: UpcomingPrayer): Notification {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        ensureChannel(context, prefs.getString(KEY_CHANNEL_NAME, null).orEmpty())
        return NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_fajr)
            .setContentTitle(next.title)
            .setContentText(prefs.getString(KEY_LABEL, null).orEmpty())
            .setWhen(next.at)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(AlarmNotifier.openAppPending(context))
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    /** Low importance: in the shade and the status bar, never a sound, a
     *  vibration or a heads-up. */
    private fun ensureChannel(context: Context, name: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        val channel = NotificationChannel(
            CHANNEL,
            name.ifEmpty { "Next prayer" },
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }
}
