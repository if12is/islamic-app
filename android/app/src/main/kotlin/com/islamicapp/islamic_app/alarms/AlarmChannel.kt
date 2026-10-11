package com.islamicapp.islamic_app.alarms

import android.content.Context
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
 */
object AlarmChannel {
    const val NAME = "islamic_app/alarms"

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setPlan" -> {
                val raw = call.argument<String>("items") ?: "[]"
                // Only what is still to come. An alert whose time had already
                // passed when the plan was made was never promised, and left
                // in, the next arming would write it down as missed — a false
                // alarm on the screen that reports what did not arrive.
                val now = System.currentTimeMillis()
                val items = parse(raw).filter { it.at > now }
                PrayerPlan.write(context, items)
                AlarmEngine.arm(context, "plan")
                result.success(items.size)
            }

            "cancel" -> {
                val ids = call.argument<List<Int>>("ids")?.toSet() ?: emptySet()
                AlarmEngine.cancel(context, ids)
                result.success(true)
            }

            "clear" -> {
                AlarmEngine.clear(context)
                result.success(true)
            }

            "arm" -> {
                AlarmEngine.arm(context, call.argument<String>("reason") ?: "app")
                result.success(true)
            }

            "diagnostics" -> result.success(AlarmEngine.diagnostics(context))

            "clearHistory" -> {
                PrayerPlan.clearHistory(context)
                result.success(true)
            }

            else -> result.notImplemented()
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
