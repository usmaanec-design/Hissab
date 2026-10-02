import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hissab/core/constants/app_assets.dart';
import 'package:hissab/core/constants/currencies.dart';
import 'package:hissab/core/localization/app_localizations.dart';
import 'package:hissab/core/security/security_service.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/utils/currency_formatter.dart';
import 'package:hissab/presentation/controllers/app_controller.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';
import 'audit_logs_screen.dart';
import 'contact_us_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'widgets/cloud_backup_section.dart';

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

  @override
  Widget build(BuildContext context) {
    final appController = context.watch<AppController>();
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Top Center Prominent Logo & App Identity Header
          Center(
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.14),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      AppAssets.logo,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        AppAssets.logoAlias,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Hissab',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'CashBook & Financial Ledger',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Preferences Section
          const Text('Preferences', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.language_outlined, color: AppColors.primaryLight),
                title: Text(loc.translate('settings.language')),
                subtitle: Text(appController.locale.languageCode == 'ar'
                    ? 'العربية (Arabic - RTL)'
                    : (appController.locale.languageCode == 'ur' ? 'اردو (Urdu - RTL)' : 'English (LTR)')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguageDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.palette_outlined, color: AppColors.primaryLight),
                title: Text(loc.translate('settings.theme')),
                subtitle: Text(appController.themeMode == ThemeMode.dark
                    ? 'Dark Mode'
                    : (appController.themeMode == ThemeMode.light ? 'Light Mode' : 'System Default')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // 2. Account Section (Google Cloud Backup & Restore, Security, Audit)
          Text(loc.translate('settings.account_section'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),

          // Google Cloud Backup Section (Maintained)
          const CloudBackupSection(),

          const SizedBox(height: 12),

          _buildSettingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.security_outlined, color: AppColors.accent),
                title: Text(loc.translate('settings.security')),
                subtitle: Text(appController.isPinProtected ? 'Activated (Secured)' : 'Disabled'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPinDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.verified_outlined, color: AppColors.moneyIn),
                title: Text(loc.translate('settings.reconcile')),
                subtitle: const Text('Verify 100% calculation integrity against transactions journal'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _runReconciliation(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history_outlined, color: AppColors.primaryLight),
                title: Text(loc.translate('settings.audit_log')),
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

          const SizedBox(height: 22),

          // 3. Information Section (Privacy Policy, Terms, Contact Us, Website)
          Text(loc.translate('settings.info_section'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF10B981)),
                title: Text(loc.translate('settings.privacy_policy')),
                subtitle: const Text('Data protection, offline storage & Drive scopes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: Color(0xFF3B82F6)),
                title: Text(loc.translate('settings.terms_conditions')),
                subtitle: const Text('Terms of service, guidelines & user agreement'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.support_agent_rounded, color: Color(0xFF25D366)),
                title: Text(loc.translate('settings.contact_us')),
                subtitle: const Text('Chat on WhatsApp (+966 50 376 3410) & Support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language_rounded, color: AppColors.primaryLight),
                title: Text(loc.translate('settings.hissab_website')),
                subtitle: const Text('https://hamarahissab.web.app'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () async {
                  final uri = Uri.parse('https://hamarahissab.web.app/');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 22),

          // 4. About Section
          Text(loc.translate('settings.about_section'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    AppAssets.logo,
                    width: 42,
                    height: 42,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      AppAssets.logoAlias,
                      width: 42,
                      height: 42,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                title: const Text('Hissab CashBook & Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Version 1.0.0 • Offline-First Deterministic Accounting\nDeveloper: Muhammad Usman'),
              ),
            ],
          ),

          const SizedBox(height: 30),
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
