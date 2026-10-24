# System Architecture — Smart Reminder & Voice Alarm

## 1. Architectural Overview

The application follows a strict four-layer modular architecture designed for offline reliability, testability, and safe native Android interop:

1. **Domain Layer (`lib/domain/`)**:
   - Pure Dart entities (`Reminder`, `Alarm`, `ReminderCategory`, `RecurrenceRule`, `ThemeSettings`, `SpeechSettings`, `UserPreferences`, `PremiumEntitlement`, `AdvertisingConfiguration`, `BackupBundle`) and the deterministic `RecurrenceEngine`.
   - Zero dependency on Flutter UI widgets or platform plugins, enabling fast deterministic unit tests.

2. **Data Layer (`lib/data/`)**:
   - `AppDatabase`: Versioned SQLite engine (`sqflite`, schema v3) supporting `v1 → v2 → v3` incremental schema upgrades and injectable `DatabaseFactory` (`sqflite_common_ffi`) for desktop/CI test execution.
   - Repositories (`ReminderRepository`, `AlarmRepository`, `CategoryRepository`, `SettingsRepository`) and `BackupService` using explicit SQLite transactions.

3. **Platform & Service Integration Layer (`lib/platform/`)**:
   - `NativeAlarmBridge`: MethodChannel (`com.premium.smartreminder/native_alarm`) communicating with Kotlin `MainActivity` and `AlarmScheduler`.
   - `WidgetSyncBridge`: MethodChannel (`com.premium.smartreminder/widget_bridge`) + `SharedPreferences` JSON snapshot bridge to `SmartReminderWidgetProvider`.
   - `LocalNotificationService`: `flutter_local_notifications` wrapper for reminder alerts.
   - `TtsService`: `flutter_tts` wrapper for interactive voice preview and reminder readout.
   - `VoiceInputService`: `speech_to_text` wrapper for hands-free reminder dictation.
   - `EntitlementBillingService`: Store-agnostic subscription entitlement service with `GooglePlayBillingProvider` and `AmazonAppstoreBillingProvider` integration points.
   - `AdvertisingService`: Test-mode safe AdMob/Amazon Ads abstraction with hard alarm-ringing suppression guards.

4. **Presentation Layer (`lib/presentation/`)**:
   - `AppController`: Central `ChangeNotifier` state coordinator that reconciles SQLite records with Android `AlarmManager` and the Home-Screen Widget on every mutation.
   - `GlassTheme` & `GlassWidgets`: Material 3 + frosted glassmorphism design system supporting Light, Dark, System Default, and Automatic Day/Night schedules (including midnight-crossing windows).
   - 13 dedicated screens covering all functional workflows.

---

## 2. Native Android Alarm & Spoken TTS Execution Path

A core architectural requirement is that **scheduled alarms and spoken TTS messages must not depend on a live Flutter UI engine or Dart isolate**, because the Android OS can reclaim backgrounded UI processes at any time.

### Execution Lifecycle

```text
[Flutter UI / AppController]
       │  saveAlarm / toggleAlarmEnabled / reconcileAlarms
       ▼
[MethodChannel: com.premium.smartreminder/native_alarm]
       │
       ▼
[AlarmScheduler.kt]
  ├─ Persists NativeAlarmRecord in SharedPreferences ("native_scheduled_alarms_registry")
  └─ Checks AlarmManager.canScheduleExactAlarms() (API 31+)
       ├─ TRUE  ──► AlarmManager.setAlarmClock(...)
       └─ FALSE ──► AlarmManager.setAndAllowWhileIdle(...) (Inexact fallback)
       │
       ▼  (At Trigger Epoch Millis, or after Reboot via BootAndTimeChangeReceiver.kt)
[AlarmReceiver.kt (BroadcastReceiver)]
  ├─ Acquires timed PARTIAL_WAKE_LOCK (30s)
  └─ Starts AlarmForegroundService (or posts compliant fallback notification)
       │
       ▼
[AlarmForegroundService.kt (ForegroundService: mediaPlayback|specialUse)]
  ├─ Posts NotificationCompat (CATEGORY_ALARM, PRIORITY_MAX, fullScreenIntent -> AlarmRingingActivity)
  ├─ Requests AudioFocus (USAGE_ALARM, AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
  └─ Checks record.alarmMode:
       ├─ "voice"    ──► Initializes native android.speech.tts.TextToSpeech
       │                 Speaks customMessage on STREAM_ALARM in configured language/rate/pitch
       │                 (Falls back to MediaPlayer alarm ringtone if TTS init/voice fails)
       └─ "ringtone" ──► Loops MediaPlayer on USAGE_ALARM with selected RingtoneManager URI
```

---

## 3. Home-Screen Widget Data-Sharing Strategy

Directly opening a private SQLite database file from both a Flutter isolate and an Android `AppWidgetProvider` broadcast receiver can cause `SQLITE_BUSY` locking errors or corrupted WAL journals.

To prevent this:
1. Whenever reminders or alarms change in SQLite, `AppController` calls `WidgetSyncBridge.syncHomeScreenWidget(...)`.
2. `WidgetSyncBridge` serializes a compact, pre-formatted JSON snapshot (`WidgetSnapshotPayload`) containing active reminder counts, overdue counts, the next scheduled alarm label, and the top upcoming reminders.
3. `MainActivity` writes this JSON string into a dedicated Android `SharedPreferences` store (`smart_reminder_widget_store`) and broadcasts `AppWidgetManager.ACTION_APPWIDGET_UPDATE`.
4. `SmartReminderWidgetProvider.kt` reads `smart_reminder_widget_store` synchronously in `onUpdate`, populates `RemoteViews` (`res/layout/smart_reminder_widget.xml`), and attaches `PendingIntent`s for opening individual reminders or launching Quick-Add.
