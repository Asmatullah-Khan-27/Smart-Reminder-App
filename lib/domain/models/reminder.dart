import 'recurrence_rule.dart';

enum ReminderPriority {
  low,
  medium,
  high,
  critical;

  String get label {
    switch (this) {
      case ReminderPriority.low:
        return 'Low';
      case ReminderPriority.medium:
        return 'Medium';
      case ReminderPriority.high:
        return 'High';
      case ReminderPriority.critical:
        return 'Critical';
    }
  }

  int get weight {
    switch (this) {
      case ReminderPriority.low:
        return 1;
      case ReminderPriority.medium:
        return 2;
      case ReminderPriority.high:
        return 3;
      case ReminderPriority.critical:
        return 4;
    }
  }

  static ReminderPriority fromString(String? raw) {
    return ReminderPriority.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ReminderPriority.medium,
    );
  }
}

class Reminder {
  final String id;
  final String title;
  final String notes;
  final DateTime scheduledDateTime;
  final RecurrenceRule recurrenceRule;
  final String categoryId;
  final ReminderPriority priority;
  final bool completed;
  final bool notificationEnabled;
  final int snoozeDuration; // in minutes
  final DateTime createdAt;
  final DateTime updatedAt;

  const Reminder({
    required this.id,
    required this.title,
    this.notes = '',
    required this.scheduledDateTime,
    this.recurrenceRule = const RecurrenceRule(),
    this.categoryId = 'personal',
    this.priority = ReminderPriority.medium,
    this.completed = false,
    this.notificationEnabled = true,
    this.snoozeDuration = 10,
    required this.createdAt,
    required this.updatedAt,
  });

  void validate() {
    if (id.trim().isEmpty) {
      throw ArgumentError('Reminder id cannot be empty.');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError('Reminder title cannot be empty.');
    }
    if (title.trim().length > 200) {
      throw ArgumentError('Reminder title cannot exceed 200 characters.');
    }
    if (categoryId.trim().isEmpty) {
      throw ArgumentError('Reminder categoryId cannot be empty.');
    }
    if (snoozeDuration < 1 || snoozeDuration > 1440) {
      throw ArgumentError('Snooze duration must be between 1 and 1440 minutes.');
    }
    recurrenceRule.validate();
  }

  bool isOverdueAt(DateTime now) {
    return !completed && scheduledDateTime.isBefore(now);
  }

  bool isTodayAt(DateTime now) {
    return !completed &&
        scheduledDateTime.year == now.year &&
        scheduledDateTime.month == now.month &&
        scheduledDateTime.day == now.day;
  }

  bool isUpcomingAt(DateTime now) {
    return !completed && scheduledDateTime.isAfter(now);
  }

  DateTime calculateSnoozedTime(DateTime fromTime, {int? customMinutes}) {
    final minutes = customMinutes ?? snoozeDuration;
    if (minutes < 1) {
      throw ArgumentError.value(minutes, 'minutes', 'Snooze minutes must be >= 1');
    }
    final baseline =
        fromTime.isAfter(scheduledDateTime) ? fromTime : scheduledDateTime;
    return baseline.add(Duration(minutes: minutes));
  }

  Reminder copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? scheduledDateTime,
    RecurrenceRule? recurrenceRule,
    String? categoryId,
    ReminderPriority? priority,
    bool? completed,
    bool? notificationEnabled,
    int? snoozeDuration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title.trim(),
      'notes': notes,
      'scheduledDateTime': scheduledDateTime.millisecondsSinceEpoch,
      'recurrenceRule': recurrenceRule.toJsonString(),
      'categoryId': categoryId,
      'priority': priority.name,
      'completed': completed ? 1 : 0,
      'notificationEnabled': notificationEnabled ? 1 : 0,
      'snoozeDuration': snoozeDuration,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      scheduledDateTime: DateTime.fromMillisecondsSinceEpoch(
        (map['scheduledDateTime'] as num).toInt(),
      ),
      recurrenceRule: RecurrenceRule.fromJsonString(
        map['recurrenceRule'] as String?,
      ),
      categoryId: (map['categoryId'] as String?) ?? 'personal',
      priority: ReminderPriority.fromString(map['priority'] as String?),
      completed: ((map['completed'] as num?)?.toInt() ?? 0) == 1,
      notificationEnabled:
          ((map['notificationEnabled'] as num?)?.toInt() ?? 1) == 1,
      snoozeDuration: ((map['snoozeDuration'] as num?)?.toInt() ?? 10).clamp(
        1,
        1440,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updatedAt'] as num).toInt(),
      ),
    );
  }

  Map<String, dynamic> toBackupJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'notes': notes,
      'scheduledDateTime': scheduledDateTime.toIso8601String(),
      'recurrenceRule': recurrenceRule.toMap(),
      'categoryId': categoryId,
      'priority': priority.name,
      'completed': completed,
      'notificationEnabled': notificationEnabled,
      'snoozeDuration': snoozeDuration,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Reminder.fromBackupJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final title = (json['title'] as String?)?.trim() ?? '';
    if (id.isEmpty || title.isEmpty) {
      throw const FormatException('Invalid reminder record: missing id or title.');
    }
    final scheduled = DateTime.parse(json['scheduledDateTime'] as String);
    final created = json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now();
    final updated = json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : created;
    final rawRule = json['recurrenceRule'];
    final RecurrenceRule rule = rawRule is Map<String, dynamic>
        ? RecurrenceRule.fromMap(rawRule)
        : RecurrenceRule.fromJsonString(rawRule?.toString());

    return Reminder(
      id: id,
      title: title,
      notes: (json['notes'] as String?) ?? '',
      scheduledDateTime: scheduled,
      recurrenceRule: rule,
      categoryId: (json['categoryId'] as String?)?.trim().isNotEmpty == true
          ? (json['categoryId'] as String).trim()
          : 'personal',
      priority: ReminderPriority.fromString(json['priority'] as String?),
      completed: json['completed'] == true || json['completed'] == 1,
      notificationEnabled: json['notificationEnabled'] == null
          ? true
          : (json['notificationEnabled'] == true ||
              json['notificationEnabled'] == 1),
      snoozeDuration:
          ((json['snoozeDuration'] as num?)?.toInt() ?? 10).clamp(1, 1440),
      createdAt: created,
      updatedAt: updated,
    );
  }
}
