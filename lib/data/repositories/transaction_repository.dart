import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/tables.dart';
import '../models/transaction_model.dart';

class TransactionFilter {
  final String? startDate; // YYYY-MM-DD
  final String? endDate; // YYYY-MM-DD
  final String? typeFilter; // 'ALL', 'IN', 'OUT'
  final String? categoryId;
  final String? partyId;
  final String? accountId;
  final String? paymentMethod;
  final int? minAmountMinor;
  final int? maxAmountMinor;
  final String? searchQuery;
  final bool includeDeleted;

  const TransactionFilter({
    this.startDate,
    this.endDate,
    this.typeFilter,
    this.categoryId,
    this.partyId,
    this.accountId,
    this.paymentMethod,
    this.minAmountMinor,
    this.maxAmountMinor,
    this.searchQuery,
    this.includeDeleted = false,
  });
}

class TransactionRepository {
  final AppDatabase _dbProvider = AppDatabase.instance;
  final Uuid _uuid = const Uuid();

  /// Record a new transaction (Income, Expense, Receivable, Payable, etc.)
  Future<TransactionModel> addTransaction(TransactionModel tx) async {
    assert(tx.amountMinorUnit > 0, 'Transaction amount must be strictly greater than 0');

    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();
    final newTx = tx.copyWith(
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert(Tables.transactions, newTx.toMap());
      await txn.insert(Tables.auditLogs, {
        'id': _uuid.v4(),
        'book_id': tx.bookId,
        'action': 'CREATE_TRANSACTION',
        'details': '${tx.type.toDbString()} of minor amount ${tx.amountMinorUnit} recorded',
        'timestamp': now,
      });
    });

    return newTx;
  }

  /// Edit existing transaction with full balance audit safety
  Future<void> updateTransaction(TransactionModel tx) async {
    assert(tx.amountMinorUnit > 0, 'Transaction amount must be strictly greater than 0');

    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();
    final updated = tx.copyWith(updatedAt: now);

    await db.transaction((txn) async {
      await txn.update(
        Tables.transactions,
        updated.toMap(),
        where: 'id = ? AND book_id = ?',
        whereArgs: [tx.id, tx.bookId],
      );
      await txn.insert(Tables.auditLogs, {
        'id': _uuid.v4(),
        'book_id': tx.bookId,
        'action': 'EDIT_TRANSACTION',
        'details': 'Transaction ${tx.id} updated to ${tx.amountMinorUnit}',
        'timestamp': now,
      });
    });
  }

  /// Soft delete transaction to protect accounting integrity
  Future<void> softDeleteTransaction(String transactionId, String bookId) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        Tables.transactions,
        {
          'is_deleted': 1,
          'deleted_at': now,
          'updated_at': now,
        },
        where: 'id = ? AND book_id = ?',
        whereArgs: [transactionId, bookId],
      );
      await txn.insert(Tables.auditLogs, {
        'id': _uuid.v4(),
        'book_id': bookId,
        'action': 'DELETE_TRANSACTION',
        'details': 'Transaction $transactionId soft deleted',
        'timestamp': now,
      });
    });
  }

  /// Restore a soft-deleted transaction from trash
  Future<void> restoreTransaction(String transactionId, String bookId) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        Tables.transactions,
        {
          'is_deleted': 0,
          'deleted_at': null,
          'updated_at': now,
        },
        where: 'id = ? AND book_id = ?',
        whereArgs: [transactionId, bookId],
      );
      await txn.insert(Tables.auditLogs, {
        'id': _uuid.v4(),
        'book_id': bookId,
        'action': 'RESTORE_TRANSACTION',
        'details': 'Transaction $transactionId restored from trash',
        'timestamp': now,
      });
    });
  }

  /// Create internal transfer between two accounts within a book
  /// Atomic operation: Debit source (TRANSFER_OUT), credit destination (TRANSFER_IN)
  Future<void> createInternalTransfer({
    required String bookId,
    required String sourceAccountId,
    required String destinationAccountId,
    required int amountMinorUnit,
    required String date,
    required String time,
    String? description,
  }) async {
    assert(amountMinorUnit > 0, 'Transfer amount must be strictly greater than 0');
    assert(sourceAccountId != destinationAccountId, 'Cannot transfer to the same account');

    final db = await _dbProvider.database;
    final transferId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    final outTx = TransactionModel(
      id: _uuid.v4(),
      bookId: bookId,
      accountId: sourceAccountId,
      type: TransactionType.transferOut,
      amountMinorUnit: amountMinorUnit,
      date: date,
      time: time,
      description: description ?? 'Internal Transfer Out',
      transferId: transferId,
      createdAt: now,
      updatedAt: now,
    );

    final inTx = TransactionModel(
      id: _uuid.v4(),
      bookId: bookId,
      accountId: destinationAccountId,
      type: TransactionType.transferIn,
      amountMinorUnit: amountMinorUnit,
      date: date,
      time: time,
      description: description ?? 'Internal Transfer In',
      transferId: transferId,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert(Tables.transactions, outTx.toMap());
      await txn.insert(Tables.transactions, inTx.toMap());
      await txn.insert(Tables.auditLogs, {
        'id': _uuid.v4(),
        'book_id': bookId,
        'action': 'TRANSFER',
        'details': 'Transfer of $amountMinorUnit from $sourceAccountId to $destinationAccountId',
        'timestamp': now,
      });
    });
  }

  /// Query transactions for a book with full filtering and pagination
  Future<List<TransactionModel>> getTransactions({
    required String bookId,
    TransactionFilter filter = const TransactionFilter(),
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _dbProvider.database;
    final whereClauses = <String>['book_id = ?'];
    final whereArgs = <dynamic>[bookId];

    if (!filter.includeDeleted) {
      whereClauses.add('is_deleted = 0');
    }

    if (filter.startDate != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(filter.startDate);
    }
    if (filter.endDate != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(filter.endDate);
    }

    if (filter.typeFilter != null) {
      if (filter.typeFilter == 'IN') {
        whereClauses.add("type IN ('INCOME', 'PAYMENT_RECEIVED', 'TRANSFER_IN')");
      } else if (filter.typeFilter == 'OUT') {
        whereClauses.add("type IN ('EXPENSE', 'PAYMENT_MADE', 'TRANSFER_OUT')");
      }
    }

    if (filter.categoryId != null) {
      whereClauses.add('category_id = ?');
      whereArgs.add(filter.categoryId);
    }

    if (filter.partyId != null) {
      whereClauses.add('party_id = ?');
      whereArgs.add(filter.partyId);
    }

    if (filter.accountId != null) {
      whereClauses.add('account_id = ?');
      whereArgs.add(filter.accountId);
    }

    if (filter.paymentMethod != null && filter.paymentMethod!.isNotEmpty) {
      whereClauses.add('payment_method = ?');
      whereArgs.add(filter.paymentMethod);
    }

    if (filter.minAmountMinor != null) {
      whereClauses.add('amount_minor >= ?');
      whereArgs.add(filter.minAmountMinor);
    }
    if (filter.maxAmountMinor != null) {
      whereClauses.add('amount_minor <= ?');
      whereArgs.add(filter.maxAmountMinor);
    }

    if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
      final query = '%${filter.searchQuery!.trim()}%';
      whereClauses.add('(description LIKE ? OR reference_number LIKE ?)');
      whereArgs.add(query);
      whereArgs.add(query);
    }

    final whereString = whereClauses.join(' AND ');

    final result = await db.query(
      Tables.transactions,
      where: whereString,
      whereArgs: whereArgs,
      orderBy: 'date DESC, time DESC, created_at DESC',
      limit: limit,
      offset: offset,
    );

    return result.map((m) => TransactionModel.fromMap(m)).toList();
  }

  /// Get ALL non-deleted transactions for a book (used by calculation engine, exports, and reports)
  Future<List<TransactionModel>> getAllActiveTransactions(String bookId) async {
    final db = await _dbProvider.database;
    final result = await db.query(
      Tables.transactions,
      where: 'book_id = ? AND is_deleted = 0',
      whereArgs: [bookId],
      orderBy: 'date ASC, time ASC, created_at ASC',
    );
    return result.map((m) => TransactionModel.fromMap(m)).toList();
  }

  /// Get recent transactions for the dashboard
  Future<List<TransactionModel>> getRecentTransactions(String bookId, {int limit = 10}) async {
    return getTransactions(
      bookId: bookId,
      limit: limit,
      offset: 0,
    );
  }
}
