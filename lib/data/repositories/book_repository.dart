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
  }) async {
    final db = await _dbProvider.database;
    final bookId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    final book = BookModel(
      id: bookId,
      name: name.trim(),
      currency: currency.toUpperCase(),
      openingBalanceMinor: openingBalanceMinor,
      openingBalanceDate: openingBalanceDate,
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
      orderBy: 'created_at DESC',
    );
    return result.map((m) => BookModel.fromMap(m)).toList();
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
