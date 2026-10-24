import 'package:sqflite/sqflite.dart';
import '../../domain/models/recurrence_rule.dart';
import '../../domain/models/reminder.dart';
import '../database/app_database.dart';

class ReminderRepository {
  final AppDatabase _appDatabase;

  ReminderRepository(this._appDatabase);

  Future<List<Reminder>> getAllReminders() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tableReminders,
      orderBy: 'completed ASC, scheduledDateTime ASC',
    );
    return rows.map(Reminder.fromMap).toList();
  }

  Future<Reminder?> getReminderById(String id) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tableReminders,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Reminder.fromMap(rows.first);
  }

  Future<void> createReminder(Reminder reminder) async {
    reminder.validate();
    final db = await _appDatabase.database;
    await db.insert(
      AppDatabase.tableReminders,
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateReminder(Reminder reminder) async {
    reminder.validate();
    final db = await _appDatabase.database;
    final updated = reminder.copyWith(updatedAt: DateTime.now());
    final count = await db.update(
      AppDatabase.tableReminders,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[reminder.id],
    );
    if (count == 0) {
      throw StateError('Reminder "${reminder.id}" not found.');
    }
  }

  Future<void> deleteReminder(String id) async {
    final db = await _appDatabase.database;
    await db.delete(
      AppDatabase.tableReminders,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Marks a reminder as completed or uncompleted.
  /// If a recurring reminder is marked completed and [rescheduleIfRecurring] is true,
  /// advances the reminder to its next scheduled occurrence and keeps it active,
  /// or marks it completed if the recurrence rule has ended.
  Future<Reminder> completeOrAdvanceReminder(
    String id, {
    required bool completed,
    DateTime? now,
    bool rescheduleIfRecurring = true,
  }) async {
    final currentTime = now ?? DateTime.now();
    return _appDatabase.runInTransaction<Reminder>((txn) async {
      final rows = await txn.query(
        AppDatabase.tableReminders,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Reminder "$id" not found.');
      }
      final existing = Reminder.fromMap(rows.first);

      Reminder updated;
      if (completed &&
          rescheduleIfRecurring &&
          existing.recurrenceRule.isRecurring) {
        final nextTime = RecurrenceEngine.computeNextAfterCompletion(
          currentScheduled: existing.scheduledDateTime,
          rule: existing.recurrenceRule,
          completedAt: currentTime,
        );
        if (nextTime != null) {
          updated = existing.copyWith(
            scheduledDateTime: nextTime,
            completed: false,
            updatedAt: currentTime,
          );
        } else {
          updated = existing.copyWith(
            completed: true,
            updatedAt: currentTime,
          );
        }
      } else {
        updated = existing.copyWith(
          completed: completed,
          updatedAt: currentTime,
        );
      }

      await txn.update(
        AppDatabase.tableReminders,
        updated.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return updated;
    });
  }

  /// Snoozes a reminder by [customMinutes] (or its configured snoozeDuration).
  Future<Reminder> snoozeReminder(
    String id, {
    int? customMinutes,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    return _appDatabase.runInTransaction<Reminder>((txn) async {
      final rows = await txn.query(
        AppDatabase.tableReminders,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Reminder "$id" not found.');
      }
      final existing = Reminder.fromMap(rows.first);
      final snoozedUntil = existing.calculateSnoozedTime(
        currentTime,
        customMinutes: customMinutes,
      );
      final updated = existing.copyWith(
        scheduledDateTime: snoozedUntil,
        completed: false,
        updatedAt: currentTime,
      );
      await txn.update(
        AppDatabase.tableReminders,
        updated.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return updated;
    });
  }
}
