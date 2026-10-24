import 'package:sqflite/sqflite.dart';
import '../../domain/models/alarm.dart';
import '../../domain/models/recurrence_rule.dart';
import '../database/app_database.dart';

class AlarmRepository {
  final AppDatabase _appDatabase;

  AlarmRepository(this._appDatabase);

  Future<List<Alarm>> getAllAlarms() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tableAlarms,
      orderBy: 'enabled DESC, nextOccurrence ASC, scheduledDateTime ASC',
    );
    return rows.map(Alarm.fromMap).toList();
  }

  Future<List<Alarm>> getEnabledAlarms() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tableAlarms,
      where: 'enabled = 1',
      orderBy: 'nextOccurrence ASC, scheduledDateTime ASC',
    );
    return rows.map(Alarm.fromMap).toList();
  }

  Future<Alarm?> getAlarmById(String id) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tableAlarms,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Alarm.fromMap(rows.first);
  }

  Future<Alarm> createAlarm(Alarm alarm, {DateTime? now}) async {
    alarm.validate();
    final currentTime = now ?? DateTime.now();
    final prepared = alarm.withRecomputedNextOccurrence(currentTime);
    final db = await _appDatabase.database;
    await db.insert(
      AppDatabase.tableAlarms,
      prepared.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return prepared;
  }

  Future<Alarm> updateAlarm(Alarm alarm, {DateTime? now}) async {
    alarm.validate();
    final currentTime = now ?? DateTime.now();
    final prepared = alarm.withRecomputedNextOccurrence(currentTime);
    final db = await _appDatabase.database;
    final count = await db.update(
      AppDatabase.tableAlarms,
      prepared.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[alarm.id],
    );
    if (count == 0) {
      throw StateError('Alarm "${alarm.id}" not found.');
    }
    return prepared;
  }

  Future<Alarm> toggleAlarmEnabled(
    String id, {
    required bool enabled,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    return _appDatabase.runInTransaction<Alarm>((txn) async {
      final rows = await txn.query(
        AppDatabase.tableAlarms,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Alarm "$id" not found.');
      }
      final existing = Alarm.fromMap(rows.first);
      final toggled = existing
          .copyWith(enabled: enabled, updatedAt: currentTime)
          .withRecomputedNextOccurrence(currentTime);

      await txn.update(
        AppDatabase.tableAlarms,
        toggled.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return toggled;
    });
  }

  Future<Alarm> snoozeAlarm(
    String id, {
    int? customMinutes,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    return _appDatabase.runInTransaction<Alarm>((txn) async {
      final rows = await txn.query(
        AppDatabase.tableAlarms,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Alarm "$id" not found.');
      }
      final existing = Alarm.fromMap(rows.first);
      final snoozedNext = existing.calculateSnoozedOccurrence(
        currentTime,
        customMinutes: customMinutes,
      );
      final updated = existing.copyWith(
        enabled: true,
        nextOccurrence: snoozedNext,
        updatedAt: currentTime,
      );
      await txn.update(
        AppDatabase.tableAlarms,
        updated.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return updated;
    });
  }

  /// Dismisses a ringing/triggered alarm.
  /// If the alarm is recurring, advances `nextOccurrence` to the next scheduled cycle.
  /// If it is a one-time alarm, disables it and clears `nextOccurrence`.
  Future<Alarm> dismissTriggeredAlarm(
    String id, {
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    return _appDatabase.runInTransaction<Alarm>((txn) async {
      final rows = await txn.query(
        AppDatabase.tableAlarms,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Alarm "$id" not found.');
      }
      final existing = Alarm.fromMap(rows.first);
      Alarm updated;
      if (existing.recurrenceRule.isRecurring) {
        final next = RecurrenceEngine.computeNextAfterCompletion(
          currentScheduled: existing.scheduledDateTime,
          rule: existing.recurrenceRule,
          completedAt: currentTime,
        );
        updated = existing.copyWith(
          enabled: next != null,
          nextOccurrence: next,
          clearNextOccurrence: next == null,
          updatedAt: currentTime,
        );
      } else {
        updated = existing.copyWith(
          enabled: false,
          clearNextOccurrence: true,
          updatedAt: currentTime,
        );
      }

      await txn.update(
        AppDatabase.tableAlarms,
        updated.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return updated;
    });
  }

  Future<void> deleteAlarm(String id) async {
    final db = await _appDatabase.database;
    await db.delete(
      AppDatabase.tableAlarms,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}
