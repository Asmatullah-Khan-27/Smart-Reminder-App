# Google Play Store & Amazon Appstore Release Checklist

This guide provides step-by-step instructions for preparing, signing, building, and submitting **Smart Reminder & Voice Alarm** to the **Google Play Store** and **Amazon Appstore**.

> **Important Status Notice**: This application has **not** been automatically published or store-approved. Complete the keystore generation, store billing SKU binding, and physical device QA checklist below before submitting to production tracks.

---

## 1. Application Metadata & Versioning

- **Default Application ID**: `com.premium.smartreminder.smart_reminder_alarm`
  - Can be overridden at build time via `-PappId=com.yourcompany.smartreminder` in `android/app/build.gradle.kts`.
- **App Display Name**: `Smart Reminder & Voice Alarm` (`android/app/src/main/res/values/strings.xml`)
- **Version**: `1.2.0+12` (`versionName: 1.2.0`, `versionCode: 12` in `pubspec.yaml`)
- **Minimum SDK**: API 24 (Android 7.0)
- **Target SDK**: Configured via `flutter.targetSdkVersion` (API 35 / Android 15 ready)

---

## 2. Release Keystore & Signing Configuration

1. **Generate an Upload Keystore** (run outside the repository so the `.jks` file is never committed to Git):
   ```bash
   keytool -genkey -v \
     -keystore ~/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias upload
   ```

2. **Create `android/key.properties`** (already supported by `android/app/build.gradle.kts` and ignored by `.gitignore`):
   ```properties
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=upload
   storeFile=/absolute/path/to/upload-keystore.jks
   ```

---

## 3. Building for Google Play Store (AAB)

Google Play requires an **Android App Bundle (`.aab`)** signed with your upload key:

```bash
flutter clean
flutter pub get
flutter test
flutter build appbundle --release
```

- **Artifact Output Path**:
  `build/app/outputs/bundle/release/app-release.aab`

### Google Play Console App Content Declarations
1. **Exact Alarm Permission (`SCHEDULE_EXACT_ALARM`)**:
   - In Play Console → *App content* → *Exact alarm permission*, declare that the app provides user-scheduled reminders and wake-up voice alarms requiring exact-minute delivery.
2. **Foreground Service Permission (`FOREGROUND_SERVICE_MEDIA_PLAYBACK` / `FOREGROUND_SERVICE_SPECIAL_USE`)**:
   - Declare that `AlarmForegroundService` plays audible alarm ringtones and spoken Text-to-Speech wake-up messages at user-scheduled alarm times, with visible Snooze/Dismiss controls.
3. **Google Play Billing SKUs**:
   - Create subscription products matching `GooglePlayBillingProvider`:
     - `smart_reminder_premium_monthly`
     - `smart_reminder_premium_annual`

---

## 4. Building for Amazon Appstore (Universal APK)

Amazon Appstore accepts a signed universal release **APK** (or split APKs) integrated with Amazon In-App Purchasing (IAP):

```bash
flutter clean
flutter pub get
flutter build apk --release
```

- **Artifact Output Path**:
  `build/app/outputs/flutter-apk/app-release.apk`

### Amazon Developer Console Checklist
1. **Amazon IAP SKUs**:
   - Configure subscription SKUs matching `AmazonAppstoreBillingProvider`:
     - `amzn_smart_reminder_pro_monthly`
     - `amzn_smart_reminder_pro_annual`
2. **Amazon App Tester Verification**:
   - Export the JSON SKU configuration file from Amazon Developer Console to `/sdcard/amazon.sdktester.json` on a Fire OS / Android test device to verify sandbox purchase flows before live submission.

---

## 5. Data Safety & Privacy Policy Requirements

Use the following factual disclosures when completing the **Google Play Data Safety** form and hosting your public Privacy Policy URL:

- **Data Collection & Sharing**:
  - **Personal Reminders, Notes, Spoken Alarm Scripts, Categories**: Stored **100% locally** in on-device SQLite (`smart_reminder_voice_alarm.db`) and local `SharedPreferences`. Not transmitted to any developer cloud server.
  - **Microphone Audio (`RECORD_AUDIO`)**: Processed ephemerally via the device's on-device/system `RecognitionService` (`speech_to_text`) only when the user explicitly taps the Dictate button. Audio is never recorded to disk or uploaded by the app.
  - **Location**: Not collected or requested (`ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` are absent from the manifest).
  - **Advertising Identifiers**: Only used if you enable production AdMob / Amazon Ads SDKs in a non-test release build; disabled for Premium users.

---

## 6. Store Screenshots & Pre-Submission QA Checklist

### Required Store Screenshots
- [ ] **Phone (16:9 / 9:16, min 1080×1920)**:
  1. Dashboard showing Next Scheduled Alarm, Today's Reminders, and Category Chips.
  2. Create Voice Alarm screen showing custom Roman Urdu TTS message (`"Sir, time ho gaya hai..."`), rate/pitch sliders, and Test Voice button.
  3. Create Reminder screen showing Speech-to-Text Voice Dictation and Recurrence Rule selector.
  4. Native Android Home-Screen Widget (4×2) pinned on the launcher.
  5. Theme Settings showing Dark Glass vs Light Mode and Automatic Day/Night Schedule.
- [ ] **7-inch & 10-inch Tablet Screenshots**:
  - Capture the responsive `NavigationRail` + 4-column metric grid layout (`width >= 720dp`).

### Physical Device QA Verification Checklist
- [ ] Verify `flutter analyze` and `flutter test` pass with zero errors.
- [ ] Schedule a One-Time Ringtone Alarm 2 minutes in the future, lock the device screen, and verify `AlarmRingingActivity` wakes the screen and plays the tone.
- [ ] Schedule a Custom Spoken Voice Alarm (`ur-PK` or `en-US`), lock the device screen, and verify `AlarmForegroundService` speaks the custom message aloud on `STREAM_ALARM`.
- [ ] Tap **Snooze (+10m)** and **Dismiss** from both the full-screen activity and the notification action buttons.
- [ ] Reboot the physical Android device (`adb reboot`) and verify `BootAndTimeChangeReceiver` reschedules active alarms.
- [ ] Add the **Smart Reminders & Voice Alarm** widget to the Android Home Screen, create a reminder, and verify the widget updates immediately.
