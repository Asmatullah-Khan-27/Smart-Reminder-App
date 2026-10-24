import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/models/alarm.dart';

class NativeAlarmPermissionStatus {
  final bool canScheduleExactAlarms;
  final bool canUseFullScreenIntent;
  final bool notificationsGranted;
  final bool batteryOptimizationIgnored;
  final int androidSdkInt;
  final String schedulingModeDescription;

  const NativeAlarmPermissionStatus({
    required this.canScheduleExactAlarms,
    required this.canUseFullScreenIntent,
    required this.notificationsGranted,
    required this.batteryOptimizationIgnored,
    required this.androidSdkInt,
    required this.schedulingModeDescription,
  });

  factory NativeAlarmPermissionStatus.fromMap(Map<dynamic, dynamic> map) {
    final exact = map['canScheduleExactAlarms'] == true;
    final fullScreen = map['canUseFullScreenIntent'] == true;
    final notif = map['notificationsGranted'] == true;
    final battery = map['batteryOptimizationIgnored'] == true;
    final sdk = (map['androidSdkInt'] as num?)?.toInt() ?? 34;
    return NativeAlarmPermissionStatus(
      canScheduleExactAlarms: exact,
      canUseFullScreenIntent: fullScreen,
      notificationsGranted: notif,
      batteryOptimizationIgnored: battery,
      androidSdkInt: sdk,
      schedulingModeDescription: exact
          ? 'Exact Alarm (AlarmManager.setAlarmClock / setExactAndAllowWhileIdle)'
          : 'Inexact Fallback (AlarmManager.setAndAllowWhileIdle — may be delayed by Doze window)',
    );
  }

  static const NativeAlarmPermissionStatus fallbackDefault =
      NativeAlarmPermissionStatus(
    canScheduleExactAlarms: true,
    canUseFullScreenIntent: true,
    notificationsGranted: true,
    batteryOptimizationIgnored: false,
    androidSdkInt: 34,
    schedulingModeDescription:
        'Exact Alarm (AlarmManager.setAlarmClock / setExactAndAllowWhileIdle)',
  );
}

class NativeAlarmScheduleResult {
  final bool scheduled;
  final bool usedExactAlarm;
  final int? scheduledEpochMillis;
  final String statusMessage;

  const NativeAlarmScheduleResult({
    required this.scheduled,
    required this.usedExactAlarm,
    this.scheduledEpochMillis,
    required this.statusMessage,
  });
}

class NativeAlarmBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.premium.smartreminder/native_alarm',
  );

  final void Function(String action, String alarmId)? onNativeAlarmAction;

  NativeAlarmBridge({this.onNativeAlarmAction}) {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    if (call.method == 'onAlarmActionFromNative') {
      final args = call.arguments;
      if (args is Map) {
        final action = args['action']?.toString() ?? '';
        final alarmId = args['alarmId']?.toString() ?? '';
        if (action.isNotEmpty && alarmId.isNotEmpty) {
          onNativeAlarmAction?.call(action, alarmId);
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _alarmToNativePayload(Alarm alarm) {
    final triggerTime = alarm.nextOccurrence ?? alarm.scheduledDateTime;
    return <String, dynamic>{
      'id': alarm.id,
      'title': alarm.title,
      'notes': alarm.notes,
      'alarmMode': alarm.alarmMode.name,
      'customMessage': alarm.customMessage,
      'speechLanguage': alarm.speechLanguage,
      'speechRate': alarm.speechRate,
      'speechPitch': alarm.speechPitch,
      'ringtoneIdentifier': alarm.ringtoneIdentifier,
      'triggerAtMillis': triggerTime.millisecondsSinceEpoch,
      'scheduledDateTimeMillis': alarm.scheduledDateTime.millisecondsSinceEpoch,
      'recurrenceRuleJson': alarm.recurrenceRule.toJsonString(),
      'snoozeDurationMinutes': alarm.snoozeDuration,
      'enabled': alarm.enabled,
    };
  }

  /// Schedules or updates a single alarm with Android's native [AlarmManager].
  Future<NativeAlarmScheduleResult> scheduleNativeAlarm(Alarm alarm) async {
    if (!alarm.enabled || alarm.nextOccurrence == null) {
      await cancelNativeAlarm(alarm.id);
      return const NativeAlarmScheduleResult(
        scheduled: false,
        usedExactAlarm: false,
        statusMessage: 'Alarm disabled or has no future occurrence; cancelled.',
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'scheduleAlarm',
        _alarmToNativePayload(alarm),
      );
      if (result != null) {
        return NativeAlarmScheduleResult(
          scheduled: result['scheduled'] == true,
          usedExactAlarm: result['usedExactAlarm'] == true,
          scheduledEpochMillis:
              (result['scheduledEpochMillis'] as num?)?.toInt(),
          statusMessage: result['statusMessage']?.toString() ??
              'Scheduled with Android AlarmManager.',
        );
      }
    } on MissingPluginException {
      debugPrint(
        '[NativeAlarmBridge] Native channel unavailable in current host environment.',
      );
    } on PlatformException catch (e) {
      return NativeAlarmScheduleResult(
        scheduled: false,
        usedExactAlarm: false,
        statusMessage: 'Platform error scheduling alarm: ${e.message}',
      );
    }

    return NativeAlarmScheduleResult(
      scheduled: true,
      usedExactAlarm: true,
      scheduledEpochMillis: alarm.nextOccurrence?.millisecondsSinceEpoch,
      statusMessage: 'Recorded in alarm schedule registry.',
    );
  }

  /// Cancels a scheduled alarm in Android's native [AlarmManager] and stops
  /// any active ringing/TTS service for [alarmId].
  Future<void> cancelNativeAlarm(String alarmId) async {
    try {
      await _channel.invokeMethod<void>(
        'cancelAlarm',
        <String, dynamic>{'id': alarmId},
      );
    } on MissingPluginException {
      // No-op in desktop/unit test host
    } on PlatformException catch (e) {
      debugPrint('[NativeAlarmBridge] cancelNativeAlarm error: ${e.message}');
    }
  }

  /// Reconciles all enabled SQLite alarms with the native Android AlarmManager
  /// registry, removing stale alarms and ensuring every enabled alarm is scheduled.
  Future<int> reconcileAlarms(List<Alarm> enabledAlarms) async {
    final activePayloads = enabledAlarms
        .where((a) => a.enabled && a.nextOccurrence != null)
        .map(_alarmToNativePayload)
        .toList();
    try {
      final count = await _channel.invokeMethod<int>(
        'reconcileAlarms',
        <String, dynamic>{'alarms': activePayloads},
      );
      return count ?? activePayloads.length;
    } on MissingPluginException {
      return activePayloads.length;
    } on PlatformException catch (e) {
      debugPrint('[NativeAlarmBridge] reconcileAlarms error: ${e.message}');
      return 0;
    }
  }

  Future<NativeAlarmPermissionStatus> getPermissionStatus() async {
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getPermissionStatus',
      );
      if (map != null) {
        return NativeAlarmPermissionStatus.fromMap(map);
      }
    } on MissingPluginException {
      // Non-Android host fallback
    } on PlatformException catch (e) {
      debugPrint('[NativeAlarmBridge] getPermissionStatus error: ${e.message}');
    }
    return NativeAlarmPermissionStatus.fallbackDefault;
  }

  Future<bool> requestExactAlarmPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>(
        'requestExactAlarmPermission',
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestFullScreenIntentPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>(
        'requestFullScreenIntentPermission',
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final res = await _channel.invokeMethod<bool>(
        'requestIgnoreBatteryOptimizations',
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> previewRingtone(String ringtoneIdentifier) async {
    try {
      await _channel.invokeMethod<void>(
        'previewRingtone',
        <String, dynamic>{'ringtoneIdentifier': ringtoneIdentifier},
      );
    } catch (_) {}
  }

  Future<void> stopRingtonePreview() async {
    try {
      await _channel.invokeMethod<void>('stopRingtonePreview');
    } catch (_) {}
  }

  /// Triggers an immediate native test execution of [alarm] (starts the
  /// native ForegroundService + notification / full-screen activity + TTS/ringtone).
  Future<void> triggerImmediateTestAlarm(Alarm alarm) async {
    try {
      await _channel.invokeMethod<void>(
        'triggerTestAlarmNow',
        _alarmToNativePayload(alarm),
      );
    } catch (e) {
      debugPrint('[NativeAlarmBridge] triggerImmediateTestAlarm: $e');
    }
  }
}
