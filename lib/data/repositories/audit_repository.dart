import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/tables.dart';
import '../models/audit_model.dart';

class AuditRepository {
  final AppDatabase _dbProvider = AppDatabase.instance;
  final Uuid _uuid = const Uuid();

  Future<void> log({
    required String bookId,
    required String action,
    required String details,
  }) async {
    final db = await _dbProvider.database;
    final audit = AuditModel(
      id: _uuid.v4(),
      bookId: bookId,
      action: action,
      details: details,
      timestamp: DateTime.now().toIso8601String(),
    );
    await db.insert(Tables.auditLogs, audit.toMap());
  }

  Future<List<AuditModel>> getLogs(String bookId, {int limit = 50}) async {
    final db = await _dbProvider.database;
    final result = await db.query(
      Tables.auditLogs,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return result.map((m) => AuditModel.fromMap(m)).toList();
  }
}
