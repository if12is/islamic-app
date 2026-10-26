package com.islamicapp.islamic_app.alarms

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

/**
 * The one way Dart talks to the alarm engine.
 *
 * Dart decides what to say and when — it knows the prayer times, the user's
 * preferences and the language. The engine decides nothing; it delivers. So
 * the plan crosses once, as plain data, and from then on the engine can carry
 * it for weeks on its own.
 *
 * The work runs on the engine's own thread — a plan of six weeks is a few
 * hundred kilobytes to parse and write — and the answer goes back on the main
 * thread, the only one a method channel may reply on.
 */
object AlarmChannel {
    const val NAME = "islamic_app/alarms"

    private val main = Handler(Looper.getMainLooper())

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val app = context.applicationContext
        when (call.method) {
            "setPlan" -> {
                val raw = call.argument<String>("items") ?: "[]"
                respond(result) {
                    PrayerPlan.locked {
                        val items = handOver(app, parse(raw))
                        PrayerPlan.write(app, items)
                        AlarmEngine.arm(app, "plan")
                        items.size
                    }
                }
            }

            "cancel" -> {
                val ids = call.argument<List<Int>>("ids")?.toSet() ?: emptySet()
                respond(result) {
                    AlarmEngine.cancel(app, ids)
                    true
                }
            }

            "clear" -> respond(result) {
                AlarmEngine.clear(app)
                true
            }

            "arm" -> {
                val reason = call.argument<String>("reason") ?: "app"
                respond(result) {
                    AlarmEngine.arm(app, reason)
                    true
                }
            }

            "setNextPrayer" -> {
                val raw = call.argument<String>("config") ?: "{}"
                respond(result) {
                    NextPrayer.configure(app, raw)
                    true
                }
            }

            "diagnostics" -> respond(result) { AlarmEngine.diagnostics(app) }

            "clearHistory" -> respond(result) {
                PrayerPlan.clearHistory(app)
                true
            }

            else -> result.notImplemented()
        }
    }

    /**
     * What of a new plan the engine takes on.
     *
     * Everything still to come, and anything due in the last few minutes that
     * has not been shown yet — an alarm can fire a few seconds after its time,
     * and a plan written in those seconds must not drop the alert it was
     * about to show. The engine shows that one once, late. Older alerts were
     * never promised by this plan, and left in, they would be written down as
     * missed: a false alarm on the screen that reports what did not arrive.
     */
    private fun handOver(context: Context, items: List<PlanItem>): List<PlanItem> {
        val now = System.currentTimeMillis()
        val shown = PrayerPlan.deliveredKeys(context)
        return items.filter { item ->
            item.at > now || (now - item.at <= AlarmEngine.LATE_GRACE_MS && !shown.contains(item.key))
        }
    }

    private fun respond(result: MethodChannel.Result, work: () -> Any?) {
        AlarmEngine.submit {
            val answer = try {
                Result.success(work())
            } catch (error: Exception) {
                Result.failure(error)
            }
            main.post {
                answer.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("alarm_engine", it.message, null) },
                )
            }
        }
    }

    private fun parse(raw: String): List<PlanItem> {
        return try {
            val array = JSONArray(raw)
            val items = ArrayList<PlanItem>(array.length())
            for (index in 0 until array.length()) {
                val entry = array.optJSONObject(index) ?: continue
                PlanItem.fromJson(entry)?.let { items.add(it) }
            }
            items
        } catch (error: Exception) {
            emptyList()
        }
    }
}
