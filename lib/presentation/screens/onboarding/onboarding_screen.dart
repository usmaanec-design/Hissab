import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hissab/core/constants/app_assets.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/services/book_appearance_service.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/decimal_calculator.dart';
import 'package:hissab/presentation/controllers/account_controller.dart';
import 'package:hissab/presentation/controllers/app_controller.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/category_controller.dart';
import 'package:hissab/presentation/controllers/party_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';
import 'package:hissab/core/services/backup_crypto_service.dart';
import 'package:hissab/presentation/controllers/cloud_backup_controller.dart';
import 'package:hissab/presentation/screens/home/main_scaffold.dart';
import 'package:hissab/presentation/widgets/bank_picker_sheet.dart';
import 'package:hissab/presentation/widgets/book_avatar_widget.dart';
import 'package:hissab/presentation/widgets/google_web_sign_in_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _nameController = TextEditingController(text: 'My Business');
  final TextEditingController _openingBalController = TextEditingController(text: '0');
  CurrencyConfig _selectedCurrency = Currencies.sar;
  int _selectedColor = BookAppearanceService.palette.first;
  String? _logoBase64;
  bool _isCreating = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _openingBalController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await BankPickerSheet.show(
      context,
      currentLogo: _logoBase64,
      bookName: _nameController.text.isNotEmpty ? _nameController.text : 'My Business',
      bookColor: _selectedColor,
    );
    if (picked != null) {
      setState(() {
        _logoBase64 = picked.isEmpty ? null : picked;
      });
    }
  }

  Future<void> _handleRestoreFromGoogle() async {
    final backupCtrl = context.read<CloudBackupController>();
    final messenger = ScaffoldMessenger.of(context);

    if (!backupCtrl.isConnected) {
      if (backupCtrl.supportsAuthenticate) {
        final signedIn = await backupCtrl.signIn();
        if (!signedIn || !mounted) {
          if (!signedIn && mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(backupCtrl.statusMessage ?? 'Google Sign-In could not complete.'),
                backgroundColor: AppColors.moneyOut,
              ),
            );
          }
          return;
        }
      } else {
        // Web: Show GIS dialog
        await showDialog(
          context: context,
          builder: (ctx) => Consumer<CloudBackupController>(
            builder: (_, ctrl, __) {
              if (ctrl.isConnected) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                });
              }
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.cloud_download_outlined, color: AppColors.primaryLight),
                    SizedBox(width: 8),
                    Text('Restore from Google'),
                  ],
                ),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sign in with your Google Account to locate your backed-up Hissab data.'),
                    SizedBox(height: 20),
                    GoogleWebSignInWidget(),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          ),
        );
        if (!backupCtrl.isConnected || !mounted) return;
      }
    }

    // Check Drive for backup
    await backupCtrl.refreshDiscoveredBackup();
    final file = backupCtrl.discoveredBackup;

    if (!mounted) return;

    if (file == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Previous Backup Found'),
          content: const Text(
            'No existing Hissab backup was found on this Google Account. Let\'s get started by creating your first Cashbook.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text('Create First Book'),
            ),
          ],
        ),
      );
      return;
    }

    final keyController = TextEditingController(text: backupCtrl.recoveryKey ?? '');
    final booksCount = file.properties['booksCount'] ?? '1+';
    final txCount = file.properties['transactionsCount'] ?? '0';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: AppColors.moneyIn),
            SizedBox(width: 8),
            Text('Cloud Backup Found!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A previous Hissab backup was found on your Google Account:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Backup Date:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(DateFormat('dd MMM yyyy').format(file.modifiedTime),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Books:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(booksCount, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Transactions:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(txCount, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter your 16-character Recovery Key:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: keyController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'XXXX-XXXX-XXXX-XXXX',
                  prefixIcon: Icon(Icons.vpn_key_rounded, size: 20),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pageController.animateToPage(
                1,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              );
            },
            child: const Text('Start Fresh'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.moneyIn,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final key = keyController.text.trim();
              if (!BackupCryptoService.isValidKeyFormat(key)) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Please enter a valid 16-character recovery key.')),
                );
                return;
              }

              final nav = Navigator.of(ctx);
              nav.pop();

              final navigator = Navigator.of(context);
              final bookCtrl = context.read<BookController>();
              final txCtrl = context.read<TransactionController>();
              final partyCtrl = context.read<PartyController>();
              final accCtrl = context.read<AccountController>();
              final catCtrl = context.read<CategoryController>();
              final appCtrl = context.read<AppController>();

              final result = await backupCtrl.restoreBackup(
                fileId: file.id,
                recoveryKey: key,
                replaceExisting: true,
              );

              if (!mounted) return;

              if (result.isSuccess) {
                await bookCtrl.loadBooks();
                final active = bookCtrl.activeBook;
                if (active != null) {
                  await appCtrl.setActiveBookId(active.id);
                  await txCtrl.loadForBook(active);
                  await partyCtrl.loadForBook(active.id);
                  await accCtrl.loadForBook(active.id);
                  await catCtrl.loadForBook(active.id);
                }

                if (!mounted) return;
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const MainScaffold()),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(result.errorMessage ?? 'Restore failed.'),
                    backgroundColor: AppColors.moneyOut,
                  ),
                );
              }
            },
            child: const Text('Restore My Data'),
          ),
        ],
      ),
    );
  }

  void _finishCreateBook() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a book name.')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final minorUnits =
          DecimalCalculator.parseToMinorUnits(_openingBalController.text, _selectedCurrency) ?? 0;

      final bookController = context.read<BookController>();
      final appController = context.read<AppController>();
      final txController = context.read<TransactionController>();
      final partyController = context.read<PartyController>();
      final accController = context.read<AccountController>();
      final catController = context.read<CategoryController>();
      final navigator = Navigator.of(context);

      final newBook = await bookController.createBook(
        name: name,
        currency: _selectedCurrency.code,
        openingBalanceMinor: minorUnits,
        openingBalanceDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        color: _selectedColor,
        logo: _logoBase64,
      );

      await appController.setActiveBookId(newBook.id);
      await txController.loadForBook(newBook);
      await partyController.loadForBook(newBook.id);
      await accController.loadForBook(newBook.id);
      await catController.loadForBook(newBook.id);

      if (mounted) {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScaffold()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomePage(isDark),
                  _buildCreateBookPage(isDark),
                ],
              ),
            ),
            _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                AppAssets.logo,
                width: 140,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  AppAssets.logoAlias,
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Welcome to Hissab',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'The smart, offline-first digital cashbook and personal accounting ledger designed for absolute precision.',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildFeatureRow(Icons.offline_bolt_rounded, '100% Offline & Private', 'Data stays on your device with persistent storage.', isDark),
          const SizedBox(height: 18),
          _buildFeatureRow(Icons.auto_stories_rounded, 'Multi-Book System', 'Manage business, personal, shop, and family ledgers separately.', isDark),
          const SizedBox(height: 18),
          _buildFeatureRow(Icons.mic_rounded, 'Smart Voice & Auto-Category', 'Dictate transactions with speech-to-text and auto-categorization.', isDark),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: AppColors.primaryLight),
            ),
            icon: const Icon(Icons.cloud_download_outlined, color: AppColors.primaryLight),
            label: const Text(
              'Restore from Google Account',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
            ),
            onPressed: _handleRestoreFromGoogle,
          ),
          const SizedBox(height: 8),
          Text(
            'Google Sign-in is optional (for Cloud Drive backup only). You can tap "Get Started" to use 100% offline.',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryLight, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateBookPage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Create Your First Book',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Set up your first cashbook. You can create more books anytime.',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Live Preview Avatar
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    BookAvatarWidget(
                      bookName: _nameController.text.isNotEmpty ? _nameController.text : 'B',
                      bookColor: _selectedColor,
                      logo: _logoBase64,
                      size: 80,
                      borderRadius: 20,
                    ),
                    InkWell(
                      onTap: _pickLogo,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(50),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _logoBase64 != null ? Icons.edit : Icons.add_a_photo,
                          size: 16,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_logoBase64 != null)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    label: const Text('Remove Logo', style: TextStyle(color: Colors.red, fontSize: 12)),
                    onPressed: () => setState(() => _logoBase64 = null),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Upload Book Logo (Optional)', style: TextStyle(fontSize: 12)),
                    onPressed: _pickLogo,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Book Name
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Book Name *',
              hintText: 'e.g. Usman Store, Personal, Home',
              prefixIcon: Icon(Icons.book_outlined),
            ),
          ),

          const SizedBox(height: 16),

          // Currency & Opening Balance
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<CurrencyConfig>(
                  value: _selectedCurrency,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    prefixIcon: Icon(Icons.monetization_on_outlined),
                  ),
                  items: Currencies.all
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text('${c.code} (${c.symbol})'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCurrency = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _openingBalController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Opening Balance',
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                    suffixText: _selectedCurrency.code,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Book Color Palette
          const Text(
            'Choose Book Color',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: BookAppearanceService.palette.map((colorInt) {
              final isSelected = _selectedColor == colorInt;
              final col = Color(colorInt);
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = colorInt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: isDark ? Colors.white : Colors.black87, width: 3)
                        : Border.all(color: Colors.transparent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: col.withAlpha(isSelected ? 90 : 30),
                        blurRadius: isSelected ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: BookAppearanceService.getContrastTextColor(col), size: 22)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page Indicators
          Row(
            children: List.generate(
              2,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 6),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppColors.primaryLight
                      : (isDark ? Colors.grey[700] : Colors.grey[300]),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // Action Button
          if (_currentPage == 0)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size(130, 46)),
              onPressed: () {
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                );
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Get Started'),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(160, 46)),
              onPressed: _isCreating ? null : _finishCreateBook,
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Book & Start'),
            ),
        ],
      ),
    );
  }
}
