import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/currencies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/decimal_calculator.dart';
import '../../data/models/book_model.dart';
import '../../data/models/party_model.dart';
import '../../data/models/transaction_model.dart';
import '../controllers/party_controller.dart';
import '../controllers/transaction_controller.dart';

/// Modal dialog for recording quick Udhar Notes (Udhar Lia / Udhar Dia)
/// with automatic current date and time diary tracking.
class AddNoteDialog extends StatefulWidget {
  final BookModel book;

  const AddNoteDialog({super.key, required this.book});

  static Future<bool?> show(BuildContext context, {required BookModel book}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddNoteDialog(book: book),
    );
  }

  @override
  State<AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<AddNoteDialog> {
  // 'given' = Maine Udhar Diya (Out / Lent)
  // 'taken' = Maine Udhar Liya (In / Borrowed)
  String _udharType = 'given';

  final TextEditingController _personNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  late DateTime _selectedDateTime;
  PartyModel? _selectedExistingParty;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = DateTime.now();
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _saveNote() async {
    final name = _personNameController.text.trim();
    final amountStr = _amountController.text.trim();
    final noteText = _noteController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter person/party name (Naam darj karein)')),
      );
      return;
    }

    final currency = Currencies.findByCode(widget.book.currency);
    final minorUnits = DecimalCalculator.parseToMinorUnits(amountStr, currency);

    if (minorUnits == null || minorUnits <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount (Raqam darj karein)')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final partyCtrl = context.read<PartyController>();
      final txCtrl = context.read<TransactionController>();

      // 1. Resolve or create party
      String partyId;
      if (_selectedExistingParty != null && _selectedExistingParty!.name.toLowerCase() == name.toLowerCase()) {
        partyId = _selectedExistingParty!.id;
      } else {
        // Find by name in current book parties
        final existingMatch = partyCtrl.parties.where(
          (p) => p.name.trim().toLowerCase() == name.toLowerCase(),
        );

        if (existingMatch.isNotEmpty) {
          partyId = existingMatch.first.id;
        } else {
          // Create new party
          final newParty = await partyCtrl.addParty(
            bookId: widget.book.id,
            name: name,
            type: _udharType == 'given' ? 'customer' : 'supplier',
            notes: 'Auto-created via Udhar Diary',
          );
          partyId = newParty.id;
        }
      }

      // 2. Create transaction record
      final isGiven = _udharType == 'given'; // Diya = Expense / Money Out
      final dateIso = DateFormat('yyyy-MM-dd').format(_selectedDateTime);
      final timeIso = DateFormat('HH:mm').format(_selectedDateTime);

      final fullDescription = noteText.isNotEmpty
          ? 'Udhar Note (${isGiven ? "Maine Diya" : "Maine Liya"}): $noteText'
          : 'Udhar Note (${isGiven ? "Maine Diya" : "Maine Liya"})';

      final tx = TransactionModel(
        id: const Uuid().v4(),
        bookId: widget.book.id,
        partyId: partyId,
        type: isGiven ? TransactionType.expense : TransactionType.income,
        amountMinorUnit: minorUnits,
        date: dateIso,
        time: timeIso,
        description: fullDescription,
        paymentMethod: 'Cash',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      await txCtrl.addTransaction(tx, widget.book);
      await partyCtrl.loadForBook(widget.book.id);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Udhar Note recorded: $name (${isGiven ? "Diya" : "Liya"} ${currency.symbol} $amountStr)',
                  ),
                ),
              ],
            ),
            backgroundColor: isGiven ? AppColors.moneyOut : AppColors.moneyIn,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: $e'), backgroundColor: AppColors.moneyOut),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = Currencies.findByCode(widget.book.currency);
    final partyCtrl = context.watch<PartyController>();
    final mediaQuery = MediaQuery.of(context);

    final isGiven = _udharType == 'given';
    final primaryThemeColor = isGiven ? AppColors.moneyOut : AppColors.moneyIn;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: mediaQuery.viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryThemeColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.edit_note_rounded, color: primaryThemeColor, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Udhar Note / ادھار ڈائری',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Book: ${widget.book.name} (${currency.code})',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Type Toggle: Udhar Diya vs Udhar Liya
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _udharType = 'given'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isGiven ? AppColors.moneyOut : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_upward_rounded, size: 18, color: isGiven ? Colors.white : Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Udhar Diya (Maine Diya)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isGiven ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _udharType = 'taken'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !isGiven ? AppColors.moneyIn : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_downward_rounded, size: 18, color: !isGiven ? Colors.white : Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Udhar Liya (Maine Liya)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: !isGiven ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Auto Current Date / Time Banner
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: primaryThemeColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryThemeColor.withAlpha(40)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_available_rounded, size: 18, color: primaryThemeColor),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Auto Date & Time (Diary Record)',
                              style: TextStyle(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              DateFormat('EEEE, dd MMM yyyy • hh:mm a').format(_selectedDateTime),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(Icons.edit_calendar_rounded, size: 18, color: primaryThemeColor),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Person / Party Name
            const Text(
              'Person / Party Name (Kiska Naam Hai?):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Autocomplete<PartyModel>(
              displayStringForOption: (p) => p.name,
              optionsBuilder: (textVal) {
                if (textVal.text.isEmpty) return const [];
                return partyCtrl.parties.where(
                  (p) => p.name.toLowerCase().contains(textVal.text.toLowerCase()),
                );
              },
              onSelected: (p) {
                setState(() {
                  _selectedExistingParty = p;
                  _personNameController.text = p.name;
                });
              },
              fieldViewBuilder: (ctx, ctrl, focusNode, onSubmitted) {
                // Keep controllers in sync
                ctrl.addListener(() {
                  _personNameController.text = ctrl.text;
                });
                return TextField(
                  controller: ctrl,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'e.g. Ali Bhai, Rashid Khan, Milk Store',
                    prefixIcon: const Icon(Icons.person_outline),
                    suffixIcon: ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              ctrl.clear();
                              setState(() => _selectedExistingParty = null);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            // Amount Field
            const Text(
              'Amount (Raqam):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryThemeColor,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixIcon: Icon(Icons.payments_outlined, color: primaryThemeColor),
                suffixText: currency.code,
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Note Description (Tafseel / Waja)
            const Text(
              'Note / Details (Tafseel / Waja / Saman):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Dukan ka samaan, Gari ka kharcha, Raqam wapsi...',
                prefixIcon: const Icon(Icons.description_outlined),
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryThemeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _isSaving ? null : _saveNote,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSaving
                      ? 'Saving Note...'
                      : 'Save Note to Diary (${isGiven ? "Udhar Diya" : "Udhar Liya"})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
