# Smart Reminder & Voice Alarm (Native Flutter + Android Kotlin)

A production-oriented native Android application built with **Flutter 3.47+ (Dart 3.13+)** and **Native Android Kotlin** featuring a custom **Material 3 Glassmorphism** design system, versioned **SQLite (`sqflite`)** persistence, deterministic recurrence calculations, custom **Text-to-Speech (TTS) Voice Alarms**, **Speech-to-Text (`speech_to_text`)** reminder dictation, a native **Android Home-Screen Widget (`AppWidgetProvider`)**, store-agnostic **Premium Entitlements**, and **100% offline-first** operation.

---

## Key Capabilities Implemented

1. **Functional SQLite-Backed Dashboard (`lib/presentation/screens/dashboard_screen.dart`)**
   - Displays Next Scheduled Native Alarm, Active Alarms, Overdue Reminders, Today's Reminders, Upcoming Reminders, and Completed Reminders loaded directly from SQLite.
   - Live search bar, category filter chips, sorting (`Time Earliest`, `Time Latest`, `Priority`, `Title`), and quick-add shortcuts.
   - Free/Premium tier status badge and pull-to-refresh synchronization.

2. **Versioned SQLite Persistence & Domain Logic (`lib/data/database/app_database.dart`)**
   - Schema Version 3 with automated migrations (`v1 → v2 → v3`), foreign key enforcement, and composite performance indexes.
   - Full CRUD repositories for `Reminder`, `Alarm`, `ReminderCategory`, `ThemeSettings`, `SpeechSettings`, `UserPreferences`, `PremiumEntitlement`, and `AdvertisingConfiguration`.

3. **Real Native Android Alarm Execution (`android/app/src/main/kotlin/...`)**
   - Uses `AlarmManager.setAlarmClock` / `setExactAndAllowWhileIdle` when `SCHEDULE_EXACT_ALARM` is granted on Android 12+ (API 31+), with automatic fallback to `setAndAllowWhileIdle` inexact scheduling if exact-alarm permission is denied.
   - Persists scheduled alarm metadata in a dedicated native registry (`native_scheduled_alarms_registry`) so `BootAndTimeChangeReceiver` (`BOOT_COMPLETED`, `LOCKED_BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `TIME_SET`, `TIMEZONE_CHANGED`) reschedules alarms without requiring a live Flutter isolate.
   - Launches `AlarmForegroundService` (`foregroundServiceType="mediaPlayback|specialUse"`) and `AlarmRingingActivity` (full-screen over lock screen when permitted, with compliant high-priority heads-up notification fallback).

4. **Custom Text-to-Speech (TTS) Voice Alarms & Ringtone Mode**
   - **Ringtone Mode**: Preset alarm/notification/ringtone sounds with native preview, snooze, and recurrence.
   - **Voice Alarm Mode**: Supports custom spoken wake-up messages such as:
     > `"Sir, time ho gaya hai. Uth jaiye aur apna kaam shuru karein."`
   - Configurable speech language (`ur-PK`, `hi-IN`, `en-US`, `en-GB`, `ar-SA`, `es-ES`), speech rate (`0.25x–1.5x`), pitch (`0.5–2.0`), in-app **Test Voice** (`flutter_tts`), and native background synthesis via Android's `android.speech.tts.TextToSpeech` inside `AlarmForegroundService` (with automatic ringtone fallback if TTS voice data is missing).

5. **Deterministic Recurrence Engine (`lib/domain/models/recurrence_rule.dart`)**
   - Supports `oneTime`, `daily`, `weekly`, `selectedWeekdays`, `monthly`, and `customInterval` (`hours`, `days`, `weeks`, `months`).
   - Clamps month-end dates across short months and leap years (`Jan 31 → Feb 28/29 → Mar 31`), preserves local wall-clock time across DST boundaries, and advances recurring items upon completion or dismissal.

6. **Speech-to-Text Voice Input (`lib/platform/voice_input_service.dart`)**
   - Uses `speech_to_text` to dictate reminder titles and notes hands-free with editable recognized text, locale selection, and graceful manual keyboard fallback.

7. **Categories with Atomic Safe Reassignment (`lib/data/repositories/category_repository.dart`)**
   - Seeds 6 default categories (`Personal`, `Work`, `Study`, `Health`, `Shopping`, `Other`).
   - Supports creating, editing, recoloring, and deleting custom categories. Deleting a custom category executes an atomic SQLite transaction that reassigns all associated reminders to a user-selected fallback category (`other` by default) so reminders are never silently deleted.

8. **Native Android Home-Screen Widget (`SmartReminderWidgetProvider.kt`)**
   - Displays active reminder count, next scheduled alarm, upcoming reminder titles/times, and a `+ Add` Quick-Add action.
   - Uses a deliberate `SharedPreferences` JSON snapshot bridge (`smart_reminder_widget_store`) written by `WidgetSyncBridge` to avoid cross-process SQLite locking.

9. **Local Versioned Backup & Transactional Restore (`lib/data/services/backup_service.dart`)**
   - Exports and restores reminders, alarms, categories, and settings using `SMART_REMINDER_VOICE_ALARM_BACKUP` (Schema v2).
   - Validates JSON structure and deduplicates internal IDs prior to import, supporting `Merge (Keep Existing)`, `Merge (Overwrite Duplicates)`, and `Replace All` inside a single SQLite transaction.

---

## Project Structure

```text
.
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── domain/
│   │   └── models/
│   │       ├── alarm.dart
│   │       ├── app_settings.dart
│   │       ├── backup_bundle.dart
│   │       ├── category.dart
│   │       ├── recurrence_rule.dart
│   │       └── reminder.dart
│   ├── data/
│   │   ├── database/
│   │   │   └── app_database.dart
│   │   ├── repositories/
│   │   │   ├── alarm_repository.dart
│   │   │   ├── category_repository.dart
│   │   │   ├── reminder_repository.dart
│   │   │   └── settings_repository.dart
│   │   └── services/
│   │       └── backup_service.dart
│   ├── platform/
│   │   ├── advertising_service.dart
│   │   ├── entitlement_billing_service.dart
│   │   ├── local_notification_service.dart
│   │   ├── native_alarm_bridge.dart
│   │   ├── tts_service.dart
│   │   ├── voice_input_service.dart
│   │   └── widget_sync_bridge.dart
│   └── presentation/
│       ├── state/
│       │   └── app_controller.dart
│       ├── theme/
│       │   └── glass_theme.dart
│       ├── widgets/
│       │   ├── glass_widgets.dart
│       │   └── recurrence_selector_widget.dart
│       └── screens/
│           ├── alarm_form_screen.dart
│           ├── alarm_list_screen.dart
│           ├── app_settings_screen.dart
│           ├── backup_export_screen.dart
│           ├── categories_screen.dart
│           ├── dashboard_screen.dart
│           ├── premium_upgrade_screen.dart
│           ├── privacy_permissions_screen.dart
│           ├── reminder_form_screen.dart
│           ├── reminder_list_screen.dart
│           ├── theme_settings_screen.dart
│           ├── voice_settings_screen.dart
│           └── widget_info_screen.dart
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml
│       ├── kotlin/com/premium/smartreminder/smart_reminder_alarm/
│       │   ├── MainActivity.kt
│       │   ├── AlarmScheduler.kt
│       │   ├── AlarmReceiver.kt
│       │   ├── BootAndTimeChangeReceiver.kt
│       │   ├── AlarmForegroundService.kt
│       │   ├── AlarmRingingActivity.kt
│       │   └── SmartReminderWidgetProvider.kt
│       └── res/
│           ├── drawable/widget_background.xml
│           ├── layout/activity_alarm_ringing.xml
│           ├── layout/smart_reminder_widget.xml
│           ├── values/strings.xml
│           └── xml/smart_reminder_widget_info.xml
└── test/
    ├── domain_and_recurrence_test.dart
    ├── database_and_repositories_test.dart
    └── widget_test.dart
```

---

## Running Analysis, Tests, and Android Builds

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Static analysis
flutter analyze

# 3. Run unit, SQLite FFI, and widget tests
flutter test -r expanded

# 4. Build Android APK & Google Play AAB (requires Android SDK + JDK 17)
flutter build apk --release
flutter build appbundle --release
```
