package com.islamicapp.islamic_app.alarms

import android.app.ActivityManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log

/**
 * Hands the next few alerts to Android's alarm manager, and nothing more.
 *
 * Two alarms are armed at a time, not the whole plan. Android holds a few
 * hundred alarms per app at most, vendors quietly thin out long queues, and a
 * queue is no use anyway once the app has been stopped — every alarm in it is
 * cancelled at the same moment. A short queue that re-arms itself each time
 * one fires survives everything except being stopped, and recovers from that
 * the next time the phone boots, the clock changes, or the app is opened.
 *
 * The nearest alarm is an alarm clock: the one kind of alarm Android never
 * delays, never batches into a maintenance window, and wakes the device out
 * of doze for. The vendor battery managers on Xiaomi, Oppo, Vivo, Honor and
 * Samsung leave it alone too, because it is the same call the clock app makes
 * for a morning alarm.
 */
object AlarmEngine {
    private const val TAG = "PrayerAlarms"

    /** How many alarms to hold at once. One would be enough if nothing ever
     *  went wrong; the second covers an alarm dropped in a doze window. */
    private const val ARM_AHEAD = 2

    /** An alert whose time passed while the phone was off is still worth
     *  showing this long after — a prayer ten minutes ago, not this morning's. */
    private const val LATE_GRACE_MS = 10 * 60 * 1000L

    const val ACTION_FIRE = "com.islamicapp.islamic_app.ALARM_FIRE"
    const val EXTRA_ID = "id"

    /**
     * Bring the armed alarms in line with the plan.
     *
     * Called after the plan is written, when one fires, and on every event
     * that can lose alarms: boot, an app update, the clock or time zone
     * changing, exact-alarm permission being granted, the app being started
     * again after the system stopped it.
     */
    @Synchronized
    fun arm(context: Context, reason: String) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (manager == null) {
            Log.w(TAG, "No alarm manager; nothing armed")
            return
        }

        val now = System.currentTimeMillis()
        val plan = PrayerPlan.items(context)

        // Anything due in the last few minutes is shown now: the phone was
        // off or dozing through it. Anything older is a miss, and recorded as
        // one so the app can say so instead of pretending it arrived.
        val overdue = plan.filter { it.at <= now }
        val late = overdue.filter { now - it.at <= LATE_GRACE_MS }
        val missed = overdue.filter { now - it.at > LATE_GRACE_MS }
        if (missed.isNotEmpty()) {
            PrayerPlan.rememberMissed(context, missed)
        }
        for (item in late) {
            AlarmNotifier.show(context, item)
            PrayerPlan.rememberDelivered(context, item, System.currentTimeMillis())
        }
        if (overdue.isNotEmpty()) {
            PrayerPlan.write(context, plan.filter { it.at > now })
        }

        val upcoming = plan.filter { it.at > now }.take(ARM_AHEAD)
        val wanted = upcoming.map { it.id }.toSet()

        // Drop what is armed and no longer wanted, so a plan rewritten with
        // new prayer times never leaves yesterday's alarm behind it.
        for (id in PrayerPlan.armedIds(context) - wanted) {
            manager.cancel(firePending(context, id))
        }

        upcoming.forEachIndexed { index, item ->
            val operation = firePending(context, item.id)
            try {
                if (index == 0) {
                    manager.setAlarmClock(
                        AlarmManager.AlarmClockInfo(item.at, AlarmNotifier.openAppPending(context)),
                        operation,
                    )
                } else {
                    manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, item.at, operation)
                }
            } catch (error: SecurityException) {
                // Exact alarms refused: still schedule, loosely, rather than
                // leave the prayer with nothing at all behind it.
                Log.w(TAG, "Exact alarm refused for ${item.id}: ${error.message}")
                manager.setWindow(
                    AlarmManager.RTC_WAKEUP,
                    item.at,
                    10 * 60 * 1000L,
                    operation,
                )
            }
        }

        PrayerPlan.rememberArmed(context, wanted)
        PrayerPlan.rememberRecovery(context, reason)
        Log.i(TAG, "Armed ${wanted.size} of ${plan.size} ($reason)")
    }

    /** Forget [ids]: both the plan entry and any alarm already armed for it. */
    fun cancel(context: Context, ids: Set<Int>) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        for (id in ids) {
            manager?.cancel(firePending(context, id))
            AlarmNotifier.dismiss(context, id)
        }
        PrayerPlan.remove(context, ids)
        arm(context, "cancel")
    }

    fun clear(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        for (id in PrayerPlan.armedIds(context)) {
            manager?.cancel(firePending(context, id))
        }
        PrayerPlan.clear(context)
    }

    private fun firePending(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = ACTION_FIRE
            // The data makes each alert's intent distinct; extras alone do not,
            // so without it every alarm would overwrite the one before it.
            data = android.net.Uri.parse("prayer-alarm://$id")
            putExtra(EXTRA_ID, id)
        }
        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * What the system says about this app's ability to deliver on time.
     *
     * Every one of these is a real reason an adhan does not sound, and none of
     * them surfaces anywhere: the app can be in the restricted standby bucket
     * with one alarm a day, or have been force-stopped overnight by a battery
     * manager, and scheduling still reports success.
     */
    fun diagnostics(context: Context): Map<String, Any?> {
        val report = HashMap<String, Any?>(PrayerPlan.report(context))
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val activity = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager

        report["canScheduleExact"] =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                manager?.canScheduleExactAlarms()
            } else {
                true
            }
        report["ignoringBatteryOptimizations"] = power?.isIgnoringBatteryOptimizations(context.packageName)
        report["powerSaveMode"] = power?.isPowerSaveMode
        report["backgroundRestricted"] =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                activity?.isBackgroundRestricted
            } else {
                false
            }
        report["standbyBucket"] = standbyBucket(context)
        report["forceStopped"] = wasForceStopped(context)
        report["manufacturer"] = Build.MANUFACTURER ?: ""
        report["sdkInt"] = Build.VERSION.SDK_INT
        report["bootedAt"] = System.currentTimeMillis() - android.os.SystemClock.elapsedRealtime()
        return report
    }

    /**
     * 10 active, 20 working set, 30 frequent, 40 rare, 45 restricted.
     *
     * Restricted is the one that matters: from Android 13 an app nobody has
     * opened for eight days lands there, and there it is allowed one alarm a
     * day — five prayers become one. Holding `USE_EXACT_ALARM`, which this app
     * does, is supposed to exempt it; reading the bucket back is how we find
     * out on the devices where it does not.
     */
    private fun standbyBucket(context: Context): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return -1
        val usage = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
        return try {
            usage?.appStandbyBucket ?: -1
        } catch (error: Exception) {
            -1
        }
    }

    /** Android 15 and up can say outright that the app was force-stopped —
     *  the event that cancels every alarm the app holds. */
    private fun wasForceStopped(context: Context): Boolean? {
        if (Build.VERSION.SDK_INT < 35) return null
        val activity = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            ?: return null
        return try {
            val starts = activity.getHistoricalProcessStartReasons(1)
            starts.firstOrNull()?.wasForceStopped()
        } catch (error: Exception) {
            null
        }
    }
}
