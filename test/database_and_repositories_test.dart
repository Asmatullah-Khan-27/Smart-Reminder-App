import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_reminder_alarm/data/database/app_database.dart';
import 'package:smart_reminder_alarm/data/repositories/alarm_repository.dart';
import 'package:smart_reminder_alarm/data/repositories/category_repository.dart';
import 'package:smart_reminder_alarm/data/repositories/reminder_repository.dart';
import 'package:smart_reminder_alarm/data/repositories/settings_repository.dart';
import 'package:smart_reminder_alarm/data/services/backup_service.dart';
import 'package:smart_reminder_alarm/domain/models/alarm.dart';
import 'package:smart_reminder_alarm/domain/models/app_settings.dart';
import 'package:smart_reminder_alarm/domain/models/backup_bundle.dart';
import 'package:smart_reminder_alarm/domain/models/category.dart';
import 'package:smart_reminder_alarm/domain/models/recurrence_rule.dart';
import 'package:smart_reminder_alarm/domain/models/reminder.dart';
import 'package:smart_reminder_alarm/platform/entitlement_billing_service.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase appDb;
  late ReminderRepository reminderRepo;
  late AlarmRepository alarmRepo;
  late CategoryRepository categoryRepo;
  late SettingsRepository settingsRepo;
  late BackupService backupService;

  setUp(() async {
    appDb = AppDatabase(
      customDatabaseFactory: databaseFactoryFfi,
      customDbPath: inMemoryDatabasePath,
    );
    reminderRepo = ReminderRepository(appDb);
    alarmRepo = AlarmRepository(appDb);
    categoryRepo = CategoryRepository(appDb);
    settingsRepo = SettingsRepository(appDb);
    backupService = BackupService(
      appDatabase: appDb,
      reminderRepository: reminderRepo,
      alarmRepository: alarmRepo,
      categoryRepository: categoryRepo,
      settingsRepository: settingsRepo,
    );
  });

  tearDown(() async {
    await appDb.close();
  });

  group('SQLite Schema Migration & Default Categories', () {
    test('Seeds all 6 required default categories on creation', () async {
      final categories = await categoryRepo.getAllCategories();
      final ids = categories.map((c) => c.id).toSet();
      expect(
        ids,
        containsAll(<String>[
          'personal',
          'work',
          'study',
          'health',
          'shopping',
          'other',
        ]),
      );
    });

    test('Schema migration v1 -> v2 -> v3 preserves v1 records and adds v2/v3 structures', () async {
      // Simulate a v1 database upgrade in an isolated FFI database
      final rawDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await AppDatabase.createSchemaV1(db);
          },
        ),
      );

      final now = DateTime(2026, 10, 25, 9, 0);
      await rawDb.insert(
        AppDatabase.tableReminders,
        Reminder(
          id: 'migrated-rem-1',
          title: 'Pre-migration V1 Reminder',
          scheduledDateTime: now,
          createdAt: now,
          updatedAt: now,
        ).toMap(),
      );

      // Apply v1->v2 and v2->v3 migrations
      await AppDatabase.migrateV1ToV2(rawDb);
      await AppDatabase.migrateV2ToV3(rawDb);
      await AppDatabase.seedDefaultCategories(rawDb);

      final remRows = await rawDb.query(
        AppDatabase.tableReminders,
        where: 'id = ?',
        whereArgs: <Object?>['migrated-rem-1'],
      );
      expect(remRows.length, equals(1));
      expect(remRows.first['title'], equals('Pre-migration V1 Reminder'));

      // Verify v2 key-value store exists
      await rawDb.insert(
        AppDatabase.tableKeyValueStore,
        <String, Object?>{
          'key': 'migration_check',
          'valueJson': '{"ok":true}',
          'updatedAt': now.millisecondsSinceEpoch,
        },
      );
      final kvRows = await rawDb.query(AppDatabase.tableKeyValueStore);
      expect(kvRows.length, equals(1));
      await rawDb.close();
    });
  });

  group('Reminder CRUD, Recurrence Advancement & Category Reassignment', () {
    test('Full Reminder CRUD and recurring completion advances scheduledDateTime', () async {
      final now = DateTime(2026, 10, 25, 9, 0);
      final reminder = Reminder(
        id: 'rem-crud-1',
        title: 'Daily Standup',
        notes: 'Sync with Android Kotlin team',
        scheduledDateTime: now,
        recurrenceRule: RecurrenceRule.daily(interval: 1),
        categoryId: 'work',
        priority: ReminderPriority.high,
        snoozeDuration: 10,
        createdAt: now,
        updatedAt: now,
      );

      await reminderRepo.createReminder(reminder);
      final fetched = await reminderRepo.getReminderById('rem-crud-1');
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('Daily Standup'));

      // Complete the daily reminder -> should advance to Oct 26, 2026 at 09:00 and remain active
      final afterComplete = await reminderRepo.completeOrAdvanceReminder(
        'rem-crud-1',
        completed: true,
        now: DateTime(2026, 10, 25, 9, 5),
      );
      expect(afterComplete.completed, isFalse);
      expect(
        afterComplete.scheduledDateTime,
        equals(DateTime(2026, 10, 26, 9, 0)),
      );

      // Snooze the reminder by 20 minutes
      final snoozed = await reminderRepo.snoozeReminder(
        'rem-crud-1',
        customMinutes: 20,
        now: DateTime(2026, 10, 26, 9, 2),
      );
      expect(
        snoozed.scheduledDateTime,
        equals(DateTime(2026, 10, 26, 9, 22)),
      );

      // Delete reminder
      await reminderRepo.deleteReminder('rem-crud-1');
      expect(await reminderRepo.getReminderById('rem-crud-1'), isNull);
    });

    test('Deleting custom category reassigns associated reminders atomically without deleting them', () async {
      final now = DateTime(2026, 10, 25, 10, 0);
      final customCat = ReminderCategory(
        id: 'custom_finance',
        name: 'Finance',
        colorValue: 0xFF10B981,
        iconCodePoint: Icons.account_balance_wallet_outlined.codePoint,
        isDefault: false,
        sortOrder: 10,
        createdAt: now,
        updatedAt: now,
      );
      await categoryRepo.createCategory(customCat);

      await reminderRepo.createReminder(
        Reminder(
          id: 'rem-fin-1',
          title: 'Pay Cloud Invoice',
          scheduledDateTime: now.add(const Duration(hours: 2)),
          categoryId: 'custom_finance',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Verify default category cannot be deleted
      expect(
        () => categoryRepo.deleteCategoryWithReassignment(
          categoryIdToDelete: 'personal',
          reassignToCategoryId: 'other',
        ),
        throwsStateError,
      );

      // Delete custom_finance and reassign its reminders to 'work'
      final reassignedCount = await categoryRepo.deleteCategoryWithReassignment(
        categoryIdToDelete: 'custom_finance',
        reassignToCategoryId: 'work',
      );
      expect(reassignedCount, equals(1));

      final updatedRem = await reminderRepo.getReminderById('rem-fin-1');
      expect(updatedRem, isNotNull);
      expect(updatedRem!.categoryId, equals('work'));
      expect(await categoryRepo.getCategoryById('custom_finance'), isNull);
    });
  });

  group('Alarm CRUD, Enable/Disable, Snooze & Dismissal Logic', () {
    test('Voice Alarm persistence, toggle disable/enable, snooze, and dismissal', () async {
      final now = DateTime(2026, 10, 25, 6, 0);
      final scheduled = DateTime(2026, 10, 25, 7, 0);

      final alarm = Alarm(
        id: 'alarm-voice-1',
        title: 'Roman Urdu Wake-Up',
        alarmMode: AlarmMode.voice,
        customMessage: Alarm.defaultRomanUrduMessage,
        speechLanguage: 'ur-PK',
        speechRate: 0.5,
        speechPitch: 1.0,
        scheduledDateTime: scheduled,
        recurrenceRule: RecurrenceRule.oneTime(),
        snoozeDuration: 10,
        enabled: true,
        nextOccurrence: scheduled,
        createdAt: now,
        updatedAt: now,
      );

      final created = await alarmRepo.createAlarm(alarm, now: now);
      expect(created.enabled, isTrue);
      expect(created.nextOccurrence, equals(scheduled));

      // Disable alarm -> nextOccurrence becomes null
      final disabled = await alarmRepo.toggleAlarmEnabled(
        'alarm-voice-1',
        enabled: false,
        now: now,
      );
      expect(disabled.enabled, isFalse);
      expect(disabled.nextOccurrence, isNull);

      // Re-enable alarm -> nextOccurrence restored
      final reEnabled = await alarmRepo.toggleAlarmEnabled(
        'alarm-voice-1',
        enabled: true,
        now: now,
      );
      expect(reEnabled.enabled, isTrue);
      expect(reEnabled.nextOccurrence, equals(scheduled));

      // Snooze alarm at 07:00 -> 07:10
      final snoozed = await alarmRepo.snoozeAlarm(
        'alarm-voice-1',
        now: scheduled,
      );
      expect(snoozed.nextOccurrence, equals(DateTime(2026, 10, 25, 7, 10)));

      // Dismiss one-time alarm -> disables it
      final dismissed = await alarmRepo.dismissTriggeredAlarm(
        'alarm-voice-1',
        now: DateTime(2026, 10, 25, 7, 10),
      );
      expect(dismissed.enabled, isFalse);
      expect(dismissed.nextOccurrence, isNull);
    });
  });

  group('Entitlements & Versioned Backup / Restore Engine', () {
    test('Entitlement service gates Pro features and does not fake store purchases', () async {
      final service = EntitlementBillingService(
        settingsRepository: settingsRepo,
      );

      // Initially Free tier
      expect(
        await service.isFeatureEntitled(PremiumFeature.customSpokenAlarms),
        isFalse,
      );

      // Attempting a live Google Play purchase without Play Console billing returns completed: false
      final playProvider = service.providerFor(StoreBillingVendor.googlePlay);
      final purchaseAttempt = await playProvider.initiateSubscriptionPurchase(
        GooglePlayBillingProvider.monthlySku,
      );
      expect(purchaseAttempt.completed, isFalse);

      // Enabling QA Sandbox override unlocks Pro features locally
      await service.setQaSandboxEntitlement(enabled: true);
      expect(
        await service.isFeatureEntitled(PremiumFeature.customSpokenAlarms),
        isTrue,
      );
    });

    test('Backup export, validation, invalid JSON rejection, and transactional restore', () async {
      final now = DateTime(2026, 10, 25, 10, 0);
      await reminderRepo.createReminder(
        Reminder(
          id: 'backup-rem-1',
          title: 'Original Reminder',
          scheduledDateTime: now.add(const Duration(hours: 3)),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final exportedBundle = await backupService.createBackupBundle(
        exportedAt: now,
      );
      final jsonStr = exportedBundle.toPrettyJson();

      // Reject corrupted JSON without harming existing SQLite records
      expect(
        () => backupService.restoreFromJson(
          '{"formatIdentifier":"INVALID_HEADER"}',
          strategy: RestoreStrategy.replaceAll,
        ),
        throwsFormatException,
      );
      expect((await reminderRepo.getAllReminders()).length, equals(1));

      // Modify reminder title in SQLite, then test mergeKeepExisting vs mergeOverwriteDuplicates
      await reminderRepo.updateReminder(
        Reminder(
          id: 'backup-rem-1',
          title: 'Locally Modified Title',
          scheduledDateTime: now.add(const Duration(hours: 3)),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final keepSummary = await backupService.restoreFromJson(
        jsonStr,
        strategy: RestoreStrategy.mergeKeepExisting,
        now: now,
      );
      expect(keepSummary.remindersSkipped, equals(1));
      expect(
        (await reminderRepo.getReminderById('backup-rem-1'))!.title,
        equals('Locally Modified Title'),
      );

      final overwriteSummary = await backupService.restoreFromJson(
        jsonStr,
        strategy: RestoreStrategy.mergeOverwriteDuplicates,
        now: now,
      );
      expect(overwriteSummary.remindersUpdated, equals(1));
      expect(
        (await reminderRepo.getReminderById('backup-rem-1'))!.title,
        equals('Original Reminder'),
      );
    });
  });
}
