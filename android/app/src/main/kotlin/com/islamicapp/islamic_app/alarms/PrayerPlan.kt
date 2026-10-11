package com.islamicapp.islamic_app.alarms

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

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
    /**
     * The sound, for Android 7 only: `raw:<name>`, a `content://` URI,
     * `default`, or empty for none. From Android 8 the channel carries it.
     */
    val sound: String = "",
    val vibrate: Boolean = false,
) {
    /** The same alert on the same day; ids repeat across rewritten plans. */
    val key: String get() = "$id@$at"

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
        if (sound.isNotEmpty()) put("sound", sound)
        if (vibrate) put("vibrate", true)
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
                sound = json.optString("sound"),
                vibrate = json.optBoolean("vibrate", false),
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
 *
 * The plan is a file of its own, not a preference. Six weeks of alerts run to
 * a few hundred kilobytes, and Android rewrites a whole preferences file on
 * every change — five times a prayer, for a few bytes of bookkeeping each. So
 * the plan is written only when it changes, and the small records stay in
 * preferences beside it.
 *
 * Every read-change-write goes through [locked]: the receiver, the app and
 * the method channel all reach this store, and since the receiver works off
 * the main thread, two of them can be in it at once.
 */
object PrayerPlan {
    private const val PREFS = "prayer_alarm_plan"
    private const val PLAN_FILE = "prayer_alarm_plan.json"
    private const val KEY_ARMED = "armed"
    private const val KEY_DELIVERED = "delivered"
    private const val KEY_MISSED = "missed"
    private const val KEY_LAST_FIRED = "last_fired_at"
    private const val KEY_LAST_ARMED = "last_armed_at"
    private const val KEY_LAST_RECOVERY = "last_recovery"
    private const val KEY_WRITTEN_AT = "written_at"

    /** The first release kept the plan in preferences, under this key. */
    private const val LEGACY_KEY_ITEMS = "items"

    /** How many delivery records to keep. Enough to show a week back. */
    private const val HISTORY = 80

    private val lock = Any()

    @Volatile
    private var cache: List<PlanItem>? = null

    fun <T> locked(block: () -> T): T = synchronized(lock) { block() }

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun file(context: Context) = File(context.filesDir, PLAN_FILE)

    fun items(context: Context): List<PlanItem> = locked {
        cache?.let { return@locked it }
        val loaded = read(context)
        cache = loaded
        loaded
    }

    private fun read(context: Context): List<PlanItem> {
        val target = file(context)
        val raw = when {
            target.exists() -> try {
                target.readText()
            } catch (error: Exception) {
                null
            }
            else -> prefs(context).getString(LEGACY_KEY_ITEMS, null)
        } ?: return emptyList()
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

    fun write(context: Context, items: List<PlanItem>) = locked {
        val sorted = items.sortedBy { it.at }
        val array = JSONArray()
        sorted.forEach { array.put(it.toJson()) }
        // Written beside the real file and moved over it, so a process killed
        // halfway leaves the old plan rather than half of a new one.
        val target = file(context)
        val temp = File(target.parentFile, "$PLAN_FILE.tmp")
        temp.writeText(array.toString())
        if (!temp.renameTo(target)) {
            target.writeText(array.toString())
            temp.delete()
        }
        cache = sorted
        prefs(context).edit()
            .remove(LEGACY_KEY_ITEMS)
            .putLong(KEY_WRITTEN_AT, System.currentTimeMillis())
            .apply()
    }

    /** Drop [ids] from the plan — a follow-up series that is no longer due. */
    fun remove(context: Context, ids: Set<Int>) = locked {
        if (ids.isEmpty()) return@locked
        val current = items(context)
        val kept = current.filterNot { ids.contains(it.id) }
        if (kept.size != current.size) {
            write(context, kept)
        }
    }

    fun clear(context: Context) = locked {
        file(context).delete()
        cache = emptyList()
        prefs(context).edit()
            .remove(LEGACY_KEY_ITEMS)
            .remove(KEY_ARMED)
            .apply()
    }

    fun item(context: Context, id: Int): PlanItem? = items(context).firstOrNull { it.id == id }

    fun armedIds(context: Context): Set<Int> = idSet(context, KEY_ARMED)

    /** The bookkeeping of one arming, in a single write. */
    fun rememberArming(context: Context, ids: Collection<Int>, reason: String) {
        val now = System.currentTimeMillis()
        prefs(context).edit()
            .putString(KEY_ARMED, JSONArray(ids.toList()).toString())
            .putLong(KEY_LAST_ARMED, now)
            .putString(KEY_LAST_RECOVERY, reason)
            .putLong("${KEY_LAST_RECOVERY}_at", now)
            .apply()
    }

    fun lastArmedAt(context: Context): Long = prefs(context).getLong(KEY_LAST_ARMED, 0L)

    /** Alerts already shown, as [PlanItem.key]s, so none is shown twice. */
    fun deliveredKeys(context: Context): Set<String> {
        val history = history(context, KEY_DELIVERED)
        val keys = HashSet<String>(history.length())
        for (index in 0 until history.length()) {
            val entry = history.optJSONObject(index) ?: continue
            keys.add("${entry.optInt("id")}@${entry.optLong("due")}")
        }
        return keys
    }

    /** Record that [item] was shown, so a silent failure can be told apart. */
    fun rememberDelivered(context: Context, item: PlanItem, shownAt: Long) = locked {
        val history = trimmed(history(context, KEY_DELIVERED), 1)
        history.put(
            JSONObject().apply {
                put("id", item.id)
                put("due", item.at)
                put("shown", shownAt)
            }
        )
        prefs(context).edit()
            .putString(KEY_DELIVERED, history.toString())
            .putLong(KEY_LAST_FIRED, shownAt)
            .apply()
    }

    /**
     * Record that alerts' times passed without them reaching the user.
     *
     * [reason] is `missed` — found overdue when the alarms were next armed,
     * the fingerprint of the app having been stopped — or `blocked`, when the
     * alarm did fire but notifications were switched off and the system
     * dropped what was posted.
     */
    fun rememberMissed(context: Context, items: List<PlanItem>, reason: String = "missed") = locked {
        if (items.isEmpty()) return@locked
        // A burst larger than the history keeps only its newest part.
        val recent = items.sortedBy { it.at }.takeLast(HISTORY)
        val history = trimmed(history(context, KEY_MISSED), recent.size)
        val now = System.currentTimeMillis()
        recent.forEach { item ->
            history.put(
                JSONObject().apply {
                    put("id", item.id)
                    put("due", item.at)
                    put("noticed", now)
                    put("reason", reason)
                }
            )
        }
        prefs(context).edit().putString(KEY_MISSED, history.toString()).apply()
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
            "planSize" to plan.count { it.at > now },
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

    private fun history(context: Context, key: String): JSONArray =
        try {
            JSONArray(prefs(context).getString(key, "[]"))
        } catch (error: Exception) {
            JSONArray()
        }

    /** The newest records of [existing], leaving room for [adding] more. */
    private fun trimmed(existing: JSONArray, adding: Int): JSONArray {
        val keep = (HISTORY - adding).coerceAtLeast(0)
        val start = (existing.length() - keep).coerceAtLeast(0)
        val result = JSONArray()
        for (index in start until existing.length()) {
            result.put(existing.opt(index))
        }
        return result
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
