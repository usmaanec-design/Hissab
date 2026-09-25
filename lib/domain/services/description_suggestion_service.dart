import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:hissab/data/database/app_database.dart';
import 'package:hissab/data/database/tables.dart';

/// Intelligent service managing smart description history and ranked suggestions per book.
class DescriptionSuggestionService {
  final Database? _database;
  final Uuid _uuid = const Uuid();

  DescriptionSuggestionService({Database? database}) : _database = database;

  Future<Database> get _db async => _database ?? await AppDatabase.instance.database;

  /// Records a used description for the given book and transaction type.
  Future<void> recordDescription({
    required String bookId,
    required String description,
    required String txType,
  }) async {
    final clean = description.trim();
    if (clean.isEmpty) return;

    final db = await _db;
    final now = DateTime.now().toIso8601String();

    // Check if description already exists for this book and type
    final existing = await db.query(
      Tables.descriptionHistory,
      where: 'book_id = ? AND tx_type = ? AND LOWER(text) = LOWER(?)',
      whereArgs: [bookId, txType, clean],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as String;
      final count = (existing.first['use_count'] as int? ?? 1) + 1;
      await db.update(
        Tables.descriptionHistory,
        {
          'use_count': count,
          'last_used_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.insert(
        Tables.descriptionHistory,
        {
          'id': _uuid.v4(),
          'book_id': bookId,
          'text': clean,
          'tx_type': txType,
          'use_count': 1,
          'last_used_at': now,
        },
      );
    }
  }

  /// Fetches ranked suggestions for the active book and transaction type.
  /// Ranked by frequency (use_count) and recency (last_used_at).
  Future<List<String>> getSuggestions({
    required String bookId,
    required String txType,
    int limit = 6,
  }) async {
    final db = await _db;

    final rows = await db.query(
      Tables.descriptionHistory,
      columns: ['text'],
      where: 'book_id = ? AND tx_type = ?',
      whereArgs: [bookId, txType],
      orderBy: 'use_count DESC, last_used_at DESC',
      limit: limit,
    );

    return rows.map((r) => r['text'] as String).toList();
  }
}
