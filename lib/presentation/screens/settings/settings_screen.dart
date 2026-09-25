import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:hissab/core/constants/app_assets.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/security/security_service.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/data/repositories/backup_repository.dart';
import 'package:hissab/presentation/controllers/app_controller.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';
import 'audit_logs_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showLanguageDialog(BuildContext context) {
    final appController = context.read<AppController>();
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Language'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              appController.setLocale('en');
              Navigator.pop(ctx);
            },
            child: const Text('English (LTR)'),
          ),
          SimpleDialogOption(
            onPressed: () {
              appController.setLocale('ar');
              Navigator.pop(ctx);
            },
            child: const Text('العربية (Arabic - RTL)'),
          ),
          SimpleDialogOption(
            onPressed: () {
              appController.setLocale('ur');
              Navigator.pop(ctx);
            },
            child: const Text('اردو (Urdu - RTL)'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final appController = context.read<AppController>();
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Appearance'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              appController.setThemeMode(ThemeMode.light);
              Navigator.pop(ctx);
            },
            child: const Text('Light Mode'),
          ),
          SimpleDialogOption(
            onPressed: () {
              appController.setThemeMode(ThemeMode.dark);
              Navigator.pop(ctx);
            },
            child: const Text('Dark Mode (Obsidian Slate)'),
          ),
          SimpleDialogOption(
            onPressed: () {
              appController.setThemeMode(ThemeMode.system);
              Navigator.pop(ctx);
            },
            child: const Text('System Default'),
          ),
        ],
      ),
    );
  }

  void _showPinDialog(BuildContext context) async {
    final hasPin = await SecurityService.hasPinSet();
    final pinController = TextEditingController();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hasPin ? 'Change or Disable PIN' : 'Set 4-Digit Security PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a 4-digit numerical PIN to protect your cashbook financial records.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: '4-Digit PIN',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          if (hasPin)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.moneyOut),
              onPressed: () async {
                final appCtrl = context.read<AppController>();
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);
                await SecurityService.disablePin();
                await appCtrl.refreshSecurityState();
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('PIN Lock disabled.')),
                );
              },
              child: const Text('Disable PIN'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.length == 4 && int.tryParse(pin) != null) {
                final appCtrl = context.read<AppController>();
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);
                await SecurityService.setPin(pin);
                await appCtrl.refreshSecurityState();
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('PIN successfully saved and activated.'),
                    backgroundColor: AppColors.moneyIn,
                  ),
                );
              }
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
  }

  void _runReconciliation(BuildContext context) async {
    final book = context.read<BookController>().activeBook;
    if (book == null) return;

    final result = await context.read<TransactionController>().reconcile(book);
    final currency = Currencies.findByCode(book.currency);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.isHealthy ? Icons.verified_rounded : Icons.warning_amber_rounded,
              color: result.isHealthy ? AppColors.moneyIn : AppColors.moneyOut,
            ),
            const SizedBox(width: 8),
            Text(result.isHealthy ? 'Audit Passed' : 'Discrepancy Detected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.message),
            const SizedBox(height: 12),
            Text('Ledger Calculated: ${CurrencyFormatter.format(result.ledgerCalculatedBalanceMinor, currency)}'),
            Text('Displayed Balance: ${CurrencyFormatter.format(result.displayedBalanceMinor, currency)}'),
            if (!result.isHealthy)
              Text(
                'Discrepancy: ${result.discrepancyMinor} minor units',
                style: const TextStyle(color: AppColors.moneyOut, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _exportDatabaseJson(BuildContext context) async {
    final repo = BackupRepository();
    final json = await repo.exportCompleteJsonBackup();

    await SharePlus.instance.share(
      ShareParams(
        text: json,
        subject: 'Hissab Database JSON Backup - ${DateTime.now().toIso8601String()}',
      ),
    );
  }

  void _restoreDatabaseJson(BuildContext context) {
    final jsonInputController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Database Backup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your exported Hissab JSON backup here. WARNING: Restoring will overwrite existing records with the backup data.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: jsonInputController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Paste JSON content here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
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
              final text = jsonInputController.text.trim();
              if (text.isEmpty) return;

              final repo = BackupRepository();
              final bookCtrl = context.read<BookController>();
              final txCtrl = context.read<TransactionController>();
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(ctx);

              final success = await repo.restoreCompleteJsonBackup(text);
              nav.pop();

              if (success) {
                await bookCtrl.loadBooks();
                final active = bookCtrl.activeBook;
                if (active != null) {
                  await txCtrl.loadForBook(active);
                }
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Database restored successfully!'),
                    backgroundColor: AppColors.moneyIn,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Invalid backup JSON format or corrupted file.'),
                    backgroundColor: AppColors.moneyOut,
                  ),
                );
              }
            },
            child: const Text('Confirm Restore'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appController = context.watch<AppController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preferences Section
          const Text('Preferences', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.language_outlined, color: AppColors.primaryLight),
                title: const Text('Language & Localization'),
                subtitle: Text(appController.locale.languageCode == 'ar'
                    ? 'العربية (Arabic - RTL)'
                    : (appController.locale.languageCode == 'ur' ? 'اردو (Urdu - RTL)' : 'English (LTR)')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguageDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.palette_outlined, color: AppColors.primaryLight),
                title: const Text('Appearance & Theme'),
                subtitle: Text(appController.themeMode == ThemeMode.dark
                    ? 'Dark Mode'
                    : (appController.themeMode == ThemeMode.light ? 'Light Mode' : 'System Default')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Security & Audit Section
          const Text('Security & Integrity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.security_outlined, color: AppColors.accent),
                title: const Text('App Security PIN Lock'),
                subtitle: Text(appController.isPinProtected ? 'Activated (Secured)' : 'Disabled'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPinDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.verified_outlined, color: AppColors.moneyIn),
                title: const Text('Audit Ledger & Reconciliation'),
                subtitle: const Text('Verify 100% calculation integrity against transactions journal'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _runReconciliation(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history_outlined, color: AppColors.primaryLight),
                title: const Text('Audit Trail & Event Log'),
                subtitle: const Text('View history of all creates, updates, and deletes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuditLogsScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Backup & Restore Section
          const Text('Backup & Data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.primaryLight),
                title: const Text('Backup Full Database (JSON)'),
                subtitle: const Text('Export complete structured database with all books & parties'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportDatabaseJson(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore_outlined, color: AppColors.moneyOut),
                title: const Text('Restore Database from Backup'),
                subtitle: const Text('Import and restore all books, transactions, and settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _restoreDatabaseJson(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // About Section
          const Text('About', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    AppAssets.logo,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      AppAssets.logoAlias,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                title: const Text('Hissab CashBook & Ledger'),
                subtitle: const Text('Version 1.0.0 • Offline-First & Deterministic Accounting'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(children: children),
    );
  }
}
