import 'dart:convert';
import 'alarm.dart';
import 'app_settings.dart';
import 'category.dart';
import 'reminder.dart';

enum RestoreStrategy {
  mergeKeepExisting,
  mergeOverwriteDuplicates,
  replaceAll;

  String get title {
    switch (this) {
      case RestoreStrategy.mergeKeepExisting:
        return 'Merge (Keep Existing on Duplicate ID)';
      case RestoreStrategy.mergeOverwriteDuplicates:
        return 'Merge (Overwrite Matching IDs)';
      case RestoreStrategy.replaceAll:
        return 'Replace All Current Data';
    }
  }

  String get description {
    switch (this) {
      case RestoreStrategy.mergeKeepExisting:
        return 'Imports only new reminders, alarms, and categories whose IDs do not already exist locally.';
      case RestoreStrategy.mergeOverwriteDuplicates:
        return 'Updates existing records when IDs match and inserts any new records from the backup.';
      case RestoreStrategy.replaceAll:
        return 'Clears current reminders, alarms, and custom categories before restoring the backup.';
    }
  }
}

class RestoreSummary {
  final int remindersInserted;
  final int remindersUpdated;
  final int remindersSkipped;
  final int alarmsInserted;
  final int alarmsUpdated;
  final int alarmsSkipped;
  final int categoriesRestored;
  final bool settingsRestored;

  const RestoreSummary({
    required this.remindersInserted,
    required this.remindersUpdated,
    required this.remindersSkipped,
    required this.alarmsInserted,
    required this.alarmsUpdated,
    required this.alarmsSkipped,
    required this.categoriesRestored,
    required this.settingsRestored,
  });
}

class BackupBundle {
  static const String magicHeader = 'SMART_REMINDER_VOICE_ALARM_BACKUP';
  static const int currentSchemaVersion = 2;

  final String formatIdentifier;
  final int schemaVersion;
  final String appVersion;
  final DateTime exportedAt;
  final List<Reminder> reminders;
  final List<Alarm> alarms;
  final List<ReminderCategory> categories;
  final ThemeSettings themeSettings;
  final SpeechSettings speechSettings;
  final UserPreferences userPreferences;

  const BackupBundle({
    this.formatIdentifier = magicHeader,
    this.schemaVersion = currentSchemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.reminders,
    required this.alarms,
    required this.categories,
    required this.themeSettings,
    required this.speechSettings,
    required this.userPreferences,
  });

  /// Validates the backup bundle and deduplicates any internal duplicate IDs
  /// within the bundle itself so a malformed file cannot corrupt SQLite.
  BackupBundle validatedAndNormalized() {
    if (formatIdentifier != magicHeader) {
      throw const FormatException(
        'Unrecognized backup format identifier. Expected SMART_REMINDER_VOICE_ALARM_BACKUP.',
      );
    }
    if (schemaVersion < 1 || schemaVersion > currentSchemaVersion) {
      throw FormatException(
        'Unsupported backup schema version: $schemaVersion (supported: 1..$currentSchemaVersion).',
      );
    }

    final seenCategories = <String>{};
    final normalizedCategories = <ReminderCategory>[];
    for (final cat in categories) {
      cat.validate();
      if (seenCategories.add(cat.id)) {
        normalizedCategories.add(cat);
      }
    }

    final validCategoryIds = <String>{
      ...ReminderCategory.defaultCategories(exportedAt).map((c) => c.id),
      ...normalizedCategories.map((c) => c.id),
    };

    final seenReminders = <String>{};
    final normalizedReminders = <Reminder>[];
    for (final rem in reminders) {
      rem.validate();
      if (seenReminders.add(rem.id)) {
        final safeCat =
            validCategoryIds.contains(rem.categoryId) ? rem.categoryId : 'other';
        normalizedReminders.add(rem.copyWith(categoryId: safeCat));
      }
    }

    final seenAlarms = <String>{};
    final normalizedAlarms = <Alarm>[];
    for (final alarm in alarms) {
      alarm.validate();
      if (seenAlarms.add(alarm.id)) {
        normalizedAlarms.add(alarm);
      }
    }

    return BackupBundle(
      formatIdentifier: formatIdentifier,
      schemaVersion: schemaVersion,
      appVersion: appVersion,
      exportedAt: exportedAt,
      reminders: List<Reminder>.unmodifiable(normalizedReminders),
      alarms: List<Alarm>.unmodifiable(normalizedAlarms),
      categories: List<ReminderCategory>.unmodifiable(normalizedCategories),
      themeSettings: themeSettings,
      speechSettings: speechSettings,
      userPreferences: userPreferences,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'formatIdentifier': formatIdentifier,
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'reminders': reminders.map((r) => r.toBackupJson()).toList(),
      'alarms': alarms.map((a) => a.toBackupJson()).toList(),
      'categories': categories.map((c) => c.toBackupJson()).toList(),
      'settings': <String, dynamic>{
        'theme': themeSettings.toMap(),
        'speech': speechSettings.toMap(),
        'preferences': userPreferences.toMap(),
      },
    };
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toMap());
  }

  factory BackupBundle.fromJsonString(String jsonStr) {
    if (jsonStr.trim().isEmpty) {
      throw const FormatException('Backup content cannot be empty.');
    }
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup root must be a JSON object.');
    }
    return BackupBundle.fromMap(decoded).validatedAndNormalized();
  }

  factory BackupBundle.fromMap(Map<String, dynamic> map) {
    final formatId = map['formatIdentifier'] as String? ?? '';
    final version = (map['schemaVersion'] as num?)?.toInt() ?? 0;
    final appVer = (map['appVersion'] as String?) ?? '1.0.0';
    final exportedRaw = map['exportedAt'] as String?;
    if (exportedRaw == null) {
      throw const FormatException('Backup missing exportedAt timestamp.');
    }
    final exportedAt = DateTime.parse(exportedRaw);

    final rawReminders = map['reminders'];
    if (rawReminders is! List) {
      throw const FormatException('Backup "reminders" field must be a list.');
    }
    final parsedReminders = rawReminders.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid reminder entry in backup.');
      }
      return Reminder.fromBackupJson(item);
    }).toList();

    final rawAlarms = map['alarms'];
    if (rawAlarms is! List) {
      throw const FormatException('Backup "alarms" field must be a list.');
    }
    final parsedAlarms = rawAlarms.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid alarm entry in backup.');
      }
      return Alarm.fromBackupJson(item);
    }).toList();

    final rawCategories = map['categories'];
    final List<ReminderCategory> parsedCategories;
    if (rawCategories is List) {
      parsedCategories = rawCategories.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid category entry in backup.');
        }
        return ReminderCategory.fromBackupJson(item);
      }).toList();
    } else {
      parsedCategories = ReminderCategory.defaultCategories(exportedAt);
    }

    final settingsMap =
        (map['settings'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final themeMap = (settingsMap['theme'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final speechMap = (settingsMap['speech'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final prefMap = (settingsMap['preferences'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return BackupBundle(
      formatIdentifier: formatId,
      schemaVersion: version,
      appVersion: appVer,
      exportedAt: exportedAt,
      reminders: parsedReminders,
      alarms: parsedAlarms,
      categories: parsedCategories,
      themeSettings: ThemeSettings.fromMap(themeMap),
      speechSettings: SpeechSettings.fromMap(speechMap),
      userPreferences: UserPreferences.fromMap(prefMap),
    );
  }
}
