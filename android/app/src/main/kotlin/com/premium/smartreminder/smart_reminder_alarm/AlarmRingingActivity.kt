package com.premium.smartreminder.smart_reminder_alarm

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import org.json.JSONObject

class AlarmRingingActivity : Activity() {
    private var alarmId: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureLockScreenWindow()
        setContentView(R.layout.activity_alarm_ringing)

        alarmId = intent?.getStringExtra("alarm_id") ?: ""
        val rawJson = intent?.getStringExtra("alarm_json")
        val record = if (!rawJson.isNullOrBlank()) {
            NativeAlarmRecord.fromJson(JSONObject(rawJson))
        } else {
            AlarmScheduler.getPersistedAlarm(this, alarmId)
        }

        val titleView = findViewById<TextView>(R.id.alarm_ringing_title)
        val subtitleView = findViewById<TextView>(R.id.alarm_ringing_subtitle)
        val modeBadgeView = findViewById<TextView>(R.id.alarm_ringing_mode_badge)
        val snoozeBtn = findViewById<Button>(R.id.btn_alarm_snooze)
        val dismissBtn = findViewById<Button>(R.id.btn_alarm_dismiss)

        if (record != null) {
            alarmId = record.id
            titleView.text = record.title
            modeBadgeView.text = if (record.alarmMode == "voice") {
                "VOICE ALARM (TTS) • ${record.speechLanguage}"
            } else {
                "RINGTONE ALARM"
            }
            subtitleView.text = if (record.alarmMode == "voice" && record.customMessage.isNotBlank()) {
                "\"${record.customMessage}\""
            } else if (record.notes.isNotBlank()) {
                record.notes
            } else {
                "Scheduled wake-up active"
            }
            snoozeBtn.text = "Snooze (+${record.snoozeDurationMinutes} min)"
        }

        snoozeBtn.setOnClickListener {
            val snoozeIntent = Intent(this, AlarmReceiver::class.java).apply {
                action = AlarmReceiver.ACTION_SNOOZE_ALARM
                putExtra("alarm_id", alarmId)
            }
            sendBroadcast(snoozeIntent)
            finish()
        }

        dismissBtn.setOnClickListener {
            val dismissIntent = Intent(this, AlarmReceiver::class.java).apply {
                action = AlarmReceiver.ACTION_DISMISS_ALARM
                putExtra("alarm_id", alarmId)
            }
            sendBroadcast(dismissIntent)
            finish()
        }
    }

    private fun configureLockScreenWindow() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            km.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }
}
