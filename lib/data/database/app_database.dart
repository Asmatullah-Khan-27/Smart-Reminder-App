import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../domain/models/category.dart';

class AppDatabase {
  static const String defaultDbFileName = 'smart_reminder_voice_alarm.db';
  static const int currentSchemaVersion = 3;

  static const String tableCategories = 'categories';
  static const String tableReminders = 'reminders';
  static const String tableAlarms = 'alarms';
  static const String tableKeyValueStore = 'app_kv_store';

  final DatabaseFactory? customDatabaseFactory;
  final String? customDbPath;

  Database? _db;

  AppDatabase({
    this.customDatabaseFactory,
    this.customDbPath,
  });

  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final factory = customDatabaseFactory ?? databaseFactory;
    final String path;
    if (customDbPath != null) {
      path = customDbPath!;
    } else {
      final dbDir = await factory.getDatabasesPath();
      path = p.join(dbDir, defaultDbFileName);
    }

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: currentSchemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await createSchemaV1(db);
          if (version >= 2) {
            await migrateV1ToV2(db);
          }
          if (version >= 3) {
            await migrateV2ToV3(db);
          }
          await seedDefaultCategories(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2 && newVersion >= 2) {
            await migrateV1ToV2(db);
          }
          if (oldVersion < 3 && newVersion >= 3) {
            await migrateV2ToV3(db);
          }
          await seedDefaultCategories(db);
        },
      ),
    );
  }

  /// Creates Schema Version 1 (core categories, reminders, and alarms tables).
  static Future<void> createSchemaV1(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCategories (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableReminders (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        scheduledDateTime INTEGER NOT NULL,
        recurrenceRule TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'medium',
        completed INTEGER NOT NULL DEFAULT 0,
        notificationEnabled INTEGER NOT NULL DEFAULT 1,
        snoozeDuration INTEGER NOT NULL DEFAULT 10,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableAlarms (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        alarmMode TEXT NOT NULL DEFAULT 'ringtone',
        customMessage TEXT NOT NULL DEFAULT '',
        speechLanguage TEXT NOT NULL DEFAULT 'en-US',
        speechRate REAL NOT NULL DEFAULT 0.5,
        speechPitch REAL NOT NULL DEFAULT 1.0,
        ringtoneIdentifier TEXT NOT NULL DEFAULT 'default_alarm',
        scheduledDateTime INTEGER NOT NULL,
        recurrenceRule TEXT NOT NULL,
        snoozeDuration INTEGER NOT NULL DEFAULT 10,
        enabled INTEGER NOT NULL DEFAULT 1,
        nextOccurrence INTEGER,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
  }

  /// Migration v1 -> v2: Add structured key-value settings table for offline
  /// preferences, theme settings, speech settings, premium entitlement, and ad config.
  static Future<void> migrateV1ToV2(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableKeyValueStore (
        key TEXT PRIMARY KEY NOT NULL,
        valueJson TEXT NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
  }

  /// Migration v2 -> v3: Add performance indexes on scheduledDateTime, categoryId,
  /// completed, and alarm nextOccurrence/enabled.
  static Future<void> migrateV2ToV3(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminders_scheduled ON $tableReminders(scheduledDateTime)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminders_category ON $tableReminders(categoryId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminders_completed ON $tableReminders(completed)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_alarms_next_enabled ON $tableAlarms(enabled, nextOccurrence)',
    );
  }

  /// Ensures all 6 required default categories exist in SQLite.
  static Future<void> seedDefaultCategories(DatabaseExecutor db) async {
    final now = DateTime.now();
    final defaults = ReminderCategory.defaultCategories(now);
    for (final category in defaults) {
      await db.insert(
        tableCategories,
        category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<T> runInTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await database;
    return db.transaction(action);
  }

  Future<void> close() async {
    final existing = _db;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
    _db = null;
  }
}
