package com.premium.smartreminder.smart_reminder_alarm

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

class SmartReminderWidgetProvider : AppWidgetProvider() {
    companion object {
        const val WIDGET_PREFS_NAME = "smart_reminder_widget_store"
        const val KEY_SNAPSHOT_JSON = "snapshot_json"
        const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
        const val FLUTTER_KEY_SNAPSHOT = "flutter.smart_reminder_widget_snapshot_json"
        const val ACTION_REFRESH_WIDGET = "com.premium.smartreminder.ACTION_REFRESH_WIDGET"

        fun saveSnapshotAndRefresh(context: Context, snapshotJson: String) {
            val prefs = context.getSharedPreferences(WIDGET_PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_SNAPSHOT_JSON, snapshotJson).apply()
            updateAllWidgets(context)
        }

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, SmartReminderWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids != null && ids.isNotEmpty()) {
                val intent = Intent(context, SmartReminderWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                context.sendBroadcast(intent)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH_WIDGET) {
            updateAllWidgets(context)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateSingleWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateSingleWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.smart_reminder_widget)

        val quickAddIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("widget_action", "quick_add_reminder")
        }
        val quickAddPending = PendingIntent.getActivity(
            context,
            7001,
            quickAddIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_btn_quick_add, quickAddPending)

        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPending = PendingIntent.getActivity(
            context,
            7000,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_header_container, openAppPending)

        val rawJson = readSnapshotJson(context)
        val rowContainerIds = intArrayOf(
            R.id.widget_item_1_container,
            R.id.widget_item_2_container,
            R.id.widget_item_3_container
        )
        val rowTitleIds = intArrayOf(
            R.id.widget_item_1_title,
            R.id.widget_item_2_title,
            R.id.widget_item_3_title
        )
        val rowTimeIds = intArrayOf(
            R.id.widget_item_1_time,
            R.id.widget_item_2_time,
            R.id.widget_item_3_time
        )

        if (rawJson.isNullOrBlank()) {
            views.setTextViewText(R.id.widget_next_alarm_text, "Next Alarm: None scheduled")
            views.setViewVisibility(R.id.widget_empty_text, View.VISIBLE)
            for (containerId in rowContainerIds) {
                views.setViewVisibility(containerId, View.GONE)
            }
        } else {
            try {
                val root = JSONObject(rawJson)
                val nextAlarm = root.optString("nextAlarmLabel", "No active alarm")
                val activeCount = root.optInt("totalActiveCount", 0)
                views.setTextViewText(
                    R.id.widget_next_alarm_text,
                    "Active: $activeCount • Next Alarm: $nextAlarm"
                )

                val items = root.optJSONArray("items")
                if (items == null || items.length() == 0) {
                    views.setViewVisibility(R.id.widget_empty_text, View.VISIBLE)
                    for (containerId in rowContainerIds) {
                        views.setViewVisibility(containerId, View.GONE)
                    }
                } else {
                    views.setViewVisibility(R.id.widget_empty_text, View.GONE)
                    for (i in rowContainerIds.indices) {
                        if (i < items.length()) {
                            val itemObj = items.optJSONObject(i)
                            val remId = itemObj?.optString("id", "") ?: ""
                            val title = itemObj?.optString("title", "Reminder") ?: "Reminder"
                            val timeStr = itemObj?.optString("formattedTime", "") ?: ""
                            val catName = itemObj?.optString("categoryName", "") ?: ""

                            views.setViewVisibility(rowContainerIds[i], View.VISIBLE)
                            views.setTextViewText(rowTitleIds[i], title)
                            views.setTextViewText(
                                rowTimeIds[i],
                                if (catName.isNotBlank()) "$catName • $timeStr" else timeStr
                            )

                            val openRemIntent = Intent(context, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                                putExtra("widget_action", "open_reminder")
                                putExtra("target_id", remId)
                            }
                            val openRemPending = PendingIntent.getActivity(
                                context,
                                7100 + i,
                                openRemIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                            views.setOnClickPendingIntent(rowContainerIds[i], openRemPending)
                        } else {
                            views.setViewVisibility(rowContainerIds[i], View.GONE)
                        }
                    }
                }
            } catch (_: Exception) {
                views.setViewVisibility(R.id.widget_empty_text, View.VISIBLE)
            }
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun readSnapshotJson(context: Context): String? {
        val dedicated = context.getSharedPreferences(WIDGET_PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SNAPSHOT_JSON, null)
        if (!dedicated.isNullOrBlank()) return dedicated

        return context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            .getString(FLUTTER_KEY_SNAPSHOT, null)
    }
}
