import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:hissab/core/services/contact_service.dart';
import 'package:hissab/core/services/speech_session_controller.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/date_formatter.dart';
import 'package:hissab/core/utils/decimal_calculator.dart';
import 'package:hissab/data/models/account_model.dart';
import 'package:hissab/data/models/category_model.dart';
import 'package:hissab/data/models/party_model.dart';
import 'package:hissab/data/models/transaction_model.dart';
import 'package:hissab/domain/services/category_detection_service.dart';
import 'package:hissab/domain/services/description_suggestion_service.dart';
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

  final DescriptionSuggestionService _descService = DescriptionSuggestionService();
  final CategoryDetectionService _categoryDetectionService = CategoryDetectionService();
  final ContactService _contactService = ContactService();
  final SpeechSessionController _speechSession = SpeechSessionController();

  List<String> _descriptionSuggestions = [];
  List<ContactItem> _recentContacts = [];
  CategoryDetectionResult? _autoDetectionResult;
  bool _userManuallyChangedCategory = false;
  bool _isSpeechUpdatingText = false;

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
      _userManuallyChangedCategory = true;
    } else {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }

    _descController.addListener(_onDescriptionChanged);
    _speechSession.addListener(_onSpeechSessionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDropdowns();
      _loadSuggestionsAndContacts();
    });
  }

  @override
  void dispose() {
    _descController.removeListener(_onDescriptionChanged);
    _speechSession.removeListener(_onSpeechSessionChanged);
    _descController.dispose();
    _refController.dispose();
    _speechSession.dispose();
    super.dispose();
  }

  void _onSpeechSessionChanged() {
    if (mounted) setState(() {});
  }

  void _onDescriptionChanged() {
    if (!_isSpeechUpdatingText) {
      _speechSession.notifyUserManualEdit(_descController.text);
    }
    if (!_userManuallyChangedCategory) {
      _autoDetectCategory();
    }
  }

  Future<void> _loadSuggestionsAndContacts() async {
    final book = context.read<BookController>().activeBook;
    if (book == null) return;

    final txTypeStr = _type.isMoneyIn ? 'INCOME' : 'EXPENSE';
    final suggestions = await _descService.getSuggestions(
      bookId: book.id,
      txType: txTypeStr,
    );
    final contacts = await _contactService.getRecentContacts(book.id);

    if (mounted) {
      setState(() {
        _descriptionSuggestions = suggestions;
        _recentContacts = contacts;
      });
    }
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
      // Default to cash account
      final cashAcc = accController.accounts.where((a) => a.type == 'cash');
      if (cashAcc.isNotEmpty) {
        _selectedAccount = cashAcc.first;
      } else if (accController.accounts.isNotEmpty) {
        _selectedAccount = accController.accounts.first;
      }

      _autoDetectCategory();
    }
    setState(() {});
  }

  Future<void> _autoDetectCategory() async {
    final text = _descController.text.trim();
    if (text.isEmpty) return;

    final book = context.read<BookController>().activeBook;
    final catController = context.read<CategoryController>();
    if (book == null) return;

    final availableCats = _type.isMoneyIn
        ? catController.incomeCategories
        : catController.expenseCategories;

    final result = await _categoryDetectionService.detectCategory(
      bookId: book.id,
      description: text,
      availableCategories: availableCats,
    );

    if (result != null && mounted) {
      setState(() {
        _selectedCategory = result.category;
        _autoDetectionResult = result;
      });
    }
  }

  // Live Speech Methods with Progressive Typing & Manual Edit Protection
  Future<void> _startLiveVoice() async {
    await _speechSession.startSession(
      context: context,
      initialText: _descController.text,
      onTranscriptUpdate: (fullTranscript) {
        if (!mounted) return;
        _isSpeechUpdatingText = true;
        _descController.text = fullTranscript;
        _descController.selection = TextSelection.fromPosition(
          TextPosition(offset: fullTranscript.length),
        );
        _isSpeechUpdatingText = false;
        _autoDetectCategory();
      },
    );
  }

  Future<void> _pauseLiveVoice() async {
    await _speechSession.pauseSession();
  }

  Future<void> _resumeLiveVoice() async {
    await _speechSession.resumeSession(
      context: context,
      currentFieldText: _descController.text,
      onTranscriptUpdate: (fullTranscript) {
        if (!mounted) return;
        _isSpeechUpdatingText = true;
        _descController.text = fullTranscript;
        _descController.selection = TextSelection.fromPosition(
          TextPosition(offset: fullTranscript.length),
        );
        _isSpeechUpdatingText = false;
        _autoDetectCategory();
      },
    );
  }

  Future<void> _stopLiveVoice() async {
    await _speechSession.stopSession(
      onFinal: (finalTranscript) {
        if (!mounted) return;
        _isSpeechUpdatingText = true;
        _descController.text = finalTranscript;
        _descController.selection = TextSelection.fromPosition(
          TextPosition(offset: finalTranscript.length),
        );
        _isSpeechUpdatingText = false;
        _autoDetectCategory();
      },
    );
  }

  // Party Selection & Inline Creation
  Future<void> _pickContactFromDevice() async {
    final book = context.read<BookController>().activeBook;
    if (book == null) return;

    final picked = await _contactService.pickContact(context, book.id);
    if (picked != null) {
      _applyContact(picked.name, picked.phone);
    }
  }

  void _applyContact(String name, [String? phone]) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final partyController = context.read<PartyController>();
    final book = context.read<BookController>().activeBook;
    if (book == null) return;

    // Check if party exists in partyController
    final existing = partyController.parties.where(
      (p) => p.name.trim().toLowerCase() == cleanName.toLowerCase(),
    );

    PartyModel partyToSelect;
    if (existing.isNotEmpty) {
      partyToSelect = existing.first;
    } else {
      // Create party automatically without hardcoding supplier or altering party name
      partyToSelect = await partyController.addParty(
        bookId: book.id,
        name: cleanName,
        phone: phone,
        type: 'other',
      );
    }

    if (mounted) {
      setState(() => _selectedParty = partyToSelect);
    }
  }

  void _showPartyPickerSheet(BuildContext context) {
    final partyController = context.read<PartyController>();
    String filter = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final parties = partyController.parties.where((p) {
              if (filter.isEmpty) return true;
              return p.name.toLowerCase().contains(filter.toLowerCase()) ||
                  (p.phone?.toLowerCase().contains(filter.toLowerCase()) ?? false);
            }).toList();

            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.72,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(80),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Party / Contact',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Actions Row: [+ Add New Party] and [Device Contacts]
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.person_add_alt_1, size: 18),
                            label: const Text('+ Add Party', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showAddNewPartySheet(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.contacts_outlined, size: 18),
                            label: const Text('Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _pickContactFromDevice();
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Search field
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by party name or phone...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: filter.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setModalState(() => filter = ''),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) => setModalState(() => filter = val.trim()),
                    ),

                    const SizedBox(height: 12),

                    // "No Party (General)" Option
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.withAlpha(40),
                        child: const Icon(Icons.person_off_outlined, color: Colors.grey, size: 20),
                      ),
                      title: const Text('No Party (General)', style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: _selectedParty == null ? const Icon(Icons.check, color: AppColors.primaryLight) : null,
                      onTap: () {
                        setState(() => _selectedParty = null);
                        Navigator.pop(ctx);
                      },
                    ),
                    const Divider(height: 1),

                    // Filtered Parties List
                    Expanded(
                      child: parties.isEmpty
                          ? Center(
                              child: Text(
                                filter.isEmpty ? 'No parties created yet.' : 'No party matching "$filter"',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: parties.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final p = parties[i];
                                final isSelected = _selectedParty?.id == p.id;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primaryLight.withAlpha(30),
                                    child: Text(
                                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                                    ),
                                  ),
                                  title: Text(
                                    p.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? AppColors.primaryLight : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: p.phone != null && p.phone!.isNotEmpty
                                      ? Text(p.phone!, style: const TextStyle(fontSize: 12))
                                      : null,
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: AppColors.primaryLight)
                                      : null,
                                  onTap: () {
                                    setState(() => _selectedParty = p);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddNewPartySheet(BuildContext context) {
    final book = context.read<BookController>().activeBook;
    if (book == null) return;

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedCategoryType = _type.isMoneyIn ? 'customer' : 'supplier';

    final partyTypes = [
      'customer',
      'supplier',
      'employee',
      'vendor',
      'other',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add New Party',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: nameCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Party / Person Name *',
                          hintText: 'e.g. Ahmed Ali',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number (optional)',
                          hintText: 'e.g. +966 50 123 4567',
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: selectedCategoryType,
                        decoration: const InputDecoration(
                          labelText: 'Category / Role',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: partyTypes.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(t[0].toUpperCase() + t.substring(1)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => selectedCategoryType = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          prefixIcon: Icon(Icons.note_alt_outlined),
                        ),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;

                          final partyController = context.read<PartyController>();
                          final newParty = await partyController.addParty(
                            bookId: book.id,
                            name: name,
                            phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                            type: selectedCategoryType,
                            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          );

                          if (mounted) {
                            setState(() => _selectedParty = newParty);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                          }
                        },
                        child: const Text('Save Party', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
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
    final descriptionText = _descController.text.trim().isEmpty ? null : _descController.text.trim();

    // Default to first category if still null
    CategoryModel? finalCategory = _selectedCategory;
    if (finalCategory == null) {
      final catController = context.read<CategoryController>();
      final cats = _type.isMoneyIn ? catController.incomeCategories : catController.expenseCategories;
      if (cats.isNotEmpty) finalCategory = cats.first;
    }

    final tx = TransactionModel(
      id: widget.editTransaction?.id ?? const Uuid().v4(),
      bookId: book.id,
      accountId: _selectedAccount?.id,
      partyId: _selectedParty?.id,
      categoryId: finalCategory?.id,
      type: _type,
      amountMinorUnit: minorUnits,
      date: DateFormatter.toIsoDate(_selectedDate),
      time: timeString,
      description: descriptionText,
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

    // Save description to history & learn category
    if (descriptionText != null && descriptionText.isNotEmpty) {
      final txTypeStr = _type.isMoneyIn ? 'INCOME' : 'EXPENSE';
      await _descService.recordDescription(
        bookId: book.id,
        description: descriptionText,
        txType: txTypeStr,
      );

      if (finalCategory != null && _userManuallyChangedCategory) {
        await _categoryDetectionService.learnCorrection(
          bookId: book.id,
          description: descriptionText,
          selectedCategory: finalCategory,
        );
      }
    }

    // Record contact usage if party was selected
    if (_selectedParty != null) {
      await _contactService.recordContactUsage(
        bookId: book.id,
        name: _selectedParty!.name,
        phone: _selectedParty!.phone,
      );
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              // Hero Amount Display Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                color: isDark ? AppColors.darkCard : Colors.white,
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${isIncome ? "+" : "-"} ${currency.code} ${_amountInput.isEmpty ? "0.00" : _amountInput}',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: themeColor,
                          letterSpacing: -0.5,
                        ),
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
                    // Description / Note with Live Microphone & Language Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Description / Note',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        // Language Selector Dropdown
                        PopupMenuButton<SpeechLanguageMode>(
                          initialValue: _speechSession.languageMode,
                          tooltip: 'Select Voice Language',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.language, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  _speechSession.languageMode.displayName,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                          onSelected: (mode) => _speechSession.setLanguageMode(mode),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: SpeechLanguageMode.auto,
                              child: Text('Auto (Smart Detect)'),
                            ),
                            const PopupMenuItem(
                              value: SpeechLanguageMode.urdu,
                              child: Text('اردو (Urdu)'),
                            ),
                            const PopupMenuItem(
                              value: SpeechLanguageMode.english,
                              child: Text('English (US)'),
                            ),
                            const PopupMenuItem(
                              value: SpeechLanguageMode.arabic,
                              child: Text('العربية (Arabic)'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Description TextField with Live Typing & Microphone Button
                    TextField(
                      controller: _descController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'e.g. Paid petrol for vehicle, Sales payment',
                        prefixIcon: const Icon(Icons.notes_outlined, size: 20),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: IconButton(
                            tooltip: _speechSession.isListening
                                ? 'Stop Listening'
                                : 'Live Voice Dictation (Speak Now)',
                            icon: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _speechSession.isListening
                                    ? Colors.red.withAlpha(40)
                                    : Colors.blue.withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _speechSession.isListening ? Icons.mic : Icons.mic_none_rounded,
                                color: _speechSession.isListening ? Colors.red : Colors.blue,
                                size: 22,
                              ),
                            ),
                            onPressed: () {
                              if (_speechSession.isListening) {
                                _stopLiveVoice();
                              } else if (_speechSession.isPaused) {
                                _resumeLiveVoice();
                              } else {
                                _startLiveVoice();
                              }
                            },
                          ),
                        ),
                      ),
                    ),

                    // Live Recording Active Banner & Controls (Progressive Speaking UX)
                    if (_speechSession.isListening || _speechSession.isPaused) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _speechSession.isListening ? Colors.red.withAlpha(15) : Colors.amber.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _speechSession.isListening ? Colors.red.withAlpha(80) : Colors.amber.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _speechSession.isListening ? Colors.red : Colors.amber,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _speechSession.isListening
                                    ? 'Listening live (${_speechSession.languageMode.displayName})... Speak now'
                                    : 'Voice paused. Tap resume to continue.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _speechSession.isListening ? Colors.red : Colors.amber[800],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_speechSession.isListening)
                              IconButton(
                                icon: const Icon(Icons.pause, size: 20, color: Colors.grey),
                                tooltip: 'Pause Voice',
                                onPressed: _pauseLiveVoice,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.play_arrow, size: 20, color: Colors.blue),
                                tooltip: 'Resume Voice',
                                onPressed: _resumeLiveVoice,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                              ),
                            const SizedBox(width: 4),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(40, 28),
                              ),
                              onPressed: _stopLiveVoice,
                              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Smart Description Suggestions
                    if (_descriptionSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Icon(Icons.history, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            ..._descriptionSuggestions.map((s) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    label: Text(s, style: const TextStyle(fontSize: 11)),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    onPressed: () {
                                      setState(() {
                                        _descController.text = s;
                                        _descController.selection = TextSelection.fromPosition(
                                          TextPosition(offset: s.length),
                                        );
                                      });
                                      _autoDetectCategory();
                                    },
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Category Section (Auto-Detected Badge + Manual Selector)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Category',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        if (_selectedCategory != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: themeColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _userManuallyChangedCategory ? Icons.edit : Icons.auto_awesome,
                                  size: 12,
                                  color: themeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _userManuallyChangedCategory
                                      ? 'Custom'
                                      : 'Auto: ${_autoDetectionResult?.confidence ?? "Matched"}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: themeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
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
                                if (val) {
                                  setState(() {
                                    _selectedCategory = cat;
                                    _userManuallyChangedCategory = true;
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Party / Contact Section (Inline Contact Selector & Add Party Modal)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Party / Contact',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.person_add_alt, size: 15),
                              label: const Text('+ Add', style: TextStyle(fontSize: 12)),
                              onPressed: () => _showAddNewPartySheet(context),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.contacts_outlined, size: 15),
                              label: const Text('Contacts', style: TextStyle(fontSize: 12)),
                              onPressed: _pickContactFromDevice,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Tappable Party Field: Opens bottom sheet picker
                    InkWell(
                      onTap: () => _showPartyPickerSheet(context),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          hintText: 'Select or search party / contact',
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          suffixIcon: _selectedParty != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() => _selectedParty = null),
                                )
                              : const Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          _selectedParty != null ? _selectedParty!.name : 'No Party (General)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedParty != null ? FontWeight.bold : FontWeight.normal,
                            color: _selectedParty != null
                                ? (isDark ? Colors.white : Colors.black87)
                                : Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    // Recent Contacts Chips
                    if (_recentContacts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Icon(Icons.recent_actors_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            ..._recentContacts.map((c) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    avatar: CircleAvatar(
                                      backgroundColor: Colors.blue.withAlpha(40),
                                      child: Text(
                                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                      ),
                                    ),
                                    label: Text(c.name, style: const TextStyle(fontSize: 11)),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    onPressed: () => _applyContact(c.name, c.phone),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Account Selector & Payment Method
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

                    // Reference Number / Receipt #
                    TextField(
                      controller: _refController,
                      decoration: const InputDecoration(
                        labelText: 'Reference / Invoice #',
                        hintText: 'e.g. INV-2026-001',
                        prefixIcon: Icon(Icons.tag, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Sticky Keyboard-Aware Save Button
      // Stays visible above the keyboard and above Android system navigation bar
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(context).bottom > 0 ? 8 : 16,
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _submit,
            child: Text(
              widget.editTransaction != null ? 'Update Transaction' : 'Save Transaction',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
