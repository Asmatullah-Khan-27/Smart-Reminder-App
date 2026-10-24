package com.premium.smartreminder.smart_reminder_alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.core.content.ContextCompat
import org.json.JSONObject

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_TRIGGER_ALARM = "com.premium.smartreminder.ACTION_TRIGGER_ALARM"
        const val ACTION_DISMISS_ALARM = "com.premium.smartreminder.ACTION_DISMISS_ALARM"
        const val ACTION_SNOOZE_ALARM = "com.premium.smartreminder.ACTION_SNOOZE_ALARM"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: ACTION_TRIGGER_ALARM
        val alarmId = intent.getStringExtra("alarm_id") ?: ""

        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SmartReminder:AlarmReceiverWakeLock"
        )
        wakeLock.acquire(30_000L)

        try {
            when (action) {
                ACTION_TRIGGER_ALARM -> {
                    val rawJson = intent.getStringExtra("alarm_json")
                    val record = if (!rawJson.isNullOrBlank()) {
                        NativeAlarmRecord.fromJson(JSONObject(rawJson))
                    } else {
                        AlarmScheduler.getPersistedAlarm(context, alarmId)
                    }

                    if (record != null) {
                        val serviceIntent = Intent(context, AlarmForegroundService::class.java).apply {
                            putExtra("alarm_id", record.id)
                            putExtra("alarm_json", record.toJson().toString())
                        }
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                ContextCompat.startForegroundService(context, serviceIntent)
                            } else {
                                context.startService(serviceIntent)
                            }
                        } catch (_: Exception) {
                            // Compliant fallback notification if OS restricts FGS start
                            AlarmForegroundService.postCompliantAlarmNotification(
                                context = context,
                                record = record
                            )
                        }
                    }
                }

                ACTION_DISMISS_ALARM -> {
                    AlarmForegroundService.stopIfMatchingAlarm(context, alarmId)
                    val existing = AlarmScheduler.getPersistedAlarm(context, alarmId)
                    if (existing != null) {
                        val nextRecurring = AlarmScheduler.computeNextBasicRecurringMillis(
                            existing,
                            System.currentTimeMillis()
                        )
                        if (nextRecurring != null) {
                            AlarmScheduler.scheduleAlarm(
                                context,
                                existing.copy(triggerAtMillis = nextRecurring, enabled = true)
                            )
                        } else {
                            AlarmScheduler.cancelAlarm(context, alarmId)
                        }
                    }
                    MainActivity.notifyFlutterAlarmAction("dismiss", alarmId)
                }

                ACTION_SNOOZE_ALARM -> {
                    AlarmForegroundService.stopIfMatchingAlarm(context, alarmId)
                    val existing = AlarmScheduler.getPersistedAlarm(context, alarmId)
                    if (existing != null) {
                        val snoozeMillis = System.currentTimeMillis() +
                            (existing.snoozeDurationMinutes.coerceAtLeast(1) * 60_000L)
                        AlarmScheduler.scheduleAlarm(
                            context,
                            existing.copy(triggerAtMillis = snoozeMillis, enabled = true)
                        )
                    }
                    MainActivity.notifyFlutterAlarmAction("snooze", alarmId)
                }
            }
        } finally {
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
    }
}
