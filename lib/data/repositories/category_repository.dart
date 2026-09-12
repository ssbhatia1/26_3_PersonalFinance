import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../models/category.dart';

class CategoryRepository {
  final AppDatabase _dbManager;
  CategoryRepository([AppDatabase? dbManager]) : _dbManager = dbManager ?? AppDatabase.instance;

  Future<List<Category>> getAllCategories({String? type}) async {
    final db = await _dbManager.database;
    final where = (type != null && type != 'all') ? 'type = ?' : null;
    final whereArgs = (type != null && type != 'all') ? [type] : null;

    final maps = await db.query(
      DatabaseTables.categories,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<void> createCategory(Category category) async {
    final db = await _dbManager.database;
    await db.insert(
      DatabaseTables.categories,
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCategory(Category category) async {
    final db = await _dbManager.database;
    await db.update(
      DatabaseTables.categories,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> getCategoryTransactionCount(String categoryId) async {
    final db = await _dbManager.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseTables.transactions} WHERE category_id = ? AND is_deleted = 0',
      [categoryId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteCategory(String id) async {
    final db = await _dbManager.database;
    await db.delete(
      DatabaseTables.categories,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
