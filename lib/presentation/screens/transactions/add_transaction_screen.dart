import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/date_formatter.dart';
import 'package:hissab/core/utils/decimal_calculator.dart';
import 'package:hissab/data/models/category_model.dart';
import 'package:hissab/data/models/party_model.dart';
import 'package:hissab/data/models/account_model.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/presentation/controllers/account_controller.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/category_controller.dart';
import 'package:hissab/presentation/controllers/party_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';
import 'package:hissab/presentation/widgets/amount_keypad.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionType initialType; // income or expense
  final TransactionModel? editTransaction; // if editing

  const AddTransactionScreen({
    super.key,
    required this.initialType,
    this.editTransaction,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late TransactionType _type;
  String _amountInput = '';
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  CategoryModel? _selectedCategory;
  PartyModel? _selectedParty;
  AccountModel? _selectedAccount;
  String _selectedPaymentMethod = 'Cash';

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _refController = TextEditingController();

  final List<String> _paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Card',
    'Mada',
    'STC Pay',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.editTransaction?.type ?? widget.initialType;

    if (widget.editTransaction != null) {
      final tx = widget.editTransaction!;
      final bookController = context.read<BookController>();
      final curr = bookController.activeCurrency;
      _amountInput = DecimalCalculator.formatDecimal(tx.amountMinorUnit, curr);
      _selectedDate = DateFormatter.parseIsoDate(tx.date);
      final timeParts = tx.time.split(':');
      _selectedTime = TimeOfDay(
        hour: int.tryParse(timeParts[0]) ?? 12,
        minute: int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0,
      );
      _descController.text = tx.description ?? '';
      _refController.text = tx.referenceNumber ?? '';
      _selectedPaymentMethod = tx.paymentMethod ?? 'Cash';
    } else {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _initDropdowns());
  }

  void _initDropdowns() {
    final catController = context.read<CategoryController>();
    final partyController = context.read<PartyController>();
    final accController = context.read<AccountController>();

    final cats = _type.isMoneyIn
        ? catController.incomeCategories
        : catController.expenseCategories;

    if (widget.editTransaction != null) {
      if (widget.editTransaction!.categoryId != null) {
        final found = cats.where((c) => c.id == widget.editTransaction!.categoryId);
        if (found.isNotEmpty) _selectedCategory = found.first;
      }
      if (widget.editTransaction!.partyId != null) {
        final found = partyController.parties.where((p) => p.id == widget.editTransaction!.partyId);
        if (found.isNotEmpty) _selectedParty = found.first;
      }
      if (widget.editTransaction!.accountId != null) {
        final found = accController.accounts.where((a) => a.id == widget.editTransaction!.accountId);
        if (found.isNotEmpty) _selectedAccount = found.first;
      }
    } else {
      if (cats.isNotEmpty) _selectedCategory = cats.first;
      if (accController.accounts.isNotEmpty) _selectedAccount = accController.accounts.first;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _descController.dispose();
    _refController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _submit() async {
    final bookController = context.read<BookController>();
    final book = bookController.activeBook;
    if (book == null) return;

    final currency = bookController.activeCurrency;
    final minorUnits = DecimalCalculator.parseToMinorUnits(_amountInput, currency);

    if (minorUnits == null || minorUnits <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount greater than 0.'),
          backgroundColor: AppColors.moneyOut,
        ),
      );
      return;
    }

    final timeString =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final now = DateTime.now().toIso8601String();

    final tx = TransactionModel(
      id: widget.editTransaction?.id ?? const Uuid().v4(),
      bookId: book.id,
      accountId: _selectedAccount?.id,
      partyId: _selectedParty?.id,
      categoryId: _selectedCategory?.id,
      type: _type,
      amountMinorUnit: minorUnits,
      date: DateFormatter.toIsoDate(_selectedDate),
      time: timeString,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      paymentMethod: _selectedPaymentMethod,
      referenceNumber: _refController.text.trim().isEmpty ? null : _refController.text.trim(),
      createdAt: widget.editTransaction?.createdAt ?? now,
      updatedAt: now,
    );

    final txController = context.read<TransactionController>();

    if (widget.editTransaction != null) {
      await txController.updateTransaction(tx, book);
    } else {
      await txController.addTransaction(tx, book);
    }

    // Refresh parties and accounts if used
    if (mounted) {
      context.read<PartyController>().loadForBook(book.id);
      context.read<AccountController>().loadForBook(book.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookController = context.watch<BookController>();
    final catController = context.watch<CategoryController>();
    final partyController = context.watch<PartyController>();
    final accController = context.watch<AccountController>();

    final currency = bookController.activeCurrency;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = _type.isMoneyIn;

    final categories = isIncome
        ? catController.incomeCategories
        : catController.expenseCategories;

    final themeColor = isIncome ? AppColors.moneyIn : AppColors.moneyOut;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editTransaction != null
              ? 'Edit Transaction'
              : (isIncome ? 'Money In (+)' : 'Money Out (-)'),
          style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text(
              'SAVE',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Amount Display Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              color: isDark ? AppColors.darkCard : Colors.white,
              child: Column(
                children: [
                  Text(
                    '${isIncome ? "+" : "-"} ${currency.code} ${_amountInput.isEmpty ? "0.00" : _amountInput}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: themeColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Currency: ${currency.name} (${currency.code})',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Numeric Keypad for 3-second rapid entry
            AmountKeypad(
              currentAmountText: _amountInput,
              currency: currency,
              onAmountChanged: (val) => setState(() => _amountInput = val),
            ),

            const Divider(),

            // Form Fields
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Selector (Chips)
                  const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((cat) {
                        final isSelected = _selectedCategory?.id == cat.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat.name),
                            selected: isSelected,
                            selectedColor: themeColor.withAlpha(40),
                            labelStyle: TextStyle(
                              color: isSelected ? themeColor : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedCategory = cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Party Selector
                  const Text('Party / Contact', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<PartyModel?>(
                    value: _selectedParty,
                    decoration: const InputDecoration(
                      hintText: 'Select contact (optional)',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<PartyModel?>(
                        value: null,
                        child: Text('No Party (General)'),
                      ),
                      ...partyController.parties.map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('${p.name} (${p.type})'),
                          )),
                    ],
                    onChanged: (val) => setState(() => _selectedParty = val),
                  ),

                  const SizedBox(height: 16),

                  // Account Selector & Payment Method in Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<AccountModel?>(
                              value: _selectedAccount,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 20),
                              ),
                              items: accController.accounts.map((a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                                  )).toList(),
                              onChanged: (val) => setState(() => _selectedAccount = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _selectedPaymentMethod,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.payment_outlined, size: 20),
                              ),
                              items: _paymentMethods.map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m),
                                  )).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedPaymentMethod = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Date & Time Selectors
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              prefixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Time',
                              prefixIcon: Icon(Icons.access_time, size: 18),
                            ),
                            child: Text(_selectedTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Description / Note
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Description / Note',
                      hintText: 'e.g. Office supplies, Customer payment',
                      prefixIcon: Icon(Icons.notes_outlined, size: 20),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Reference Number / Receipt #
                  TextField(
                    controller: _refController,
                    decoration: const InputDecoration(
                      labelText: 'Reference / Invoice #',
                      hintText: 'e.g. INV-2026-001',
                      prefixIcon: Icon(Icons.tag, size: 20),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Save Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _submit,
                    child: Text(
                      widget.editTransaction != null ? 'Update Transaction' : 'Save Transaction',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
