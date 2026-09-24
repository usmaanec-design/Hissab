import 'package:flutter/material.dart';
import 'package:hissab/data/models/category_model.dart';
import 'package:hissab/data/repositories/category_repository.dart';

class CategoryController extends ChangeNotifier {
  final CategoryRepository _categoryRepository = CategoryRepository();

  List<CategoryModel> _incomeCategories = [];
  List<CategoryModel> _expenseCategories = [];
  bool _isLoading = false;

  List<CategoryModel> get incomeCategories => _incomeCategories;
  List<CategoryModel> get expenseCategories => _expenseCategories;
  bool get isLoading => _isLoading;

  Future<void> loadForBook(String? bookId) async {
    if (bookId == null) {
      _incomeCategories = [];
      _expenseCategories = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final all = await _categoryRepository.getCategories(bookId);
      _incomeCategories = all.where((c) => c.type == 'income').toList();
      _expenseCategories = all.where((c) => c.type == 'expense').toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CategoryModel> addCategory({
    required String bookId,
    required String name,
    required String type,
    required String icon,
    required int color,
  }) async {
    final cat = await _categoryRepository.createCategory(
      bookId: bookId,
      name: name,
      type: type,
      icon: icon,
      color: color,
    );
    await loadForBook(bookId);
    return cat;
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _categoryRepository.updateCategory(category);
    await loadForBook(category.bookId);
  }

  Future<bool> deleteCategory(String categoryId, String bookId) async {
    final success = await _categoryRepository.deleteCategory(categoryId, bookId);
    if (success) {
      await loadForBook(bookId);
    }
    return success;
  }
}
