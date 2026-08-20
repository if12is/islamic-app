package com.islamicapp.islamic_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing the next prayer and today's timetable.
 *
 * The values are written from Dart (see `WidgetService`) whenever prayer times
 * are recalculated; this class only paints them.
 */
class PrayerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.prayer_widget)

            views.setTextViewText(
                R.id.widget_next_label,
                widgetData.getString("next_label", "الصلاة القادمة")
            )
            views.setTextViewText(
                R.id.widget_next_name,
                widgetData.getString("next_name", "—")
            )
            views.setTextViewText(
                R.id.widget_next_time,
                widgetData.getString("next_time", "--:--")
            )
            views.setTextViewText(
                R.id.widget_countdown,
                widgetData.getString("countdown", "")
            )
            views.setTextViewText(
                R.id.widget_hijri,
                widgetData.getString("hijri", "")
            )

            PRAYERS.forEach { (key, ids) ->
                val (labelId, timeId) = ids
                views.setTextViewText(
                    labelId,
                    widgetData.getString("${key}_label", "") ?: ""
                )
                views.setTextViewText(
                    timeId,
                    widgetData.getString("${key}_time", "--:--")
                )
            }

            // Tapping anywhere opens the app.
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    companion object {
        private val PRAYERS = mapOf(
            "fajr" to Pair(R.id.widget_fajr_label, R.id.widget_fajr_time),
            "dhuhr" to Pair(R.id.widget_dhuhr_label, R.id.widget_dhuhr_time),
            "asr" to Pair(R.id.widget_asr_label, R.id.widget_asr_time),
            "maghrib" to Pair(R.id.widget_maghrib_label, R.id.widget_maghrib_time),
            "isha" to Pair(R.id.widget_isha_label, R.id.widget_isha_time),
        )
    }
}
