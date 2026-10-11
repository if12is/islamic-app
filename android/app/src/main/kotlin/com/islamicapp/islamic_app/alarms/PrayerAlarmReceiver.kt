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
 * event happened that loses alarms or moves them, so arm them again. Android
 * clears every alarm on reboot, an app update replaces them, changing the
 * clock or flying to another country moves every prayer, and being granted
 * exact alarms makes possible what was refused an hour ago.
 *
 * None of this reaches an app that has been force-stopped: Android sends a
 * stopped app nothing, boot included, until it is opened. That case is left
 * to the phone's auto-start setting and to opening the app, which re-arms.
 *
 * The work runs on the engine's thread through [goAsync]: the plan is a file
 * of a few hundred kilobytes, and a receiver on the main thread of a process
 * just started for it has no time to spare.
 */
class PrayerAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val handled = action == AlarmEngine.ACTION_FIRE || action in rearmOn
        if (!handled) return

        val pending = goAsync()
        val app = context.applicationContext
        AlarmEngine.submit {
            try {
                if (action == AlarmEngine.ACTION_FIRE) {
                    deliver(app, intent.getIntExtra(AlarmEngine.EXTRA_ID, -1))
                } else {
                    Log.i("PrayerAlarms", "Re-arming after $action")
                    AlarmEngine.arm(app, action)
                }
            } finally {
                pending.finish()
            }
        }
    }

    private fun deliver(context: Context, id: Int) {
        try {
            PrayerPlan.locked {
                val item = if (id >= 0) PrayerPlan.item(context, id) else null
                // Gone from the plan: already shown late, or cancelled because
                // the thing it asked about was done. Either way, not again.
                if (item != null && !PrayerPlan.deliveredKeys(context).contains(item.key)) {
                    AlarmEngine.present(context, item)
                }
                if (item != null) {
                    PrayerPlan.remove(context, setOf(item.id))
                }
            }
        } catch (error: Exception) {
            Log.e("PrayerAlarms", "Delivering alert $id failed", error)
        } finally {
            // Always, whatever happened above: the next alarm is what keeps
            // six weeks of prayers alive, and one bad alert must not end them.
            AlarmEngine.arm(context, "fired")
        }
    }

    companion object {
        private val rearmOn = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            // Granted exact alarms: what was refused can now be scheduled on
            // the second, so everything is armed again at once.
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
        )
    }
}
