import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/tables.dart';
import '../models/account_model.dart';

class AccountRepository {
  final AppDatabase _dbProvider = AppDatabase.instance;
  final Uuid _uuid = const Uuid();

  Future<AccountModel> createAccount({
    required String bookId,
    required String name,
    required String type,
    int openingBalanceMinor = 0,
  }) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();
    final account = AccountModel(
      id: _uuid.v4(),
      bookId: bookId,
      name: name.trim(),
      type: type.toLowerCase(),
      openingBalanceMinor: openingBalanceMinor,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert(Tables.accounts, account.toMap());
    return account;
  }

  Future<List<AccountModel>> getAccounts(String bookId) async {
    final db = await _dbProvider.database;
    final result = await db.query(
      Tables.accounts,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at ASC',
    );
    return result.map((m) => AccountModel.fromMap(m)).toList();
  }

  Future<void> updateAccount(AccountModel account) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();
    final updated = account.copyWith(updatedAt: now);

    await db.update(
      Tables.accounts,
      updated.toMap(),
      where: 'id = ? AND book_id = ?',
      whereArgs: [account.id, account.bookId],
    );
  }
}
