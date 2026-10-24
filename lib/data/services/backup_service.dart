import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/models/backup_bundle.dart';
import '../../domain/models/category.dart';
import '../database/app_database.dart';
import '../repositories/alarm_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/settings_repository.dart';

class BackupService {
  final AppDatabase appDatabase;
  final ReminderRepository reminderRepository;
  final AlarmRepository alarmRepository;
  final CategoryRepository categoryRepository;
  final SettingsRepository settingsRepository;

  BackupService({
    required this.appDatabase,
    required this.reminderRepository,
    required this.alarmRepository,
    required this.categoryRepository,
    required this.settingsRepository,
  });

  Future<BackupBundle> createBackupBundle({
    String appVersion = '1.2.0',
    DateTime? exportedAt,
  }) async {
    final now = exportedAt ?? DateTime.now();
    final reminders = await reminderRepository.getAllReminders();
    final alarms = await alarmRepository.getAllAlarms();
    final categories = await categoryRepository.getAllCategories();
    final themeSettings = await settingsRepository.loadThemeSettings();
    final speechSettings = await settingsRepository.loadSpeechSettings();
    final userPreferences = await settingsRepository.loadUserPreferences();

    return BackupBundle(
      appVersion: appVersion,
      exportedAt: now,
      reminders: reminders,
      alarms: alarms,
      categories: categories,
      themeSettings: themeSettings,
      speechSettings: speechSettings,
      userPreferences: userPreferences,
    ).validatedAndNormalized();
  }

  Future<File> exportBackupToFile({
    String? customDirectoryPath,
    String appVersion = '1.2.0',
  }) async {
    final bundle = await createBackupBundle(appVersion: appVersion);
    final String dirPath;
    if (customDirectoryPath != null) {
      dirPath = customDirectoryPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dirPath = dir.path;
    }
    final timestamp = bundle.exportedAt
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final filePath = p.join(dirPath, 'smart_reminder_backup_$timestamp.json');
    final file = File(filePath);
    await file.writeAsString(bundle.toPrettyJson(), flush: true);
    return file;
  }

  /// Validates raw JSON and returns the normalized [BackupBundle] without modifying SQLite.
  BackupBundle validateBackupJson(String jsonContent) {
    return BackupBundle.fromJsonString(jsonContent);
  }

  /// Restores a validated [BackupBundle] inside a single SQLite transaction so
  /// any unexpected failure rolls back completely without corrupting existing records.
  Future<RestoreSummary> restoreFromJson(
    String jsonContent, {
    required RestoreStrategy strategy,
    bool restoreSettings = true,
    DateTime? now,
  }) async {
    final bundle = validateBackupJson(jsonContent);
    final currentTime = now ?? DateTime.now();

    int remindersInserted = 0;
    int remindersUpdated = 0;
    int remindersSkipped = 0;
    int alarmsInserted = 0;
    int alarmsUpdated = 0;
    int alarmsSkipped = 0;
    int categoriesRestored = 0;

    await appDatabase.runInTransaction<void>((txn) async {
      if (strategy == RestoreStrategy.replaceAll) {
        await txn.delete(AppDatabase.tableReminders);
        await txn.delete(AppDatabase.tableAlarms);
        await txn.delete(
          AppDatabase.tableCategories,
          where: 'isDefault = 0',
        );
      }

      // Ensure default categories exist
      for (final def in ReminderCategory.defaultCategories(currentTime)) {
        await txn.insert(
          AppDatabase.tableCategories,
          def.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // Restore categories
      for (final cat in bundle.categories) {
        final existing = await txn.query(
          AppDatabase.tableCategories,
          where: 'id = ?',
          whereArgs: <Object?>[cat.id],
          limit: 1,
        );
        if (existing.isEmpty) {
          await txn.insert(AppDatabase.tableCategories, cat.toMap());
          categoriesRestored++;
        } else if (strategy != RestoreStrategy.mergeKeepExisting) {
          await txn.update(
            AppDatabase.tableCategories,
            cat.toMap(),
            where: 'id = ?',
            whereArgs: <Object?>[cat.id],
          );
          categoriesRestored++;
        }
      }

      // Restore reminders
      for (final reminder in bundle.reminders) {
        final existing = await txn.query(
          AppDatabase.tableReminders,
          where: 'id = ?',
          whereArgs: <Object?>[reminder.id],
          limit: 1,
        );
        if (existing.isEmpty) {
          await txn.insert(AppDatabase.tableReminders, reminder.toMap());
          remindersInserted++;
        } else {
          if (strategy == RestoreStrategy.mergeKeepExisting) {
            remindersSkipped++;
          } else {
            await txn.update(
              AppDatabase.tableReminders,
              reminder.toMap(),
              where: 'id = ?',
              whereArgs: <Object?>[reminder.id],
            );
            remindersUpdated++;
          }
        }
      }

      // Restore alarms (recomputing nextOccurrence relative to currentTime)
      for (final alarm in bundle.alarms) {
        final recomputed = alarm.withRecomputedNextOccurrence(currentTime);
        final existing = await txn.query(
          AppDatabase.tableAlarms,
          where: 'id = ?',
          whereArgs: <Object?>[recomputed.id],
          limit: 1,
        );
        if (existing.isEmpty) {
          await txn.insert(AppDatabase.tableAlarms, recomputed.toMap());
          alarmsInserted++;
        } else {
          if (strategy == RestoreStrategy.mergeKeepExisting) {
            alarmsSkipped++;
          } else {
            await txn.update(
              AppDatabase.tableAlarms,
              recomputed.toMap(),
              where: 'id = ?',
              whereArgs: <Object?>[recomputed.id],
            );
            alarmsUpdated++;
          }
        }
      }

      if (restoreSettings) {
        Future<void> writeKv(String key, Map<String, dynamic> value) async {
          await txn.insert(
            AppDatabase.tableKeyValueStore,
            <String, Object?>{
              'key': key,
              'valueJson': jsonEncode(value),
              'updatedAt': currentTime.millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await writeKv(
          SettingsRepository.keyThemeSettings,
          bundle.themeSettings.toMap(),
        );
        await writeKv(
          SettingsRepository.keySpeechSettings,
          bundle.speechSettings.toMap(),
        );
        await writeKv(
          SettingsRepository.keyUserPreferences,
          bundle.userPreferences.toMap(),
        );
      }
    });

    return RestoreSummary(
      remindersInserted: remindersInserted,
      remindersUpdated: remindersUpdated,
      remindersSkipped: remindersSkipped,
      alarmsInserted: alarmsInserted,
      alarmsUpdated: alarmsUpdated,
      alarmsSkipped: alarmsSkipped,
      categoriesRestored: categoriesRestored,
      settingsRestored: restoreSettings,
    );
  }
}
