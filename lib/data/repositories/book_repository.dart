import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/tables.dart';
import '../models/book_model.dart';

class BookRepository {
  final AppDatabase _dbProvider = AppDatabase.instance;
  final Uuid _uuid = const Uuid();

  Future<BookModel> createBook({
    required String name,
    required String currency,
    required int openingBalanceMinor,
    required String openingBalanceDate,
    int? color,
    String? logo,
  }) async {
    final db = await _dbProvider.database;
    final bookId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    // Determine next displayOrder so new book is placed at the end of the order
    final orderRes = await db.rawQuery('SELECT COALESCE(MAX(display_order), -1) + 1 AS next_order FROM ${Tables.books} WHERE is_deleted = 0');
    final nextOrder = (orderRes.first['next_order'] as num?)?.toInt() ?? 0;

    final book = BookModel(
      id: bookId,
      name: name.trim(),
      currency: currency.toUpperCase(),
      openingBalanceMinor: openingBalanceMinor,
      openingBalanceDate: openingBalanceDate,
      color: color ?? 0xFF2563EB,
      logo: logo,
      displayOrder: nextOrder,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert(Tables.books, book.toMap());
      await AppDatabase.seedDefaultCategories(txn, bookId);
      await AppDatabase.seedDefaultAccounts(txn, bookId);
      await txn.insert(Tables.auditLogs, {
        'id': _uuid.v4(),
        'book_id': bookId,
        'action': 'CREATE_BOOK',
        'details': 'Created book "${book.name}" with opening balance $openingBalanceMinor',
        'timestamp': now,
      });
    });

    return book;
  }

  Future<List<BookModel>> getBooks({bool includeArchived = false}) async {
    final db = await _dbProvider.database;
    final where = includeArchived ? null : 'is_archived = 0';
    final result = await db.query(
      Tables.books,
      where: where,
      orderBy: 'display_order ASC, created_at DESC',
    );
    return result.map((m) => BookModel.fromMap(m)).toList();
  }

  /// Persists reordered book IDs atomically to SQLite
  Future<void> updateBookOrder(List<String> orderedBookIds) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (int i = 0; i < orderedBookIds.length; i++) {
        await txn.update(
          Tables.books,
          {
            'display_order': i,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [orderedBookIds[i]],
        );
      }
    });
  }

  Future<BookModel?> getBookById(String id) async {
    final db = await _dbProvider.database;
    final result = await db.query(
      Tables.books,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return BookModel.fromMap(result.first);
  }

  Future<void> updateBook(BookModel book) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();
    final updated = book.copyWith(updatedAt: now);

    await db.transaction((txn) async {
      await txn.update(
        Tables.books,
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [book.id],
      );
      await txn.insert(Tables.auditLogs, {
        'id': _uuid.v4(),
        'book_id': book.id,
        'action': 'UPDATE_BOOK',
        'details': 'Updated book details for "${book.name}"',
        'timestamp': now,
      });
    });
  }

  Future<void> setArchived(String bookId, bool isArchived) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        Tables.books,
        {'is_archived': isArchived ? 1 : 0, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [bookId],
      );
      await txn.insert(Tables.auditLogs, {
        'id': _uuid.v4(),
        'book_id': bookId,
        'action': isArchived ? 'ARCHIVE_BOOK' : 'UNARCHIVE_BOOK',
        'details': 'Book archived status changed to $isArchived',
        'timestamp': now,
      });
    });
  }

  Future<void> deleteBookPermanently(String bookId) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      await txn.delete(Tables.transactions, where: 'book_id = ?', whereArgs: [bookId]);
      await txn.delete(Tables.categories, where: 'book_id = ?', whereArgs: [bookId]);
      await txn.delete(Tables.parties, where: 'book_id = ?', whereArgs: [bookId]);
      await txn.delete(Tables.accounts, where: 'book_id = ?', whereArgs: [bookId]);
      await txn.delete(Tables.auditLogs, where: 'book_id = ?', whereArgs: [bookId]);
      await txn.delete(Tables.books, where: 'id = ?', whereArgs: [bookId]);
    });
  }
}
