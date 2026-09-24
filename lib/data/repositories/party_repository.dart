import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/tables.dart';
import '../models/party_model.dart';

class PartyRepository {
  final AppDatabase _dbProvider = AppDatabase.instance;
  final Uuid _uuid = const Uuid();

  Future<PartyModel> createParty({
    required String bookId,
    required String name,
    String? phone,
    String? email,
    required String type,
    String? notes,
  }) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();
    final party = PartyModel(
      id: _uuid.v4(),
      bookId: bookId,
      name: name.trim(),
      phone: phone?.trim(),
      email: email?.trim(),
      type: type.toLowerCase(),
      notes: notes?.trim(),
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert(Tables.parties, party.toMap());
    return party;
  }

  Future<List<PartyModel>> getParties(String bookId, {String? typeFilter}) async {
    final db = await _dbProvider.database;
    final whereClauses = <String>['book_id = ?', 'is_deleted = 0'];
    final whereArgs = <dynamic>[bookId];

    if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
      whereClauses.add('type = ?');
      whereArgs.add(typeFilter.toLowerCase());
    }

    final result = await db.query(
      Tables.parties,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );

    return result.map((m) => PartyModel.fromMap(m)).toList();
  }

  Future<PartyModel?> getPartyById(String id) async {
    final db = await _dbProvider.database;
    final result = await db.query(
      Tables.parties,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return PartyModel.fromMap(result.first);
  }

  Future<void> updateParty(PartyModel party) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();
    final updated = party.copyWith(updatedAt: now);

    await db.update(
      Tables.parties,
      updated.toMap(),
      where: 'id = ? AND book_id = ?',
      whereArgs: [party.id, party.bookId],
    );
  }

  Future<void> deleteParty(String partyId, String bookId) async {
    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      Tables.parties,
      {'is_deleted': 1, 'updated_at': now},
      where: 'id = ? AND book_id = ?',
      whereArgs: [partyId, bookId],
    );
  }
}
