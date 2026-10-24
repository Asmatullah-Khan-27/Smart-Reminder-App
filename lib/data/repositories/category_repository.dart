import 'package:sqflite/sqflite.dart';
import '../../domain/models/category.dart';
import '../database/app_database.dart';

class CategoryRepository {
  final AppDatabase _appDatabase;

  CategoryRepository(this._appDatabase);

  Future<List<ReminderCategory>> getAllCategories() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tableCategories,
      orderBy: 'sortOrder ASC, name ASC',
    );
    return rows.map(ReminderCategory.fromMap).toList();
  }

  Future<ReminderCategory?> getCategoryById(String id) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tableCategories,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ReminderCategory.fromMap(rows.first);
  }

  Future<void> createCategory(ReminderCategory category) async {
    category.validate();
    final db = await _appDatabase.database;
    await db.insert(
      AppDatabase.tableCategories,
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCategory(ReminderCategory category) async {
    category.validate();
    final db = await _appDatabase.database;
    final updated = category.copyWith(updatedAt: DateTime.now());
    final count = await db.update(
      AppDatabase.tableCategories,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[category.id],
    );
    if (count == 0) {
      throw StateError('Category "${category.id}" does not exist.');
    }
  }

  Future<int> countRemindersInCategory(String categoryId) async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${AppDatabase.tableReminders} WHERE categoryId = ?',
      <Object?>[categoryId],
    );
    if (result.isEmpty) return 0;
    return (result.first['cnt'] as num?)?.toInt() ?? 0;
  }

  /// Safely deletes a custom category and reassigns any reminders belonging to it
  /// to [reassignToCategoryId] inside an atomic SQLite transaction.
  /// Default categories cannot be deleted.
  Future<int> deleteCategoryWithReassignment({
    required String categoryIdToDelete,
    String reassignToCategoryId = 'other',
  }) async {
    if (categoryIdToDelete == reassignToCategoryId) {
      throw ArgumentError(
        'Target reassignment category must differ from the deleted category.',
      );
    }

    return _appDatabase.runInTransaction<int>((txn) async {
      final catRows = await txn.query(
        AppDatabase.tableCategories,
        where: 'id = ?',
        whereArgs: <Object?>[categoryIdToDelete],
        limit: 1,
      );
      if (catRows.isEmpty) {
        throw StateError('Category "$categoryIdToDelete" not found.');
      }
      final cat = ReminderCategory.fromMap(catRows.first);
      if (cat.isDefault) {
        throw StateError('Default category "${cat.name}" cannot be deleted.');
      }

      // Ensure target category exists; fallback to 'other' if needed
      final targetRows = await txn.query(
        AppDatabase.tableCategories,
        where: 'id = ?',
        whereArgs: <Object?>[reassignToCategoryId],
        limit: 1,
      );
      final effectiveTarget =
          targetRows.isNotEmpty ? reassignToCategoryId : 'other';

      final reassignedCount = await txn.update(
        AppDatabase.tableReminders,
        <String, Object?>{
          'categoryId': effectiveTarget,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'categoryId = ?',
        whereArgs: <Object?>[categoryIdToDelete],
      );

      await txn.delete(
        AppDatabase.tableCategories,
        where: 'id = ?',
        whereArgs: <Object?>[categoryIdToDelete],
      );

      return reassignedCount;
    });
  }
}
