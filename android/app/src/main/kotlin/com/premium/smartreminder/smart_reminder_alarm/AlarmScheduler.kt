package com.premium.smartreminder.smart_reminder_alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

data class NativeAlarmRecord(
    val id: String,
    val title: String,
    val notes: String,
    val alarmMode: String,
    val customMessage: String,
    val speechLanguage: String,
    val speechRate: Float,
    val speechPitch: Float,
    val ringtoneIdentifier: String,
    val triggerAtMillis: Long,
    val scheduledDateTimeMillis: Long,
    val recurrenceRuleJson: String,
    val snoozeDurationMinutes: Int,
    val enabled: Boolean
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("title", title)
            put("notes", notes)
            put("alarmMode", alarmMode)
            put("customMessage", customMessage)
            put("speechLanguage", speechLanguage)
            put("speechRate", speechRate.toDouble())
            put("speechPitch", speechPitch.toDouble())
            put("ringtoneIdentifier", ringtoneIdentifier)
            put("triggerAtMillis", triggerAtMillis)
            put("scheduledDateTimeMillis", scheduledDateTimeMillis)
            put("recurrenceRuleJson", recurrenceRuleJson)
            put("snoozeDurationMinutes", snoozeDurationMinutes)
            put("enabled", enabled)
        }
    }

    companion object {
        fun fromJson(obj: JSONObject): NativeAlarmRecord {
            return NativeAlarmRecord(
                id = obj.optString("id", ""),
                title = obj.optString("title", "Scheduled Alarm"),
                notes = obj.optString("notes", ""),
                alarmMode = obj.optString("alarmMode", "ringtone"),
                customMessage = obj.optString("customMessage", ""),
                speechLanguage = obj.optString("speechLanguage", "en-US"),
                speechRate = obj.optDouble("speechRate", 0.5).toFloat(),
                speechPitch = obj.optDouble("speechPitch", 1.0).toFloat(),
                ringtoneIdentifier = obj.optString("ringtoneIdentifier", "default_alarm"),
                triggerAtMillis = obj.optLong("triggerAtMillis", System.currentTimeMillis() + 60_000L),
                scheduledDateTimeMillis = obj.optLong("scheduledDateTimeMillis", System.currentTimeMillis()),
                recurrenceRuleJson = obj.optString("recurrenceRuleJson", "{\"frequency\":\"oneTime\"}"),
                snoozeDurationMinutes = obj.optInt("snoozeDurationMinutes", 10),
                enabled = obj.optBoolean("enabled", true)
            )
        }

        fun fromMap(map: Map<*, *>): NativeAlarmRecord {
            return NativeAlarmRecord(
                id = map["id"]?.toString() ?: "",
                title = map["title"]?.toString() ?: "Scheduled Alarm",
                notes = map["notes"]?.toString() ?: "",
                alarmMode = map["alarmMode"]?.toString() ?: "ringtone",
                customMessage = map["customMessage"]?.toString() ?: "",
                speechLanguage = map["speechLanguage"]?.toString() ?: "en-US",
                speechRate = (map["speechRate"] as? Number)?.toFloat() ?: 0.5f,
                speechPitch = (map["speechPitch"] as? Number)?.toFloat() ?: 1.0f,
                ringtoneIdentifier = map["ringtoneIdentifier"]?.toString() ?: "default_alarm",
                triggerAtMillis = (map["triggerAtMillis"] as? Number)?.toLong()
                    ?: (System.currentTimeMillis() + 60_000L),
                scheduledDateTimeMillis = (map["scheduledDateTimeMillis"] as? Number)?.toLong()
                    ?: System.currentTimeMillis(),
                recurrenceRuleJson = map["recurrenceRuleJson"]?.toString()
                    ?: "{\"frequency\":\"oneTime\"}",
                snoozeDurationMinutes = (map["snoozeDurationMinutes"] as? Number)?.toInt() ?: 10,
                enabled = (map["enabled"] as? Boolean) ?: true
            )
        }
    }
}

object AlarmScheduler {
    private const val PREFS_NAME = "native_scheduled_alarms_registry"
    private const val KEY_ALARMS_JSON = "alarms_json_map"

    fun canScheduleExactAlarms(context: Context): Boolean {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    fun scheduleAlarm(context: Context, record: NativeAlarmRecord): Map<String, Any?> {
        if (!record.enabled || record.id.isBlank()) {
            cancelAlarm(context, record.id)
            return mapOf(
                "scheduled" to false,
                "usedExactAlarm" to false,
                "scheduledEpochMillis" to null,
                "statusMessage" to "Alarm disabled; removed from Android AlarmManager."
            )
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildTriggerPendingIntent(context, record)
        val now = System.currentTimeMillis()
        val effectiveTrigger = if (record.triggerAtMillis <= now) {
            now + 5_000L
        } else {
            record.triggerAtMillis
        }

        val exactPermitted = canScheduleExactAlarms(context)
        try {
            if (exactPermitted) {
                val showIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val showPendingIntent = PendingIntent.getActivity(
                    context,
                    record.id.hashCode(),
                    showIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val clockInfo = AlarmManager.AlarmClockInfo(effectiveTrigger, showPendingIntent)
                alarmManager.setAlarmClock(clockInfo, pendingIntent)
            } else {
                // Inexact fallback when SCHEDULE_EXACT_ALARM is denied by user
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    effectiveTrigger,
                    pendingIntent
                )
            }
        } catch (secEx: SecurityException) {
            // Fallback to inexact scheduling if SecurityException is thrown
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                effectiveTrigger,
                pendingIntent
            )
            persistAlarmRecord(context, record.copy(triggerAtMillis = effectiveTrigger))
            return mapOf(
                "scheduled" to true,
                "usedExactAlarm" to false,
                "scheduledEpochMillis" to effectiveTrigger,
                "statusMessage" to "Scheduled via inexact fallback (exact alarm permission denied: ${secEx.message})."
            )
        }

        persistAlarmRecord(context, record.copy(triggerAtMillis = effectiveTrigger))

        val statusMsg = if (exactPermitted) {
            "Scheduled exact Android AlarmClock wake-up."
        } else {
            "Scheduled using inexact fallback (grant Exact Alarm permission for Doze precision)."
        }
        return mapOf(
            "scheduled" to true,
            "usedExactAlarm" to exactPermitted,
            "scheduledEpochMillis" to effectiveTrigger,
            "statusMessage" to statusMsg
        )
    }

    fun cancelAlarm(context: Context, alarmId: String) {
        if (alarmId.isBlank()) return
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_TRIGGER_ALARM
            putExtra("alarm_id", alarmId)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCodeForAlarm(alarmId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        removePersistedAlarmRecord(context, alarmId)
        AlarmForegroundService.stopIfMatchingAlarm(context, alarmId)
    }

    fun reconcileAlarms(context: Context, records: List<NativeAlarmRecord>): Int {
        val existing = loadPersistedAlarms(context)
        val incomingIds = records.map { it.id }.toSet()

        // Cancel any previously scheduled alarms that are no longer enabled in SQLite
        for (old in existing) {
            if (!incomingIds.contains(old.id)) {
                cancelAlarm(context, old.id)
            }
        }

        var count = 0
        for (record in records) {
            if (record.enabled && record.triggerAtMillis > System.currentTimeMillis() - 60_000L) {
                scheduleAlarm(context, record)
                count++
            }
        }
        return count
    }

    fun rescheduleAllPersistedAlarms(context: Context): Int {
        val persisted = loadPersistedAlarms(context)
        val now = System.currentTimeMillis()
        var rescheduled = 0
        for (record in persisted) {
            if (!record.enabled) continue
            var nextTrigger = record.triggerAtMillis
            if (nextTrigger <= now) {
                val nextRecurring = computeNextBasicRecurringMillis(record, now)
                if (nextRecurring != null) {
                    nextTrigger = nextRecurring
                } else {
                    continue
                }
            }
            scheduleAlarm(context, record.copy(triggerAtMillis = nextTrigger))
            rescheduled++
        }
        return rescheduled
    }

    fun computeNextBasicRecurringMillis(record: NativeAlarmRecord, nowMillis: Long): Long? {
        return try {
            val ruleObj = JSONObject(record.recurrenceRuleJson)
            val freq = ruleObj.optString("frequency", "oneTime")
            val interval = ruleObj.optInt("interval", 1).coerceAtLeast(1)
            when (freq) {
                "oneTime" -> null
                "daily" -> {
                    val step = interval * 24L * 60L * 60L * 1000L
                    var candidate = record.triggerAtMillis
                    while (candidate <= nowMillis) {
                        candidate += step
                    }
                    candidate
                }
                "weekly", "selectedWeekdays" -> {
                    val step = 24L * 60L * 60L * 1000L
                    var candidate = record.triggerAtMillis + step
                    while (candidate <= nowMillis) {
                        candidate += step
                    }
                    candidate
                }
                else -> {
                    val step = 24L * 60L * 60L * 1000L
                    nowMillis + step
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    fun getPersistedAlarm(context: Context, alarmId: String): NativeAlarmRecord? {
        return loadPersistedAlarms(context).firstOrNull { it.id == alarmId }
    }

    private fun buildTriggerPendingIntent(context: Context, record: NativeAlarmRecord): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_TRIGGER_ALARM
            putExtra("alarm_id", record.id)
            putExtra("alarm_json", record.toJson().toString())
        }
        return PendingIntent.getBroadcast(
            context,
            requestCodeForAlarm(record.id),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun requestCodeForAlarm(alarmId: String): Int {
        return alarmId.hashCode() and 0x7FFFFFFF
    }

    private fun persistAlarmRecord(context: Context, record: NativeAlarmRecord) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val current = loadPersistedAlarms(context).filter { it.id != record.id }.toMutableList()
        current.add(record)
        val array = JSONArray()
        for (item in current) {
            array.put(item.toJson())
        }
        prefs.edit().putString(KEY_ALARMS_JSON, array.toString()).apply()
    }

    private fun removePersistedAlarmRecord(context: Context, alarmId: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val remaining = loadPersistedAlarms(context).filter { it.id != alarmId }
        val array = JSONArray()
        for (item in remaining) {
            array.put(item.toJson())
        }
        prefs.edit().putString(KEY_ALARMS_JSON, array.toString()).apply()
    }

    fun loadPersistedAlarms(context: Context): List<NativeAlarmRecord> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_ALARMS_JSON, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            val list = mutableListOf<NativeAlarmRecord>()
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i) ?: continue
                list.add(NativeAlarmRecord.fromJson(obj))
            }
            list
        } catch (_: Exception) {
            emptyList()
        }
    }
}
