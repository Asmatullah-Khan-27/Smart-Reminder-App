import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reminder_alarm/domain/models/alarm.dart';
import 'package:smart_reminder_alarm/domain/models/app_settings.dart';
import 'package:smart_reminder_alarm/domain/models/recurrence_rule.dart';
import 'package:smart_reminder_alarm/domain/models/reminder.dart';

void main() {
  group('RecurrenceEngine Calculations & Edge Cases', () {
    test('One-time recurrence returns anchor if in future, null if in past', () {
      final anchor = DateTime(2026, 10, 26, 9, 0);
      final rule = RecurrenceRule.oneTime();

      final futureRes = RecurrenceEngine.computeNextOccurrence(
        anchorDateTime: anchor,
        rule: rule,
        referenceTime: DateTime(2026, 10, 25, 12, 0),
      );
      expect(futureRes, equals(anchor));

      final pastRes = RecurrenceEngine.computeNextOccurrence(
        anchorDateTime: anchor,
        rule: rule,
        referenceTime: DateTime(2026, 10, 26, 10, 0),
      );
      expect(pastRes, isNull);
    });

    test('Daily recurrence advances across multiple past days preserving wall-clock time', () {
      final anchor = DateTime(2026, 10, 1, 7, 30);
      final rule = RecurrenceRule.daily(interval: 2);
      final reference = DateTime(2026, 10, 6, 8, 0);

      // Anchor Oct 1 -> Oct 3 -> Oct 5 -> Oct 7 at 07:30
      final next = RecurrenceEngine.computeNextOccurrence(
        anchorDateTime: anchor,
        rule: rule,
        referenceTime: reference,
      );
      expect(next, equals(DateTime(2026, 10, 7, 7, 30)));
    });

    test('Selected weekdays recurrence skips weekend to next Monday', () {
      // Friday Oct 23, 2026 at 09:00
      final anchor = DateTime(2026, 10, 23, 9, 0);
      final rule = RecurrenceRule.selectedWeekdays(
        weekdays: const <int>[1, 2, 3, 4, 5], // Mon..Fri
      );
      // Reference is Friday Oct 23, 2026 at 10:00 (after Friday's 09:00 slot)
      final reference = DateTime(2026, 10, 23, 10, 0);

      final next = RecurrenceEngine.computeNextOccurrence(
        anchorDateTime: anchor,
        rule: rule,
        referenceTime: reference,
      );
      // Should skip Sat Oct 24 & Sun Oct 25 -> Mon Oct 26, 2026 at 09:00
      expect(next, equals(DateTime(2026, 10, 26, 9, 0)));
      expect(next!.weekday, equals(DateTime.monday));
    });

    test('Monthly recurrence clamps Jan 31 to Feb 28 (non-leap) and Feb 29 (leap year)', () {
      final anchorNonLeap = DateTime(2026, 1, 31, 8, 15);
      final rule = RecurrenceRule.monthly(interval: 1, dayOfMonth: 31);

      // After Jan 31, 2026 -> Feb 28, 2026
      final feb2026 = RecurrenceEngine.computeNextOccurrence(
        anchorDateTime: anchorNonLeap,
        rule: rule,
        referenceTime: DateTime(2026, 1, 31, 9, 0),
      );
      expect(feb2026, equals(DateTime(2026, 2, 28, 8, 15)));

      // After Feb 28, 2026 -> Mar 31, 2026
      final mar2026 = RecurrenceEngine.computeNextOccurrence(
        anchorDateTime: anchorNonLeap,
        rule: rule,
        referenceTime: DateTime(2026, 2, 28, 9, 0),
      );
      expect(mar2026, equals(DateTime(2026, 3, 31, 8, 15)));

      // Leap year 2028: Jan 31, 2028 -> Feb 29, 2028
      final anchorLeap = DateTime(2028, 1, 31, 8, 15);
      final feb2028 = RecurrenceEngine.computeNextOccurrence(
        anchorDateTime: anchorLeap,
        rule: rule,
        referenceTime: DateTime(2028, 1, 31, 9, 0),
      );
      expect(feb2028, equals(DateTime(2028, 2, 29, 8, 15)));
    });

    test('Custom interval in hours and endDate expiration work accurately', () {
      final anchor = DateTime(2026, 10, 25, 8, 0);
      final endDate = DateTime(2026, 10, 25, 18, 0);
      final rule = RecurrenceRule.custom(
        interval: 4,
        unit: CustomIntervalUnit.hours,
        endDate: endDate,
      );

      final next1 = RecurrenceEngine.computeNextOccurrence(
        anchorDateTime: anchor,
        rule: rule,
        referenceTime: DateTime(2026, 10, 25, 13, 0),
      );
      expect(next1, equals(DateTime(2026, 10, 25, 16, 0)));

      // Next after 16:00 would be 20:00, which exceeds endDate (18:00) -> null
      final expired = RecurrenceEngine.computeNextOccurrence(
        anchorDateTime: anchor,
        rule: rule,
        referenceTime: DateTime(2026, 10, 25, 16, 1),
      );
      expect(expired, isNull);
    });
  });

  group('Validation & Snooze Calculation Tests', () {
    test('Reminder validation rejects empty title or invalid snooze duration', () {
      final now = DateTime(2026, 10, 25, 10, 0);
      final invalidTitle = Reminder(
        id: 'rem-1',
        title: '   ',
        scheduledDateTime: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(() => invalidTitle.validate(), throwsArgumentError);

      final invalidSnooze = Reminder(
        id: 'rem-1',
        title: 'Valid Title',
        scheduledDateTime: now,
        snoozeDuration: 0,
        createdAt: now,
        updatedAt: now,
      );
      expect(() => invalidSnooze.validate(), throwsArgumentError);
    });

    test('Voice Alarm validation requires customMessage when in AlarmMode.voice', () {
      final now = DateTime(2026, 10, 25, 7, 0);
      final emptyVoiceAlarm = Alarm(
        id: 'alarm-1',
        title: 'Wake up',
        alarmMode: AlarmMode.voice,
        customMessage: '   ',
        scheduledDateTime: now,
        nextOccurrence: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(() => emptyVoiceAlarm.validate(), throwsArgumentError);

      final validVoiceAlarm = emptyVoiceAlarm.copyWith(
        customMessage: Alarm.defaultRomanUrduMessage,
      );
      expect(() => validVoiceAlarm.validate(), returnsNormally);
    });

    test('Snooze calculation advances from max(now, scheduledDateTime)', () {
      final scheduled = DateTime(2026, 10, 25, 10, 0);
      final reminder = Reminder(
        id: 'rem-snooze',
        title: 'Test Snooze',
        scheduledDateTime: scheduled,
        snoozeDuration: 15,
        createdAt: scheduled,
        updatedAt: scheduled,
      );

      final nowAfter = DateTime(2026, 10, 25, 10, 5);
      expect(
        reminder.calculateSnoozedTime(nowAfter),
        equals(DateTime(2026, 10, 25, 10, 20)),
      );
    });
  });

  group('Theme Scheduling Across Midnight & Feature Entitlement Tests', () {
    test('Standard Day/Night schedule (07:00 to 19:30) resolves Light vs Dark', () {
      const settings = ThemeSettings(
        mode: ThemePreferenceMode.scheduled,
        dayStartHour: 7,
        dayStartMinute: 0,
        nightStartHour: 19,
        nightStartMinute: 30,
      );

      expect(
        settings.resolveThemeMode(DateTime(2026, 10, 25, 6, 59)),
        equals(ThemeMode.dark),
      );
      expect(
        settings.resolveThemeMode(DateTime(2026, 10, 25, 7, 0)),
        equals(ThemeMode.light),
      );
      expect(
        settings.resolveThemeMode(DateTime(2026, 10, 25, 14, 0)),
        equals(ThemeMode.light),
      );
      expect(
        settings.resolveThemeMode(DateTime(2026, 10, 25, 19, 30)),
        equals(ThemeMode.dark),
      );
    });

    test('Schedule where Daytime crosses midnight (Day 20:00 -> Night 05:00)', () {
      const nightShiftSettings = ThemeSettings(
        mode: ThemePreferenceMode.scheduled,
        dayStartHour: 20,
        dayStartMinute: 0,
        nightStartHour: 5,
        nightStartMinute: 0,
      );

      // 23:30 is inside [20:00 .. 05:00) -> Light
      expect(
        nightShiftSettings.resolveThemeMode(DateTime(2026, 10, 25, 23, 30)),
        equals(ThemeMode.light),
      );
      // 02:15 is inside [20:00 .. 05:00) -> Light
      expect(
        nightShiftSettings.resolveThemeMode(DateTime(2026, 10, 25, 2, 15)),
        equals(ThemeMode.light),
      );
      // 12:00 noon is outside [20:00 .. 05:00) -> Dark
      expect(
        nightShiftSettings.resolveThemeMode(DateTime(2026, 10, 25, 12, 0)),
        equals(ThemeMode.dark),
      );
    });

    test('AdvertisingConfiguration never permits interstitial when alarm is ringing', () {
      const adConfig = AdvertisingConfiguration(
        provider: AdNetworkProvider.googleAdMob,
        testMode: true,
        bannerEnabled: true,
        interstitialEnabled: true,
      );

      expect(
        adConfig.canShowInterstitial(
          isPremiumActive: false,
          isAlarmRinging: true,
          isSchedulingOrDismissingAlarm: false,
        ),
        isFalse,
      );
      expect(
        adConfig.canShowInterstitial(
          isPremiumActive: false,
          isAlarmRinging: false,
          isSchedulingOrDismissingAlarm: true,
        ),
        isFalse,
      );
      expect(
        adConfig.canShowInterstitial(
          isPremiumActive: true,
          isAlarmRinging: false,
          isSchedulingOrDismissingAlarm: false,
        ),
        isFalse,
      );
    });
  });
}
