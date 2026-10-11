package com.islamicapp.islamic_app.alarms

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * One alert the app has promised to deliver: a prayer, the call before it, the
 * iqama, an azkar reminder.
 *
 * It carries everything needed to show the notification without Dart running,
 * because at the moment it matters Dart is not running: the phone has been in
 * someone's pocket since yesterday and the app was never opened.
 */
data class PlanItem(
    val id: Int,
    val at: Long,
    val title: String,
    val body: String,
    val channel: String,
    val payload: String?,
    /** Shown as a time-critical alarm rather than a reminder. */
    val alarm: Boolean,
    val fullScreen: Boolean,
    val silent: Boolean,
    val actions: List<PlanAction>,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("at", at)
        put("title", title)
        put("body", body)
        put("channel", channel)
        payload?.let { put("payload", it) }
        put("alarm", alarm)
        put("fullScreen", fullScreen)
        put("silent", silent)
        if (actions.isNotEmpty()) {
            put("actions", JSONArray().apply {
                actions.forEach { put(it.toJson()) }
            })
        }
    }

    companion object {
        fun fromJson(json: JSONObject): PlanItem? {
            val id = json.optInt("id", -1)
            val at = json.optLong("at", 0L)
            if (id < 0 || at <= 0L) return null
            return PlanItem(
                id = id,
                at = at,
                title = json.optString("title"),
                body = json.optString("body"),
                channel = json.optString("channel"),
                payload = json.optString("payload").ifEmpty { null },
                alarm = json.optBoolean("alarm", false),
                fullScreen = json.optBoolean("fullScreen", false),
                silent = json.optBoolean("silent", false),
                actions = PlanAction.listFrom(json.optJSONArray("actions")),
            )
        }
    }
}

/** A button under a notification. Every one of them opens the app. */
data class PlanAction(val id: String, val label: String) {
    fun toJson(): JSONObject =
        JSONObject().apply {
            put("id", id)
            put("label", label)
        }

    companion object {
        fun listFrom(array: JSONArray?): List<PlanAction> {
            if (array == null) return emptyList()
            val actions = mutableListOf<PlanAction>()
            for (index in 0 until array.length()) {
                val entry = array.optJSONObject(index) ?: continue
                val id = entry.optString("id")
                val label = entry.optString("label")
                if (id.isNotEmpty() && label.isNotEmpty()) {
                    actions.add(PlanAction(id, label))
                }
            }
            return actions
        }
    }
}

/**
 * The plan on the device, and the record of what was actually delivered.
 *
 * Why the plan lives here rather than in the notification plugin's cache: the
 * plugin hands every alert to the alarm manager at once and holds nothing it
 * can rebuild from. This store keeps weeks of alerts as plain data and arms
 * only the next few, so a single fired alarm is enough to arm the one after
 * it — the schedule carries itself forward without the app being opened.
 *
 * It also keeps the other half of the story, which the app never had: which
 * alerts arrived. Without that, an adhan that never sounded looks exactly
 * like an adhan nobody was there to hear.
 */
object PrayerPlan {
    private const val FILE = "prayer_alarm_plan"
    private const val KEY_ITEMS = "items"
    private const val KEY_ARMED = "armed"
    private const val KEY_DELIVERED = "delivered"
    private const val KEY_MISSED = "missed"
    private const val KEY_LAST_FIRED = "last_fired_at"
    private const val KEY_LAST_ARMED = "last_armed_at"
    private const val KEY_LAST_RECOVERY = "last_recovery"
    private const val KEY_WRITTEN_AT = "written_at"

    /** How many delivery records to keep. Enough to show a week back. */
    private const val HISTORY = 80

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun items(context: Context): List<PlanItem> {
        val raw = prefs(context).getString(KEY_ITEMS, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            val items = ArrayList<PlanItem>(array.length())
            for (index in 0 until array.length()) {
                val entry = array.optJSONObject(index) ?: continue
                PlanItem.fromJson(entry)?.let { items.add(it) }
            }
            items.sortedBy { it.at }
        } catch (error: Exception) {
            emptyList()
        }
    }

    fun write(context: Context, items: List<PlanItem>) {
        val array = JSONArray()
        items.sortedBy { it.at }.forEach { array.put(it.toJson()) }
        prefs(context).edit()
            .putString(KEY_ITEMS, array.toString())
            .putLong(KEY_WRITTEN_AT, System.currentTimeMillis())
            .apply()
    }

    /** Drop [ids] from the plan — a follow-up series that is no longer due. */
    fun remove(context: Context, ids: Set<Int>) {
        if (ids.isEmpty()) return
        write(context, items(context).filterNot { ids.contains(it.id) })
    }

    fun clear(context: Context) {
        prefs(context).edit()
            .remove(KEY_ITEMS)
            .remove(KEY_ARMED)
            .apply()
    }

    fun item(context: Context, id: Int): PlanItem? = items(context).firstOrNull { it.id == id }

    fun armedIds(context: Context): Set<Int> = idSet(context, KEY_ARMED)

    fun rememberArmed(context: Context, ids: Collection<Int>) {
        prefs(context).edit()
            .putString(KEY_ARMED, JSONArray(ids.toList()).toString())
            .putLong(KEY_LAST_ARMED, System.currentTimeMillis())
            .apply()
    }

    /** Record that [item] was shown, so a silent failure can be told apart. */
    fun rememberDelivered(context: Context, item: PlanItem, shownAt: Long) {
        val store = prefs(context)
        val history = JSONArray()
        val existing = try {
            JSONArray(store.getString(KEY_DELIVERED, "[]"))
        } catch (error: Exception) {
            JSONArray()
        }
        val start = maxOf(0, existing.length() - (HISTORY - 1))
        for (index in start until existing.length()) {
            history.put(existing.opt(index))
        }
        history.put(
            JSONObject().apply {
                put("id", item.id)
                put("due", item.at)
                put("shown", shownAt)
            }
        )
        store.edit()
            .putString(KEY_DELIVERED, history.toString())
            .putLong(KEY_LAST_FIRED, shownAt)
            .apply()
    }

    /**
     * Record that an alert's time passed without it being shown.
     *
     * Found when the alarms are next armed: an item due in the past that was
     * never delivered. That is the fingerprint of the app having been stopped
     * by the system — nothing else loses an alarm quietly.
     */
    fun rememberMissed(context: Context, items: List<PlanItem>) {
        if (items.isEmpty()) return
        val store = prefs(context)
        val history = JSONArray()
        val existing = try {
            JSONArray(store.getString(KEY_MISSED, "[]"))
        } catch (error: Exception) {
            JSONArray()
        }
        val keep = maxOf(0, existing.length() - (HISTORY - items.size))
        for (index in keep until existing.length()) {
            history.put(existing.opt(index))
        }
        items.forEach { item ->
            history.put(
                JSONObject().apply {
                    put("id", item.id)
                    put("due", item.at)
                    put("noticed", System.currentTimeMillis())
                }
            )
        }
        store.edit().putString(KEY_MISSED, history.toString()).apply()
    }

    fun rememberRecovery(context: Context, reason: String) {
        prefs(context).edit()
            .putString(KEY_LAST_RECOVERY, reason)
            .putLong("${KEY_LAST_RECOVERY}_at", System.currentTimeMillis())
            .apply()
    }

    fun clearHistory(context: Context) {
        prefs(context).edit()
            .remove(KEY_DELIVERED)
            .remove(KEY_MISSED)
            .apply()
    }

    /** Everything the diagnostics screen reads back out. */
    fun report(context: Context): Map<String, Any?> {
        val store = prefs(context)
        val plan = items(context)
        val now = System.currentTimeMillis()
        return mapOf(
            "planSize" to plan.size,
            "planWrittenAt" to store.getLong(KEY_WRITTEN_AT, 0L),
            "planEndsAt" to (plan.lastOrNull()?.at ?: 0L),
            "nextAt" to (plan.firstOrNull { it.at > now }?.at ?: 0L),
            "armed" to armedIds(context).size,
            "lastArmedAt" to store.getLong(KEY_LAST_ARMED, 0L),
            "lastFiredAt" to store.getLong(KEY_LAST_FIRED, 0L),
            "lastRecovery" to store.getString(KEY_LAST_RECOVERY, ""),
            "lastRecoveryAt" to store.getLong("${KEY_LAST_RECOVERY}_at", 0L),
            "delivered" to store.getString(KEY_DELIVERED, "[]"),
            "missed" to store.getString(KEY_MISSED, "[]"),
        )
    }

    private fun idSet(context: Context, key: String): Set<Int> {
        val raw = prefs(context).getString(key, null) ?: return emptySet()
        return try {
            val array = JSONArray(raw)
            val ids = HashSet<Int>(array.length())
            for (index in 0 until array.length()) {
                ids.add(array.optInt(index, -1))
            }
            ids.remove(-1)
            ids
        } catch (error: Exception) {
            emptySet()
        }
    }
}
