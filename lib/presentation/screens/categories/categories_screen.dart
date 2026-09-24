import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/data/models/category_model.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/category_controller.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddCategoryDialog(BuildContext context, {CategoryModel? editCategory}) {
    final nameController = TextEditingController(text: editCategory?.name ?? '');
    String type = editCategory?.type ?? (_tabController.index == 0 ? 'income' : 'expense');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(editCategory != null ? 'Edit Category' : 'Create Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Consulting, Groceries',
                ),
              ),
              const SizedBox(height: 16),
              if (editCategory == null)
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Category Type'),
                  items: const [
                    DropdownMenuItem(value: 'income', child: Text('Income (Money In)')),
                    DropdownMenuItem(value: 'expense', child: Text('Expense (Money Out)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => type = val);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final book = context.read<BookController>().activeBook;
                if (book != null) {
                  final catController = context.read<CategoryController>();
                  if (editCategory != null) {
                    await catController.updateCategory(editCategory.copyWith(name: name));
                  } else {
                    await catController.addCategory(
                      bookId: book.id,
                      name: name,
                      type: type,
                      icon: type == 'income' ? 'attach_money' : 'shopping_bag',
                      color: type == 'income' ? 0xFF059669 : 0xFFE11D48,
                    );
                  }
                }
                if (context.mounted) Navigator.pop(ctx);
              },
              child: Text(editCategory != null ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, CategoryModel cat) async {
    final book = context.read<BookController>().activeBook;
    if (book == null) return;

    final catController = context.read<CategoryController>();
    final inUse = await catController.deleteCategory(cat.id, book.id);

    if (!inUse && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete category: It has active transactions assigned to it.'),
          backgroundColor: AppColors.moneyOut,
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category deleted.'),
          backgroundColor: AppColors.moneyIn,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final catController = context.watch<CategoryController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Income (${catController.incomeCategories.length})'),
            Tab(text: 'Expense (${catController.expenseCategories.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Category',
            onPressed: () => _showAddCategoryDialog(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(catController.incomeCategories, isDark),
          _buildCategoryList(catController.expenseCategories, isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Category'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCategoryList(List<CategoryModel> categories, bool isDark) {
    if (categories.isEmpty) {
      return Center(
        child: Text(
          'No categories found.',
          style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isIncome = cat.type == 'income';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(cat.color).withAlpha(25),
              child: Icon(
                isIncome ? Icons.attach_money : Icons.shopping_bag_outlined,
                color: Color(cat.color),
                size: 20,
              ),
            ),
            title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(cat.isDefault ? 'Default System Category' : 'Custom Category'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _showAddCategoryDialog(context, editCategory: cat),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.moneyOut),
                  onPressed: () => _confirmDeleteCategory(context, cat),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
