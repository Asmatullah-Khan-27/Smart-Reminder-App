import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/alarm.dart';
import '../domain/models/category.dart';
import '../domain/models/reminder.dart';

class WidgetReminderItemSnapshot {
  final String id;
  final String title;
  final String formattedTime;
  final String categoryName;
  final String priority;
  final bool isOverdue;

  const WidgetReminderItemSnapshot({
    required this.id,
    required this.title,
    required this.formattedTime,
    required this.categoryName,
    required this.priority,
    required this.isOverdue,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'title': title,
        'formattedTime': formattedTime,
        'categoryName': categoryName,
        'priority': priority,
        'isOverdue': isOverdue,
      };
}

class WidgetSnapshotPayload {
  final DateTime syncedAt;
  final int totalActiveCount;
  final int overdueCount;
  final String? nextAlarmLabel;
  final List<WidgetReminderItemSnapshot> items;

  const WidgetSnapshotPayload({
    required this.syncedAt,
    required this.totalActiveCount,
    required this.overdueCount,
    this.nextAlarmLabel,
    required this.items,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'syncedAtMillis': syncedAt.millisecondsSinceEpoch,
        'syncedAtFormatted': DateFormat('MMM d, h:mm a').format(syncedAt),
        'totalActiveCount': totalActiveCount,
        'overdueCount': overdueCount,
        'nextAlarmLabel': nextAlarmLabel ?? 'No active alarm',
        'items': items.map((e) => e.toMap()).toList(),
      };

  String toJsonString() => jsonEncode(toMap());
}

class WidgetSyncBridge {
  static const String sharedPrefsSnapshotKey =
      'smart_reminder_widget_snapshot_json';
  static const MethodChannel _widgetChannel = MethodChannel(
    'com.premium.smartreminder/widget_bridge',
  );

  final void Function(String action, String? targetId)? onWidgetLaunchAction;

  WidgetSyncBridge({this.onWidgetLaunchAction}) {
    _widgetChannel.setMethodCallHandler(_handleWidgetIntentCall);
  }

  Future<dynamic> _handleWidgetIntentCall(MethodCall call) async {
    if (call.method == 'onWidgetIntentAction') {
      final args = call.arguments;
      if (args is Map) {
        final action = args['action']?.toString() ?? '';
        final targetId = args['targetId']?.toString();
        if (action.isNotEmpty) {
          onWidgetLaunchAction?.call(action, targetId);
        }
      }
    }
    return null;
  }

  /// Builds a deterministic snapshot of upcoming reminders and next alarm,
  /// persists it to SharedPreferences, and triggers the native Android
  /// [SmartReminderWidgetProvider] broadcast update.
  Future<WidgetSnapshotPayload> syncHomeScreenWidget({
    required List<Reminder> reminders,
    required List<Alarm> alarms,
    required List<ReminderCategory> categories,
    bool use24HourFormat = false,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    final categoryMap = <String, String>{
      for (final c in categories) c.id: c.name,
    };

    final activeReminders = reminders.where((r) => !r.completed).toList()
      ..sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));

    final overdueCount =
        activeReminders.where((r) => r.isOverdueAt(currentTime)).length;

    final timePattern = use24HourFormat ? 'EEE, MMM d • HH:mm' : 'EEE, MMM d • h:mm a';
    final dateFormat = DateFormat(timePattern);

    final topItems = activeReminders.take(5).map((r) {
      return WidgetReminderItemSnapshot(
        id: r.id,
        title: r.title,
        formattedTime: dateFormat.format(r.scheduledDateTime),
        categoryName: categoryMap[r.categoryId] ?? 'Personal',
        priority: r.priority.label,
        isOverdue: r.isOverdueAt(currentTime),
      );
    }).toList();

    final enabledAlarms = alarms
        .where((a) => a.enabled && a.nextOccurrence != null)
        .toList()
      ..sort((a, b) => a.nextOccurrence!.compareTo(b.nextOccurrence!));

    String? nextAlarmLabel;
    if (enabledAlarms.isNotEmpty) {
      final nextAlarm = enabledAlarms.first;
      final alarmTimeFmt = DateFormat(use24HourFormat ? 'HH:mm' : 'h:mm a')
          .format(nextAlarm.nextOccurrence!);
      nextAlarmLabel = '${nextAlarm.title} ($alarmTimeFmt)';
    }

    final payload = WidgetSnapshotPayload(
      syncedAt: currentTime,
      totalActiveCount: activeReminders.length,
      overdueCount: overdueCount,
      nextAlarmLabel: nextAlarmLabel,
      items: topItems,
    );

    final jsonString = payload.toJsonString();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sharedPrefsSnapshotKey, jsonString);
    } catch (_) {}

    try {
      await _widgetChannel.invokeMethod<bool>(
        'syncWidgetSnapshot',
        <String, dynamic>{
          'snapshotJson': jsonString,
        },
      );
    } on MissingPluginException {
      debugPrint(
        '[WidgetSyncBridge] Widget channel not attached in current environment.',
      );
    } catch (e) {
      debugPrint('[WidgetSyncBridge] syncWidgetSnapshot error: $e');
    }

    return payload;
  }

  /// Checks if the app was launched via a Home-Screen Widget tap (e.g. Quick Add
  /// or opening a specific Reminder ID).
  Future<Map<String, String?>?> consumeInitialWidgetLaunchAction() async {
    try {
      final res = await _widgetChannel.invokeMethod<Map<dynamic, dynamic>>(
        'consumeInitialWidgetAction',
      );
      if (res != null && res['action'] != null) {
        return <String, String?>{
          'action': res['action']?.toString(),
          'targetId': res['targetId']?.toString(),
        };
      }
    } catch (_) {}
    return null;
  }
}
