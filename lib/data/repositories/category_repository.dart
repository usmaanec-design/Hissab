import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/tables.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final AppDatabase _dbProvider = AppDatabase.instance;
  final Uuid _uuid = const Uuid();

  Future<CategoryModel> createCategory({
    required String bookId,
    required String name,
    required String type, // 'income' or 'expense'
    required String icon,
    required int color,
  }) async {
    final db = await _dbProvider.database;
    final category = CategoryModel(
      id: _uuid.v4(),
      bookId: bookId,
      name: name.trim(),
      type: type.toLowerCase(),
      icon: icon,
      color: color,
      isDefault: false,
      isDeleted: false,
      createdAt: DateTime.now().toIso8601String(),
    );

    await db.insert(Tables.categories, category.toMap());
    return category;
  }

  Future<List<CategoryModel>> getCategories(String bookId, {String? type}) async {
    final db = await _dbProvider.database;
    final whereClauses = <String>['book_id = ?', 'is_deleted = 0'];
    final whereArgs = <dynamic>[bookId];

    if (type != null && type.isNotEmpty && type != 'all') {
      whereClauses.add('type = ?');
      whereArgs.add(type.toLowerCase());
    }

    final result = await db.query(
      Tables.categories,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'is_default DESC, name ASC',
    );

    return result.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<CategoryModel?> getCategoryById(String id) async {
    final db = await _dbProvider.database;
    final result = await db.query(
      Tables.categories,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return CategoryModel.fromMap(result.first);
  }

  Future<void> updateCategory(CategoryModel category) async {
    final db = await _dbProvider.database;
    await db.update(
      Tables.categories,
      category.toMap(),
      where: 'id = ? AND book_id = ?',
      whereArgs: [category.id, category.bookId],
    );
  }

  /// Checks if any non-deleted transactions use this category before allowing deletion
  Future<bool> isCategoryInUse(String categoryId, String bookId) async {
    final db = await _dbProvider.database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${Tables.transactions} WHERE category_id = ? AND book_id = ? AND is_deleted = 0',
      [categoryId, bookId],
    ));
    return (count ?? 0) > 0;
  }

  Future<bool> deleteCategory(String categoryId, String bookId) async {
    final inUse = await isCategoryInUse(categoryId, bookId);
    if (inUse) return false; // Prevent deletion of active categories

    final db = await _dbProvider.database;
    await db.update(
      Tables.categories,
      {'is_deleted': 1},
      where: 'id = ? AND book_id = ?',
      whereArgs: [categoryId, bookId],
    );
    return true;
  }
}
