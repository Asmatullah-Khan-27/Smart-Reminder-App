import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../domain/models/reminder.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  final void Function(String? payload)? onNotificationTapped;

  LocalNotificationService({this.onNotificationTapped});

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
      );
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          onNotificationTapped?.call(response.payload);
        },
      );
      _initialized = true;
    } catch (e) {
      debugPrint('[LocalNotificationService] initialize skipped/failed: $e');
    }
  }

  int _stableNotificationId(String id) {
    return id.hashCode & 0x7FFFFFFF;
  }

  Future<void> showImmediateReminderNotification(Reminder reminder) async {
    if (!_initialized) {
      await initialize();
    }
    if (!reminder.notificationEnabled) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'smart_reminders_high_channel',
        'Smart Reminders',
        channelDescription: 'High-priority notifications for scheduled reminders',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      );
      const details = NotificationDetails(android: androidDetails);
      await _plugin.show(
        _stableNotificationId(reminder.id),
        reminder.title,
        reminder.notes.isNotEmpty
            ? reminder.notes
            : 'Priority: ${reminder.priority.label}',
        details,
        payload: 'reminder:${reminder.id}',
      );
    } catch (e) {
      debugPrint('[LocalNotificationService] showNotification error: $e');
    }
  }

  Future<void> cancelReminderNotification(String reminderId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_stableNotificationId(reminderId));
    } catch (_) {}
  }
}
