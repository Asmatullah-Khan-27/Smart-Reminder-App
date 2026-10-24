import 'recurrence_rule.dart';

enum AlarmMode {
  ringtone,
  voice;

  String get label {
    switch (this) {
      case AlarmMode.ringtone:
        return 'Ringtone Mode';
      case AlarmMode.voice:
        return 'Voice Alarm (TTS)';
    }
  }

  static AlarmMode fromString(String? raw) {
    return AlarmMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AlarmMode.ringtone,
    );
  }
}

class RingtoneOption {
  final String id;
  final String name;
  final String description;
  final String androidSystemType; // 'alarm', 'notification', 'ringtone'

  const RingtoneOption({
    required this.id,
    required this.name,
    required this.description,
    this.androidSystemType = 'alarm',
  });

  static const List<RingtoneOption> presets = <RingtoneOption>[
    RingtoneOption(
      id: 'default_alarm',
      name: 'Classic Horizon (System Default Alarm)',
      description: 'Standard high-reliability system alarm tone',
      androidSystemType: 'alarm',
    ),
    RingtoneOption(
      id: 'aurora_chime',
      name: 'Aurora Glass Chime',
      description: 'Crystalline harmonic wake sequence',
      androidSystemType: 'alarm',
    ),
    RingtoneOption(
      id: 'cosmic_pulse',
      name: 'Cosmic Pulse',
      description: 'Progressive deep synth pulse for heavy sleepers',
      androidSystemType: 'alarm',
    ),
    RingtoneOption(
      id: 'gentle_sunrise',
      name: 'Gentle Sunrise',
      description: 'Soft acoustic bell cadence',
      androidSystemType: 'notification',
    ),
    RingtoneOption(
      id: 'urgent_beacon',
      name: 'Urgent Executive Beacon',
      description: 'High-priority rapid cadence tone',
      androidSystemType: 'ringtone',
    ),
  ];

  static RingtoneOption byId(String id) {
    return presets.firstWhere(
      (e) => e.id == id,
      orElse: () => presets.first,
    );
  }
}

class SpeechLanguageOption {
  final String code;
  final String label;
  final String samplePrompt;

  const SpeechLanguageOption({
    required this.code,
    required this.label,
    required this.samplePrompt,
  });

  static const List<SpeechLanguageOption> supported = <SpeechLanguageOption>[
    SpeechLanguageOption(
      code: 'ur-PK',
      label: 'Urdu / Roman Urdu (ur-PK)',
      samplePrompt:
          'Sir, time ho gaya hai. Uth jaiye aur apna kaam shuru karein.',
    ),
    SpeechLanguageOption(
      code: 'hi-IN',
      label: 'Hindi / Hinglish (hi-IN)',
      samplePrompt:
          'Sir, time ho gaya hai. Uth jaiye aur apna kaam shuru karein.',
    ),
    SpeechLanguageOption(
      code: 'en-US',
      label: 'English — United States (en-US)',
      samplePrompt:
          'Good morning! Your scheduled alarm is now active. Time to begin your priorities.',
    ),
    SpeechLanguageOption(
      code: 'en-GB',
      label: 'English — United Kingdom (en-GB)',
      samplePrompt:
          'Excuse me, it is time for your scheduled commitment. Please get started.',
    ),
    SpeechLanguageOption(
      code: 'ar-SA',
      label: 'Arabic (ar-SA)',
      samplePrompt: 'حان وقت المنبه المجدول الآن، يرجى الاستعداد والبدء.',
    ),
    SpeechLanguageOption(
      code: 'es-ES',
      label: 'Spanish (es-ES)',
      samplePrompt:
          'Es hora de levantarse y comenzar tus actividades programadas.',
    ),
  ];
}

class Alarm {
  final String id;
  final String title;
  final String notes;
  final AlarmMode alarmMode;
  final String customMessage;
  final String speechLanguage;
  final double speechRate;
  final double speechPitch;
  final String ringtoneIdentifier;
  final DateTime scheduledDateTime;
  final RecurrenceRule recurrenceRule;
  final int snoozeDuration; // in minutes
  final bool enabled;
  final DateTime? nextOccurrence;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Alarm({
    required this.id,
    required this.title,
    this.notes = '',
    this.alarmMode = AlarmMode.ringtone,
    this.customMessage = '',
    this.speechLanguage = 'en-US',
    this.speechRate = 0.5,
    this.speechPitch = 1.0,
    this.ringtoneIdentifier = 'default_alarm',
    required this.scheduledDateTime,
    this.recurrenceRule = const RecurrenceRule(),
    this.snoozeDuration = 10,
    this.enabled = true,
    required this.nextOccurrence,
    required this.createdAt,
    required this.updatedAt,
  });

  static const String defaultRomanUrduMessage =
      'Sir, time ho gaya hai. Uth jaiye aur apna kaam shuru karein.';

  void validate() {
    if (id.trim().isEmpty) {
      throw ArgumentError('Alarm id cannot be empty.');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError('Alarm title cannot be empty.');
    }
    if (alarmMode == AlarmMode.voice && customMessage.trim().isEmpty) {
      throw ArgumentError(
        'Voice Alarm mode requires a non-empty custom spoken message.',
      );
    }
    if (speechRate < 0.1 || speechRate > 2.0) {
      throw ArgumentError('speechRate must be between 0.1 and 2.0.');
    }
    if (speechPitch < 0.5 || speechPitch > 2.0) {
      throw ArgumentError('speechPitch must be between 0.5 and 2.0.');
    }
    if (snoozeDuration < 1 || snoozeDuration > 1440) {
      throw ArgumentError('Snooze duration must be between 1 and 1440 minutes.');
    }
    recurrenceRule.validate();
  }

  /// Resolves the next occurrence relative to [now] when the alarm is enabled.
  /// If a one-time alarm's scheduledDateTime is in the past when re-enabled,
  /// rolls the scheduled time forward to the next 24-hour occurrence with the
  /// same wall-clock hour and minute.
  Alarm withRecomputedNextOccurrence(
    DateTime now, {
    bool rollForwardPastOneTime = true,
  }) {
    if (!enabled) {
      return copyWith(clearNextOccurrence: true, updatedAt: now);
    }

    DateTime effectiveAnchor = scheduledDateTime;
    if (!recurrenceRule.isRecurring && !effectiveAnchor.isAfter(now)) {
      if (rollForwardPastOneTime) {
        DateTime candidate = DateTime(
          now.year,
          now.month,
          now.day,
          effectiveAnchor.hour,
          effectiveAnchor.minute,
        );
        if (!candidate.isAfter(now)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        effectiveAnchor = candidate;
      }
    }

    final computed = RecurrenceEngine.computeNextOccurrence(
      anchorDateTime: effectiveAnchor,
      rule: recurrenceRule,
      referenceTime: now,
      allowAnchorIfInFuture: true,
    );

    return copyWith(
      scheduledDateTime: effectiveAnchor,
      nextOccurrence: computed,
      clearNextOccurrence: computed == null,
      enabled: computed != null,
      updatedAt: now,
    );
  }

  DateTime calculateSnoozedOccurrence(DateTime fromTime, {int? customMinutes}) {
    final minutes = customMinutes ?? snoozeDuration;
    if (minutes < 1) {
      throw ArgumentError.value(minutes, 'minutes', 'Snooze minutes must be >= 1');
    }
    return fromTime.add(Duration(minutes: minutes));
  }

  Alarm copyWith({
    String? id,
    String? title,
    String? notes,
    AlarmMode? alarmMode,
    String? customMessage,
    String? speechLanguage,
    double? speechRate,
    double? speechPitch,
    String? ringtoneIdentifier,
    DateTime? scheduledDateTime,
    RecurrenceRule? recurrenceRule,
    int? snoozeDuration,
    bool? enabled,
    DateTime? nextOccurrence,
    bool clearNextOccurrence = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Alarm(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      alarmMode: alarmMode ?? this.alarmMode,
      customMessage: customMessage ?? this.customMessage,
      speechLanguage: speechLanguage ?? this.speechLanguage,
      speechRate: speechRate ?? this.speechRate,
      speechPitch: speechPitch ?? this.speechPitch,
      ringtoneIdentifier: ringtoneIdentifier ?? this.ringtoneIdentifier,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
      enabled: enabled ?? this.enabled,
      nextOccurrence:
          clearNextOccurrence ? null : (nextOccurrence ?? this.nextOccurrence),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title.trim(),
      'notes': notes,
      'alarmMode': alarmMode.name,
      'customMessage': customMessage,
      'speechLanguage': speechLanguage,
      'speechRate': speechRate,
      'speechPitch': speechPitch,
      'ringtoneIdentifier': ringtoneIdentifier,
      'scheduledDateTime': scheduledDateTime.millisecondsSinceEpoch,
      'recurrenceRule': recurrenceRule.toJsonString(),
      'snoozeDuration': snoozeDuration,
      'enabled': enabled ? 1 : 0,
      'nextOccurrence': nextOccurrence?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Alarm.fromMap(Map<String, dynamic> map) {
    final nextMs = (map['nextOccurrence'] as num?)?.toInt();
    return Alarm(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      alarmMode: AlarmMode.fromString(map['alarmMode'] as String?),
      customMessage: (map['customMessage'] as String?) ?? '',
      speechLanguage: (map['speechLanguage'] as String?) ?? 'en-US',
      speechRate: ((map['speechRate'] as num?)?.toDouble() ?? 0.5).clamp(
        0.1,
        2.0,
      ),
      speechPitch: ((map['speechPitch'] as num?)?.toDouble() ?? 1.0).clamp(
        0.5,
        2.0,
      ),
      ringtoneIdentifier:
          (map['ringtoneIdentifier'] as String?) ?? 'default_alarm',
      scheduledDateTime: DateTime.fromMillisecondsSinceEpoch(
        (map['scheduledDateTime'] as num).toInt(),
      ),
      recurrenceRule: RecurrenceRule.fromJsonString(
        map['recurrenceRule'] as String?,
      ),
      snoozeDuration: ((map['snoozeDuration'] as num?)?.toInt() ?? 10).clamp(
        1,
        1440,
      ),
      enabled: ((map['enabled'] as num?)?.toInt() ?? 1) == 1,
      nextOccurrence: nextMs != null
          ? DateTime.fromMillisecondsSinceEpoch(nextMs)
          : null,
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
      'alarmMode': alarmMode.name,
      'customMessage': customMessage,
      'speechLanguage': speechLanguage,
      'speechRate': speechRate,
      'speechPitch': speechPitch,
      'ringtoneIdentifier': ringtoneIdentifier,
      'scheduledDateTime': scheduledDateTime.toIso8601String(),
      'recurrenceRule': recurrenceRule.toMap(),
      'snoozeDuration': snoozeDuration,
      'enabled': enabled,
      'nextOccurrence': nextOccurrence?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Alarm.fromBackupJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final title = (json['title'] as String?)?.trim() ?? '';
    if (id.isEmpty || title.isEmpty) {
      throw const FormatException('Invalid alarm record: missing id or title.');
    }
    final scheduled = DateTime.parse(json['scheduledDateTime'] as String);
    final nextStr = json['nextOccurrence'] as String?;
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

    return Alarm(
      id: id,
      title: title,
      notes: (json['notes'] as String?) ?? '',
      alarmMode: AlarmMode.fromString(json['alarmMode'] as String?),
      customMessage: (json['customMessage'] as String?) ?? '',
      speechLanguage: (json['speechLanguage'] as String?) ?? 'en-US',
      speechRate:
          ((json['speechRate'] as num?)?.toDouble() ?? 0.5).clamp(0.1, 2.0),
      speechPitch:
          ((json['speechPitch'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 2.0),
      ringtoneIdentifier:
          (json['ringtoneIdentifier'] as String?) ?? 'default_alarm',
      scheduledDateTime: scheduled,
      recurrenceRule: rule,
      snoozeDuration:
          ((json['snoozeDuration'] as num?)?.toInt() ?? 10).clamp(1, 1440),
      enabled: json['enabled'] == null
          ? true
          : (json['enabled'] == true || json['enabled'] == 1),
      nextOccurrence: nextStr != null && nextStr.isNotEmpty
          ? DateTime.tryParse(nextStr)
          : null,
      createdAt: created,
      updatedAt: updated,
    );
  }
}
