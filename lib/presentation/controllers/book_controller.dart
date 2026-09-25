import 'package:flutter/material.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/data/models/book_model.dart';
import 'package:hissab/data/repositories/book_repository.dart';

class BookController extends ChangeNotifier {
  final BookRepository _bookRepository = BookRepository();

  List<BookModel> _books = [];
  List<BookModel> _archivedBooks = [];
  BookModel? _activeBook;
  bool _isLoading = false;

  List<BookModel> get books => _books;
  List<BookModel> get archivedBooks => _archivedBooks;
  BookModel? get activeBook => _activeBook;
  bool get isLoading => _isLoading;

  CurrencyConfig get activeCurrency {
    if (_activeBook == null) return Currencies.sar;
    return Currencies.findByCode(_activeBook!.currency);
  }

  Future<void> loadBooks({String? preferredActiveBookId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final all = await _bookRepository.getBooks(includeArchived: true);
      _books = all.where((b) => !b.isArchived).toList();
      _archivedBooks = all.where((b) => b.isArchived).toList();

      if (_books.isNotEmpty) {
        if (preferredActiveBookId != null) {
          _activeBook = _books.firstWhere(
            (b) => b.id == preferredActiveBookId,
            orElse: () => _books.first,
          );
        } else if (_activeBook != null) {
          _activeBook = _books.firstWhere(
            (b) => b.id == _activeBook!.id,
            orElse: () => _books.first,
          );
        } else {
          _activeBook = _books.first;
        }
      } else {
        _activeBook = null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BookModel> createBook({
    required String name,
    required String currency,
    required int openingBalanceMinor,
    required String openingBalanceDate,
    int? color,
    String? logo,
  }) async {
    final newBook = await _bookRepository.createBook(
      name: name,
      currency: currency,
      openingBalanceMinor: openingBalanceMinor,
      openingBalanceDate: openingBalanceDate,
      color: color,
      logo: logo,
    );

    await loadBooks(preferredActiveBookId: newBook.id);
    return newBook;
  }

  Future<void> selectBook(String bookId) async {
    final found = _books.firstWhere((b) => b.id == bookId, orElse: () => _books.first);
    _activeBook = found;
    notifyListeners();
  }

  Future<void> updateBook(BookModel book) async {
    await _bookRepository.updateBook(book);
    await loadBooks(preferredActiveBookId: book.id);
  }

  Future<void> archiveBook(String bookId) async {
    await _bookRepository.setArchived(bookId, true);
    await loadBooks();
  }

  Future<void> unarchiveBook(String bookId) async {
    await _bookRepository.setArchived(bookId, false);
    await loadBooks(preferredActiveBookId: bookId);
  }

  Future<void> deleteBook(String bookId) async {
    await _bookRepository.deleteBookPermanently(bookId);
    await loadBooks();
  }
}
