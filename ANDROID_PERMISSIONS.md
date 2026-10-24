# Android Permissions & Background Reliability Guide

This document details every Android permission declared in `android/app/src/main/AndroidManifest.xml`, why it is required, how runtime permission requests are handled in context, and the platform reliability boundaries.

---

## 1. Declared Permissions & Policy Rationale

| Permission | Target API / Scope | Purpose in Smart Reminder & Voice Alarm |
| :--- | :--- | :--- |
| `android.permission.POST_NOTIFICATIONS` | Android 13+ (API 33+) Runtime | Displays scheduled reminder notifications and high-priority heads-up alarm notifications with Snooze/Dismiss actions. |
| `android.permission.SCHEDULE_EXACT_ALARM` | Android 12+ (API 31+) Special App Access | Allows `AlarmScheduler.kt` to schedule exact wake-up alarms via `AlarmManager.setAlarmClock`. Uses `SCHEDULE_EXACT_ALARM` (user-grantable via `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`) so the app remains compliant with Google Play policies for reminder/productivity apps that also offer alarm features. |
| `android.permission.USE_FULL_SCREEN_INTENT` | Android 14+ (API 34+) Special App Access | Enables `AlarmForegroundService` to launch `AlarmRingingActivity` over the lock screen when an alarm fires. If denied or restricted on Android 14+, the notification gracefully degrades to an ongoing `PRIORITY_MAX` heads-up notification with Snooze and Dismiss action buttons. |
| `android.permission.RECEIVE_BOOT_COMPLETED` | Install-time | Allows `BootAndTimeChangeReceiver.kt` to receive `BOOT_COMPLETED` and `LOCKED_BOOT_COMPLETED` broadcasts and reschedule persisted alarms after a device restart. |
| `android.permission.WAKE_LOCK` | Install-time | Allows `AlarmReceiver.kt` to hold a bounded 30-second partial wake lock while transitioning from the broadcast receiver into `AlarmForegroundService`. |
| `android.permission.FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK` / `FOREGROUND_SERVICE_SPECIAL_USE` | Android 9+ / Android 14+ | Required to run `AlarmForegroundService` while playing alarm ringtones or synthesizing custom spoken TTS alarm messages in the background. |
| `android.permission.RECORD_AUDIO` | Android 6+ (API 23+) Runtime | Requested strictly in context when the user taps **Dictate Title** or **Dictate Notes** (`speech_to_text`). If denied, manual keyboard entry remains fully available. |
| `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Optional User Action | Allows users on aggressive OEM devices to exempt the app from battery restrictions via `PrivacyPermissionsScreen`. |

---

## 2. Permissions Intentionally NOT Requested

- **Location (`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`)**: Never requested. Automatic Day/Night theme scheduling uses the user's configured local clock start/end hours (supporting midnight-crossing ranges) rather than GPS coordinates.
- **Contacts / Storage / Camera / Phone State**: Never requested. Versioned backups are exported to the app's documents directory or copied as JSON without broad external storage permissions.

---

## 3. Reboot, Timezone & Clock Change Recovery

`BootAndTimeChangeReceiver.kt` registers for:
- `android.intent.action.BOOT_COMPLETED`
- `android.intent.action.LOCKED_BOOT_COMPLETED`
- `android.intent.action.MY_PACKAGE_REPLACED`
- `android.intent.action.TIME_SET`
- `android.intent.action.TIMEZONE_CHANGED`

When any of these broadcasts fire, `AlarmScheduler.rescheduleAllPersistedAlarms(context)` reads `native_scheduled_alarms_registry` and re-registers all enabled future and recurring alarms with `AlarmManager`. Additionally, whenever the Flutter UI opens, `AppController.refreshAll()` executes `NativeAlarmBridge.reconcileAlarms(...)` to reconcile SQLite records with the native Android registry.

---

## 4. Transparent Platform Limitations

No Android application can guarantee background alarm execution under the following OS-enforced conditions:
1. **Explicit User "Force Stop"**: If the user opens Android Settings and clicks **Force Stop**, the Android OS cancels all pending `AlarmManager` intents and blocks broadcast receivers until the user manually launches the app again.
2. **OEM Vendor Deep-Sleep Killers**: Certain OEM skins (Xiaomi MIUI, Huawei EMUI, Oppo ColorOS, Vivo Funtouch, Samsung "Deep Sleeping Apps") may block background services unless the user enables "Autostart" or exempts the app from battery optimization.
3. **Missing TTS Voice Data**: If a user configures a Voice Alarm in a language (`ur-PK`, `hi-IN`, `ar-SA`, etc.) whose offline voice pack is not installed in Google Speech Services, `AlarmForegroundService.kt` automatically falls back to `hi-IN`, then `en-US`, and if TTS initialization fails altogether, plays the configured fallback alarm ringtone so the alarm is never silent.
