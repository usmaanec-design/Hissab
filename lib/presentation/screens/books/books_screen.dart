import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/services/book_appearance_service.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/core/utils/decimal_calculator.dart';
import 'package:hissab/data/models/book_model.dart';
import 'package:hissab/presentation/controllers/app_controller.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';
import 'package:hissab/presentation/controllers/party_controller.dart';
import 'package:hissab/presentation/controllers/account_controller.dart';
import 'package:hissab/presentation/controllers/category_controller.dart';
import 'package:hissab/presentation/widgets/bank_picker_sheet.dart';
import 'package:hissab/presentation/widgets/book_avatar_widget.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> with SingleTickerProviderStateMixin {
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

  void _showCreateBookDialog(BuildContext context, {BookModel? editBook}) {
    final nameController = TextEditingController(text: editBook?.name ?? '');
    final openingBalController = TextEditingController(
      text: editBook != null
          ? DecimalCalculator.formatDecimal(
              editBook.openingBalanceMinor,
              Currencies.findByCode(editBook.currency),
            )
          : '0',
    );
    CurrencyConfig selectedCurrency = editBook != null
        ? Currencies.findByCode(editBook.currency)
        : Currencies.sar;
    int selectedColor = editBook?.color ?? BookAppearanceService.palette.first;
    String? selectedLogo = editBook?.logo;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(editBook != null ? 'Edit Book' : 'Create New Book'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final picked = await BankPickerSheet.show(
                            ctx,
                            currentLogo: selectedLogo,
                            bookName: nameController.text.isNotEmpty ? nameController.text : 'B',
                            bookColor: selectedColor,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedLogo = picked.isEmpty ? null : picked;
                            });
                          }
                        },
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            BookAvatarWidget(
                              bookName: nameController.text.isNotEmpty ? nameController.text : 'B',
                              bookColor: selectedColor,
                              logo: selectedLogo,
                              size: 76,
                              borderRadius: 18,
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.edit, size: 14, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.account_balance, size: 16),
                        label: Text(
                          selectedLogo != null && selectedLogo!.isNotEmpty
                              ? 'Change Logo'
                              : 'Choose Bank / Logo',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        onPressed: () async {
                          final picked = await BankPickerSheet.show(
                            ctx,
                            currentLogo: selectedLogo,
                            bookName: nameController.text.isNotEmpty ? nameController.text : 'B',
                            bookColor: selectedColor,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedLogo = picked.isEmpty ? null : picked;
                            });
                          }
                        },
                      ),
                      if (selectedLogo != null && selectedLogo!.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 14, color: AppColors.moneyOut),
                          label: const Text('Remove Logo', style: TextStyle(color: AppColors.moneyOut, fontSize: 11)),
                          onPressed: () {
                            setDialogState(() => selectedLogo = null);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Book Name',
                    hintText: 'e.g. Main Business, Personal',
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                const Text('Book Color Theme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BookAppearanceService.palette.map((colorVal) {
                    final isSelected = selectedColor == colorVal;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() => selectedColor = colorVal);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(colorVal),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Color(colorVal).withAlpha(140),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Base Currency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<CurrencyConfig>(
                  value: selectedCurrency,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.monetization_on_outlined),
                  ),
                  items: Currencies.all.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.code} - ${c.name} (${c.symbol})'),
                      )).toList(),
                  onChanged: editBook == null
                      ? (val) {
                          if (val != null) setDialogState(() => selectedCurrency = val);
                        }
                      : null, // Base currency is immutable once book is active to protect ledger
                ),
                if (editBook == null) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: openingBalController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Opening Balance (${selectedCurrency.code})',
                      hintText: '0.00',
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                    ),
                  ),
                ],
              ],
            ),
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

                final bookController = context.read<BookController>();

                if (editBook != null) {
                  await bookController.updateBook(editBook.copyWith(
                    name: name,
                    color: selectedColor,
                    logo: selectedLogo,
                  ));
                } else {
                  final minorUnits =
                      DecimalCalculator.parseToMinorUnits(openingBalController.text, selectedCurrency) ?? 0;
                  final appCtrl = context.read<AppController>();
                  final txCtrl = context.read<TransactionController>();
                  final partyCtrl = context.read<PartyController>();
                  final accCtrl = context.read<AccountController>();
                  final catCtrl = context.read<CategoryController>();

                  final newBook = await bookController.createBook(
                    name: name,
                    currency: selectedCurrency.code,
                    openingBalanceMinor: minorUnits,
                    openingBalanceDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    color: selectedColor,
                    logo: selectedLogo,
                  );
                  await appCtrl.setActiveBookId(newBook.id);
                  await txCtrl.loadForBook(newBook);
                  await partyCtrl.loadForBook(newBook.id);
                  await accCtrl.loadForBook(newBook.id);
                  await catCtrl.loadForBook(newBook.id);
                }

                if (context.mounted) Navigator.pop(ctx);
              },
              child: Text(editBook != null ? 'Save Changes' : 'Create Book'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteBook(BuildContext context, BookModel book) {
    final nameConfirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Book Permanently?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deleting "${book.name}" will permanently erase all its transactions, categories, parties, and ledger accounts.\n\nTo confirm, type the book name below:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameConfirmController,
              decoration: InputDecoration(
                hintText: book.name,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.moneyOut,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nameConfirmController.text.trim() == book.name) {
                Navigator.pop(ctx);
                final bookCtrl = context.read<BookController>();
                final appCtrl = context.read<AppController>();
                final txCtrl = context.read<TransactionController>();

                await bookCtrl.deleteBook(book.id);
                final active = bookCtrl.activeBook;
                if (active != null) {
                  await appCtrl.setActiveBookId(active.id);
                  await txCtrl.loadForBook(active);
                }
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookController = context.watch<BookController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Books'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Active Books (${bookController.books.length})'),
            Tab(text: 'Archived (${bookController.archivedBooks.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create New Book',
            onPressed: () => _showCreateBookDialog(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Active Books
          _buildBooksList(bookController.books, isArchivedList: false, isDark: isDark),

          // Archived Books
          _buildBooksList(bookController.archivedBooks, isArchivedList: true, isDark: isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateBookDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Book'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBooksList(List<BookModel> books, {required bool isArchivedList, required bool isDark}) {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 56, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            const SizedBox(height: 12),
            Text(
              isArchivedList ? 'No archived books.' : 'No active books. Tap (+) to create one.',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final bookController = context.read<BookController>();
    final activeBookId = bookController.activeBook?.id;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final isActive = book.id == activeBookId;
        final currency = Currencies.findByCode(book.currency);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? Color(book.color)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        BookAvatarWidget(
                          bookName: book.name,
                          bookColor: book.color,
                          logo: book.logo,
                          size: 42,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              'Currency: ${book.currency}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.moneyInContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.moneyIn,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Opening Balance: ${CurrencyFormatter.format(book.openingBalanceMinor, currency)} (${book.openingBalanceDate})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isActive && !isArchivedList)
                      TextButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Set Active'),
                        onPressed: () async {
                          final appCtrl = context.read<AppController>();
                          final txCtrl = context.read<TransactionController>();
                          final partyCtrl = context.read<PartyController>();
                          final accCtrl = context.read<AccountController>();
                          final catCtrl = context.read<CategoryController>();
                          final nav = Navigator.of(context);

                          await bookController.selectBook(book.id);
                          await appCtrl.setActiveBookId(book.id);
                          await txCtrl.loadForBook(book);
                          await partyCtrl.loadForBook(book.id);
                          await accCtrl.loadForBook(book.id);
                          await catCtrl.loadForBook(book.id);
                          nav.pop();
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Rename',
                      onPressed: () => _showCreateBookDialog(context, editBook: book),
                    ),
                    IconButton(
                      icon: Icon(isArchivedList ? Icons.unarchive_outlined : Icons.archive_outlined, size: 20),
                      tooltip: isArchivedList ? 'Unarchive' : 'Archive',
                      onPressed: () async {
                        if (isArchivedList) {
                          await bookController.unarchiveBook(book.id);
                        } else {
                          await bookController.archiveBook(book.id);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.moneyOut),
                      tooltip: 'Delete Permanently',
                      onPressed: () => _confirmDeleteBook(context, book),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
