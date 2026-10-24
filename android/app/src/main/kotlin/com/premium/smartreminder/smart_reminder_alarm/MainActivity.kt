package com.premium.smartreminder.smart_reminder_alarm

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val ALARM_CHANNEL_NAME = "com.premium.smartreminder/native_alarm"
        private const val WIDGET_CHANNEL_NAME = "com.premium.smartreminder/widget_bridge"
        private const val REQ_CODE_POST_NOTIFICATIONS = 4101

        private var activeAlarmChannel: MethodChannel? = null

        fun notifyFlutterAlarmAction(action: String, alarmId: String) {
            activeAlarmChannel?.invokeMethod(
                "onAlarmActionFromNative",
                mapOf("action" to action, "alarmId" to alarmId)
            )
        }
    }

    private var widgetChannel: MethodChannel? = null
    private var initialWidgetAction: String? = null
    private var initialWidgetTargetId: String? = null
    private var activeRingtonePreview: Ringtone? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureWidgetIntent(intent)
        if (!initialWidgetAction.isNullOrBlank()) {
            widgetChannel?.invokeMethod(
                "onWidgetIntentAction",
                mapOf(
                    "action" to initialWidgetAction,
                    "targetId" to initialWidgetTargetId
                )
            )
        }
    }

    private fun captureWidgetIntent(intent: Intent?) {
        val action = intent?.getStringExtra("widget_action")
        if (!action.isNullOrBlank()) {
            initialWidgetAction = action
            initialWidgetTargetId = intent.getStringExtra("target_id")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val alarmChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ALARM_CHANNEL_NAME
        )
        activeAlarmChannel = alarmChannel

        alarmChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("INVALID_ARGS", "Expected alarm map", null)
                    } else {
                        val record = NativeAlarmRecord.fromMap(args)
                        val scheduleResult = AlarmScheduler.scheduleAlarm(applicationContext, record)
                        result.success(scheduleResult)
                    }
                }

                "cancelAlarm" -> {
                    val args = call.arguments as? Map<*, *>
                    val id = args?.get("id")?.toString() ?: ""
                    AlarmScheduler.cancelAlarm(applicationContext, id)
                    result.success(null)
                }

                "reconcileAlarms" -> {
                    val args = call.arguments as? Map<*, *>
                    val rawList = args?.get("alarms") as? List<*> ?: emptyList<Any>()
                    val records = rawList.mapNotNull { item ->
                        (item as? Map<*, *>)?.let { NativeAlarmRecord.fromMap(it) }
                    }
                    val count = AlarmScheduler.reconcileAlarms(applicationContext, records)
                    result.success(count)
                }

                "getPermissionStatus" -> {
                    result.success(buildPermissionStatusMap())
                }

                "requestExactAlarmPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        if (!AlarmScheduler.canScheduleExactAlarms(applicationContext)) {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                    }
                    result.success(AlarmScheduler.canScheduleExactAlarms(applicationContext))
                }

                "requestFullScreenIntentPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        if (!nm.canUseFullScreenIntent()) {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                    }
                    result.success(true)
                }

                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                    }
                    result.success(true)
                }

                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(
                                this,
                                Manifest.permission.POST_NOTIFICATIONS
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                REQ_CODE_POST_NOTIFICATIONS
                            )
                        }
                    }
                    result.success(true)
                }

                "previewRingtone" -> {
                    val args = call.arguments as? Map<*, *>
                    val ringtoneId = args?.get("ringtoneIdentifier")?.toString() ?: "default_alarm"
                    previewRingtoneSound(ringtoneId)
                    result.success(null)
                }

                "stopRingtonePreview" -> {
                    stopRingtonePreviewSound()
                    result.success(null)
                }

                "triggerTestAlarmNow" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        val record = NativeAlarmRecord.fromMap(args)
                        val triggerIntent = Intent(this, AlarmReceiver::class.java).apply {
                            action = AlarmReceiver.ACTION_TRIGGER_ALARM
                            putExtra("alarm_id", record.id)
                            putExtra("alarm_json", record.toJson().toString())
                        }
                        sendBroadcast(triggerIntent)
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        val wChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_CHANNEL_NAME
        )
        widgetChannel = wChannel

        wChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "syncWidgetSnapshot" -> {
                    val args = call.arguments as? Map<*, *>
                    val snapshotJson = args?.get("snapshotJson")?.toString() ?: ""
                    SmartReminderWidgetProvider.saveSnapshotAndRefresh(
                        applicationContext,
                        snapshotJson
                    )
                    result.success(true)
                }

                "consumeInitialWidgetAction" -> {
                    val action = initialWidgetAction
                    val target = initialWidgetTargetId
                    initialWidgetAction = null
                    initialWidgetTargetId = null
                    if (action != null) {
                        result.success(mapOf("action" to action, "targetId" to target))
                    } else {
                        result.success(null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun buildPermissionStatusMap(): Map<String, Any> {
        val exact = AlarmScheduler.canScheduleExactAlarms(applicationContext)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val fullScreen = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            nm.canUseFullScreenIntent()
        } else {
            true
        }
        val notifGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            nm.areNotificationsEnabled()
        }
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val batteryIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pm.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }

        return mapOf(
            "canScheduleExactAlarms" to exact,
            "canUseFullScreenIntent" to fullScreen,
            "notificationsGranted" to notifGranted,
            "batteryOptimizationIgnored" to batteryIgnored,
            "androidSdkInt" to Build.VERSION.SDK_INT
        )
    }

    private fun previewRingtoneSound(ringtoneId: String) {
        stopRingtonePreviewSound()
        try {
            val type = when (ringtoneId) {
                "gentle_sunrise" -> RingtoneManager.TYPE_NOTIFICATION
                "urgent_beacon" -> RingtoneManager.TYPE_RINGTONE
                else -> RingtoneManager.TYPE_ALARM
            }
            val uri = RingtoneManager.getDefaultUri(type)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            val r = RingtoneManager.getRingtone(applicationContext, uri)
            activeRingtonePreview = r
            r?.play()
        } catch (_: Exception) {}
    }

    private fun stopRingtonePreviewSound() {
        try {
            activeRingtonePreview?.stop()
        } catch (_: Exception) {}
        activeRingtonePreview = null
    }

    override fun onDestroy() {
        stopRingtonePreviewSound()
        if (activeAlarmChannel != null) {
            activeAlarmChannel = null
        }
        super.onDestroy()
    }
}
