package com.premium.smartreminder.smart_reminder_alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.util.Locale

class AlarmForegroundService : Service(), TextToSpeech.OnInitListener {
    companion object {
        const val CHANNEL_ID = "native_voice_alarm_channel"
        const val NOTIFICATION_ID = 9041

        private var activeAlarmId: String? = null

        fun stopIfMatchingAlarm(context: Context, alarmId: String) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIFICATION_ID)
            if (activeAlarmId == null || activeAlarmId == alarmId || alarmId.isBlank()) {
                context.stopService(Intent(context, AlarmForegroundService::class.java))
            }
        }

        fun ensureNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                    val channel = NotificationChannel(
                        CHANNEL_ID,
                        "Smart Alarms & Spoken Wake-Ups",
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "Full-screen and spoken TTS alarm alerts"
                        enableVibration(true)
                        lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    }
                    nm.createNotificationChannel(channel)
                }
            }
        }

        fun buildAlarmNotification(context: Context, record: NativeAlarmRecord): Notification {
            ensureNotificationChannel(context)

            val fullScreenIntent = Intent(context, AlarmRingingActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("alarm_id", record.id)
                putExtra("alarm_json", record.toJson().toString())
            }
            val fullScreenPendingIntent = PendingIntent.getActivity(
                context,
                record.id.hashCode() xor 0x1111,
                fullScreenIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val snoozeIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = AlarmReceiver.ACTION_SNOOZE_ALARM
                putExtra("alarm_id", record.id)
            }
            val snoozePendingIntent = PendingIntent.getBroadcast(
                context,
                record.id.hashCode() xor 0x2222,
                snoozeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = AlarmReceiver.ACTION_DISMISS_ALARM
                putExtra("alarm_id", record.id)
            }
            val dismissPendingIntent = PendingIntent.getBroadcast(
                context,
                record.id.hashCode() xor 0x3333,
                dismissIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val bodyText = if (record.alarmMode == "voice" && record.customMessage.isNotBlank()) {
                "Voice Alarm: \"${record.customMessage}\""
            } else if (record.notes.isNotBlank()) {
                record.notes
            } else {
                "Scheduled alarm is ringing"
            }

            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(record.title)
                .setContentText(bodyText)
                .setStyle(NotificationCompat.BigTextStyle().bigText(bodyText))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setOngoing(true)
                .setAutoCancel(false)
                .setFullScreenIntent(fullScreenPendingIntent, true)
                .setContentIntent(fullScreenPendingIntent)
                .addAction(
                    android.R.drawable.ic_popup_reminder,
                    "Snooze (+${record.snoozeDurationMinutes}m)",
                    snoozePendingIntent
                )
                .addAction(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Dismiss",
                    dismissPendingIntent
                )
                .build()
        }

        fun postCompliantAlarmNotification(context: Context, record: NativeAlarmRecord) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, buildAlarmNotification(context, record))
        }
    }

    private var currentRecord: NativeAlarmRecord? = null
    private var mediaPlayer: MediaPlayer? = null
    private var textToSpeech: TextToSpeech? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var speechLoopCount = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val rawJson = intent?.getStringExtra("alarm_json")
        val alarmId = intent?.getStringExtra("alarm_id") ?: ""
        val record = if (!rawJson.isNullOrBlank()) {
            NativeAlarmRecord.fromJson(JSONObject(rawJson))
        } else {
            AlarmScheduler.getPersistedAlarm(this, alarmId)
        }

        if (record == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        currentRecord = record
        activeAlarmId = record.id

        val notification = buildAlarmNotification(this, record)
        startForeground(NOTIFICATION_ID, notification)

        requestAlarmAudioFocus()
        stopActivePlayback()

        if (record.alarmMode == "voice" && record.customMessage.isNotBlank()) {
            startVoiceAlarmTts(record)
        } else {
            startRingtonePlayback(record.ringtoneIdentifier)
        }

        return START_REDELIVER_INTENT
    }

    private fun requestAlarmAudioFocus() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attrs)
                .setAcceptsDelayedFocusGain(false)
                .setOnAudioFocusChangeListener { }
                .build()
            audioFocusRequest = req
            audioManager.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            )
        }
    }

    private fun abandonAlarmAudioFocus() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
    }

    private fun startVoiceAlarmTts(record: NativeAlarmRecord) {
        speechLoopCount = 0
        try {
            textToSpeech = TextToSpeech(applicationContext, this)
        } catch (_: Exception) {
            // Fallback to ringtone if TTS service cannot be bound
            startRingtonePlayback(record.ringtoneIdentifier)
        }
    }

    override fun onInit(status: Int) {
        val record = currentRecord ?: return
        val tts = textToSpeech
        if (status != TextToSpeech.SUCCESS || tts == null) {
            startRingtonePlayback(record.ringtoneIdentifier)
            return
        }

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        tts.setAudioAttributes(attrs)

        val desiredLocale = Locale.forLanguageTag(record.speechLanguage)
        var langResult = tts.setLanguage(desiredLocale)
        if (langResult == TextToSpeech.LANG_MISSING_DATA ||
            langResult == TextToSpeech.LANG_NOT_SUPPORTED
        ) {
            // Try Hindi/Indo-Aryan fallback for Roman Urdu, then US English
            langResult = tts.setLanguage(Locale.forLanguageTag("hi-IN"))
            if (langResult == TextToSpeech.LANG_MISSING_DATA ||
                langResult == TextToSpeech.LANG_NOT_SUPPORTED
            ) {
                tts.setLanguage(Locale.US)
            }
        }

        tts.setSpeechRate(record.speechRate.coerceIn(0.25f, 1.5f))
        tts.setPitch(record.speechPitch.coerceIn(0.5f, 2.0f))

        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}

            override fun onDone(utteranceId: String?) {
                speechLoopCount++
                if (speechLoopCount < 5 && activeAlarmId == record.id) {
                    mainHandler.postDelayed({
                        speakCurrentRecordOnce(record)
                    }, 1800L)
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                mainHandler.post {
                    startRingtonePlayback(record.ringtoneIdentifier)
                }
            }
        })

        speakCurrentRecordOnce(record)
    }

    private fun speakCurrentRecordOnce(record: NativeAlarmRecord) {
        val tts = textToSpeech ?: return
        val params = Bundle().apply {
            putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_ALARM)
            putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f)
        }
        tts.speak(
            record.customMessage,
            TextToSpeech.QUEUE_FLUSH,
            params,
            "voice_alarm_${record.id}_$speechLoopCount"
        )
    }

    private fun startRingtonePlayback(ringtoneId: String) {
        try {
            val uri = resolveRingtoneUri(ringtoneId)
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            player.setDataSource(applicationContext, uri)
            player.isLooping = true
            player.prepare()
            player.start()
            mediaPlayer = player
        } catch (_: Exception) {
            // Ignore if audio hardware unavailable
        }
    }

    private fun resolveRingtoneUri(ringtoneId: String): Uri {
        val type = when (ringtoneId) {
            "gentle_sunrise" -> RingtoneManager.TYPE_NOTIFICATION
            "urgent_beacon" -> RingtoneManager.TYPE_RINGTONE
            else -> RingtoneManager.TYPE_ALARM
        }
        return RingtoneManager.getDefaultUri(type)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
    }

    private fun stopActivePlayback() {
        mainHandler.removeCallbacksAndMessages(null)
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        } catch (_: Exception) {}
        mediaPlayer = null

        try {
            textToSpeech?.stop()
            textToSpeech?.shutdown()
        } catch (_: Exception) {}
        textToSpeech = null
    }

    override fun onDestroy() {
        activeAlarmId = null
        stopActivePlayback()
        abandonAlarmAudioFocus()
        super.onDestroy()
    }
}
