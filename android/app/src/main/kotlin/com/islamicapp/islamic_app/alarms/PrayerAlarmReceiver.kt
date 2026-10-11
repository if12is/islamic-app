package com.islamicapp.islamic_app.alarms

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Where every prayer alert actually arrives, and where the schedule heals
 * itself.
 *
 * Two jobs. One: an alarm fired, so show it and arm the next — this is what
 * carries weeks of alerts forward without the app ever being opened. Two: an
 * event happened that loses alarms, so arm them again. Android clears every
 * alarm on reboot, an app update replaces them, changing the clock or flying
 * to another country moves every prayer, and being granted exact alarms makes
 * possible what was refused an hour ago. None of those used to be noticed
 * until someone opened the app.
 */
class PrayerAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (val action = intent.action) {
            AlarmEngine.ACTION_FIRE -> deliver(context, intent)

            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            // Granted exact alarms: what was refused can now be scheduled on
            // the second, so everything is armed again at once.
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
            // Android 15 and up: the app has just left the stopped state the
            // system put it in, which had cancelled every alarm it held.
            "android.intent.action.PACKAGE_UNSTOPPED",
            -> {
                Log.i("PrayerAlarms", "Re-arming after $action")
                AlarmEngine.arm(context, action)
            }
        }
    }

    private fun deliver(context: Context, intent: Intent) {
        val id = intent.getIntExtra(AlarmEngine.EXTRA_ID, -1)
        val item = if (id >= 0) PrayerPlan.item(context, id) else null

        if (item != null) {
            AlarmNotifier.show(context, item)
            PrayerPlan.rememberDelivered(context, item, System.currentTimeMillis())
            // Out of the plan now that it has been shown, so arming again
            // cannot repeat it.
            PrayerPlan.remove(context, setOf(item.id))
        }

        // Always arm, even for an alarm whose entry has gone: the next one is
        // what keeps the chain alive.
        AlarmEngine.arm(context, "fired")
    }
}
