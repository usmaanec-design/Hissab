import 'package:flutter/material.dart';
import 'package:hissab/data/models/party_model.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/data/repositories/party_repository.dart';
import 'package:hissab/data/repositories/transaction_repository.dart';
import 'package:hissab/domain/accounting/accounting_engine.dart';

class PartyController extends ChangeNotifier {
  final PartyRepository _partyRepository = PartyRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();

  List<PartyModel> _parties = [];
  Map<String, PartyBalanceSummary> _partySummaries = {};
  int _totalReceivableMinor = 0;
  int _totalPayableMinor = 0;
  bool _isLoading = false;

  List<PartyModel> get parties => _parties;
  Map<String, PartyBalanceSummary> get partySummaries => _partySummaries;
  int get totalReceivableMinor => _totalReceivableMinor;
  int get totalPayableMinor => _totalPayableMinor;
  bool get isLoading => _isLoading;

  Future<void> loadForBook(String? bookId, {String? typeFilter}) async {
    if (bookId == null) {
      _parties = [];
      _partySummaries = {};
      _totalReceivableMinor = 0;
      _totalPayableMinor = 0;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _parties = await _partyRepository.getParties(bookId, typeFilter: typeFilter);
      final allTx = await _transactionRepository.getAllActiveTransactions(bookId);

      int totalRec = 0;
      int totalPay = 0;
      final Map<String, PartyBalanceSummary> summaries = {};

      for (final party in _parties) {
        final summary = AccountingEngine.calculatePartySummary(
          partyId: party.id,
          partyType: party.type,
          transactions: allTx,
        );
        summaries[party.id] = summary;

        if (party.type.toLowerCase() == 'customer') {
          if (summary.outstandingMinor > 0) {
            totalRec += summary.outstandingMinor;
          }
        } else {
          // Supplier or others
          if (summary.outstandingMinor > 0) {
            totalPay += summary.outstandingMinor;
          }
        }
      }

      _partySummaries = summaries;
      _totalReceivableMinor = totalRec;
      _totalPayableMinor = totalPay;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PartyModel> addParty({
    required String bookId,
    required String name,
    String? phone,
    String? email,
    required String type,
    String? notes,
  }) async {
    final party = await _partyRepository.createParty(
      bookId: bookId,
      name: name,
      phone: phone,
      email: email,
      type: type,
      notes: notes,
    );
    await loadForBook(bookId);
    return party;
  }

  Future<void> updateParty(PartyModel party) async {
    await _partyRepository.updateParty(party);
    await loadForBook(party.bookId);
  }

  Future<void> deleteParty(String partyId, String bookId) async {
    await _partyRepository.deleteParty(partyId, bookId);
    await loadForBook(bookId);
  }

  Future<List<TransactionModel>> getPartyTransactions(String partyId, String bookId) async {
    return _transactionRepository.getTransactions(
      bookId: bookId,
      filter: TransactionFilter(partyId: partyId),
      limit: 100,
    );
  }
}
