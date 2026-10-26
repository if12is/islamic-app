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
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Hands the next few alerts to Android's alarm manager, and nothing more.
 *
 * A day of alarms is armed at a time, not the whole plan. Android holds a few
 * hundred alarms per app at most, vendors quietly thin out long queues, and
 * a queue of a week runs out after a week. A short queue that re-arms itself
 * each time one fires carries six weeks forward with nothing else running.
 *
 * Why a day and not two: the first release held two, and on an Honor 600 on
 * Android 16, with every permission granted and auto-launch on, almost every
 * alert of a week was missed. Two alarms are one bad night from an empty
 * queue — both dropped, and nothing is left to arm the rest. With a day of
 * them, each one that does fire re-arms the day after it.
 *
 * What it cannot survive is the app being force-stopped — by the user, or by
 * a vendor battery manager on Honor, Xiaomi, Oppo, Vivo or Samsung that does
 * the same thing. A stopped app loses every alarm it holds and receives no
 * broadcast at all, boot included, until someone opens it; nothing an app
 * does from inside can change that. The answer there is the phone's own
 * auto-start setting, which the notification centre walks the user through.
 *
 * Every armed alarm is an alarm clock: the one kind of alarm Android never
 * delays, never batches into a maintenance window, and wakes the device out
 * of doze for — and the kind vendor battery managers leave alone, because
 * cutting it would make the phone's own clock app miss a wake-up.
 */
object AlarmEngine {
    private const val TAG = "PrayerAlarms"

    /** Alarms are held for this far ahead… */
    private const val ARM_WINDOW_MS = 24 * 60 * 60 * 1000L

    /** …but never more than this many, nor fewer than [ARM_MIN] while the
     *  plan has them: a quiet day still keeps the next two armed. */
    private const val ARM_MAX = 12
    private const val ARM_MIN = 2

    /** An alert whose time passed while the phone was off is still worth
     *  showing this long after — a prayer ten minutes ago, not this morning's. */
    const val LATE_GRACE_MS = 10 * 60 * 1000L

    const val ACTION_FIRE = "com.islamicapp.islamic_app.ALARM_FIRE"
    const val EXTRA_ID = "id"

    /** Reasons that mean the clock itself moved, not that time passed. */
    private val clockChanges = setOf(
        Intent.ACTION_TIME_CHANGED,
        Intent.ACTION_TIMEZONE_CHANGED,
    )

    /**
     * One thread for all of it, so the plan's file and the alarm manager are
     * never worked on from two places at once, and never from the main thread,
     * where reading a few hundred kilobytes on every resume would show.
     */
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()

    /** [arm], off the main thread; [done] runs after, on the same thread. */
    fun armAsync(context: Context, reason: String, done: (() -> Unit)? = null) {
        val app = context.applicationContext
        worker.execute {
            try {
                arm(app, reason)
            } catch (error: Exception) {
                Log.e(TAG, "Arming failed ($reason)", error)
            } finally {
                done?.invoke()
            }
        }
    }

    /** Run [work] on the engine's thread. */
    fun submit(work: () -> Unit) {
        worker.execute {
            try {
                work()
            } catch (error: Exception) {
                Log.e(TAG, "Alarm engine work failed", error)
            }
        }
    }

    /**
     * Bring the armed alarms in line with the plan.
     *
     * Called after the plan is written, when one fires, and on every event
     * that can lose alarms: boot, an app update, the clock or time zone
     * changing, exact-alarm permission being granted, the app being opened.
     */
    fun arm(context: Context, reason: String) = PrayerPlan.locked {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (manager == null) {
            Log.w(TAG, "No alarm manager; nothing armed")
            return@locked
        }

        val now = System.currentTimeMillis()
        val plan = PrayerPlan.items(context)

        // Anything due in the last few minutes is shown now: the phone was
        // off or dozing through it. Anything older is a miss, and recorded as
        // one so the app can say so instead of pretending it arrived.
        val overdue = plan.filter { it.at <= now }
        var missedCount = 0
        var lateCount = 0
        if (overdue.isNotEmpty()) {
            if (reason in clockChanges) {
                // The clock moved, not time. A phone whose clock jumps a day
                // forward at boot did not miss a day of prayers, and showing
                // or counting them would be wrong both ways.
                Log.i(TAG, "Clock changed: dropping ${overdue.size} past alerts unrecorded")
            } else {
                val shown = PrayerPlan.deliveredKeys(context)
                val late = overdue.filter {
                    now - it.at <= LATE_GRACE_MS && !shown.contains(it.key)
                }
                val missed = overdue.filter {
                    now - it.at > LATE_GRACE_MS && !shown.contains(it.key)
                }
                if (missed.isNotEmpty()) {
                    PrayerPlan.rememberMissed(context, missed)
                    PrayerPlan.log(
                        context,
                        "missed",
                        "${missed.size}, first due ${stamp(missed.first().at)}",
                    )
                }
                missedCount = missed.size
                lateCount = late.size
                for (item in late) {
                    present(context, item, "late ${(now - item.at) / 1000}s")
                }
            }
            PrayerPlan.write(context, plan.filter { it.at > now })
        }

        val future = plan.filter { it.at > now }
        val inWindow = future.takeWhile { it.at - now <= ARM_WINDOW_MS }.take(ARM_MAX)
        val upcoming = if (inWindow.size >= ARM_MIN) inWindow else future.take(ARM_MIN)
        val wanted = upcoming.map { it.id }.toSet()

        // Drop what is armed and no longer wanted, so a plan rewritten with
        // new prayer times never leaves yesterday's alarm behind it.
        for (id in PrayerPlan.armedIds(context) - wanted) {
            manager.cancel(firePending(context, id))
        }

        var refused = 0
        for (item in upcoming) {
            val operation = firePending(context, item.id)
            try {
                manager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(item.at, AlarmNotifier.openAppPending(context)),
                    operation,
                )
            } catch (error: SecurityException) {
                // Exact alarms refused: still schedule, loosely, rather than
                // leave the prayer with nothing at all behind it.
                Log.w(TAG, "Exact alarm refused for ${item.id}: ${error.message}")
                refused++
                manager.setWindow(
                    AlarmManager.RTC_WAKEUP,
                    item.at,
                    10 * 60 * 1000L,
                    operation,
                )
            }
        }

        PrayerPlan.rememberArming(context, wanted, reason)
        PrayerPlan.log(
            context,
            "arm",
            buildString {
                append(reason)
                append(": ").append(upcoming.size).append(" armed")
                upcoming.firstOrNull()?.let { append(", next ").append(stamp(it.at)) }
                upcoming.lastOrNull()?.let { append(", last ").append(stamp(it.at)) }
                if (refused > 0) append(", exact refused ").append(refused)
                if (lateCount > 0) append(", late ").append(lateCount)
                if (missedCount > 0) append(", missed ").append(missedCount)
            },
        )
        Log.i(TAG, "Armed ${wanted.size} of ${future.size} ($reason)")

        // Every event that re-arms the alarms is also one where the next
        // prayer in the status bar may have moved, or its service been lost.
        // An alarm firing is also one of the few moments Android lets a
        // background app start a foreground service.
        NextPrayer.sync(context)
    }

    /** A local time a person can read in a log: `10-26 04:30`. */
    fun stamp(millis: Long): String =
        java.text.SimpleDateFormat("MM-dd HH:mm", java.util.Locale.US).format(java.util.Date(millis))

    /**
     * Show [item] and write down what became of it.
     *
     * Delivered only if the user could actually have seen it: with
     * notifications switched off, or this kind silenced, Android drops the
     * post without a word, and recording that as delivered would hide the
     * very failure the record is kept to reveal.
     */
    fun present(context: Context, item: PlanItem, how: String = "") {
        val posted = try {
            AlarmNotifier.show(context, item)
        } catch (error: Exception) {
            Log.e(TAG, "Could not show alert ${item.id}", error)
            false
        }
        val reached = posted && AlarmNotifier.canReachUser(context, item.channel)
        if (reached) {
            PrayerPlan.rememberDelivered(context, item, System.currentTimeMillis())
        } else {
            PrayerPlan.rememberMissed(context, listOf(item), reason = "blocked")
        }
        PrayerPlan.log(
            context,
            if (reached) "shown" else if (posted) "blocked" else "show failed",
            "${item.id} due ${stamp(item.at)}${if (how.isEmpty()) "" else ", $how"}",
        )
    }

    /** Forget [ids]: both the plan entry and any alarm already armed for it. */
    fun cancel(context: Context, ids: Set<Int>) = PrayerPlan.locked {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        for (id in ids) {
            manager?.cancel(firePending(context, id))
            AlarmNotifier.dismiss(context, id)
        }
        val inPlan = PrayerPlan.items(context).any { ids.contains(it.id) }
        if (inPlan) {
            PrayerPlan.remove(context, ids)
            arm(context, "cancel")
        }
    }

    fun clear(context: Context) = PrayerPlan.locked {
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
        report["notificationsEnabled"] = AlarmNotifier.notificationsEnabled(context)
        report["manufacturer"] = Build.MANUFACTURER ?: ""
        report["sdkInt"] = Build.VERSION.SDK_INT
        report["bootedAt"] = System.currentTimeMillis() - android.os.SystemClock.elapsedRealtime()
        report["exits"] = exitReasons(context)
        report["brand"] = Build.BRAND ?: ""
        report["model"] = Build.MODEL ?: ""
        report["display"] = Build.DISPLAY ?: ""
        return report
    }

    /**
     * Why Android ended this app's last processes, newest first, as JSON.
     *
     * The answer to "what is killing the adhan" on a given phone: reason 10
     * (user requested) is a force-stop, which is what a vendor battery manager
     * does too, and it takes every alarm with it; 3 is low memory, which
     * leaves alarms in place. Android 11 and up keep this record themselves.
     */
    private fun exitReasons(context: Context): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return "[]"
        val activity = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            ?: return "[]"
        return try {
            val array = org.json.JSONArray()
            activity.getHistoricalProcessExitReasons(context.packageName, 0, 20).forEach { exit ->
                array.put(
                    org.json.JSONObject().apply {
                        put("t", exit.timestamp)
                        put("r", exit.reason)
                        put("s", exit.status)
                        put("i", exit.importance)
                        put("d", exit.description ?: "")
                    }
                )
            }
            array.toString()
        } catch (error: Exception) {
            "[]"
        }
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
