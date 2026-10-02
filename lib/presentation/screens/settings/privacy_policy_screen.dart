import 'package:flutter/material.dart';
import 'package:hissab/core/constants/app_assets.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/localization/app_localizations.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                AppAssets.logo,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  AppAssets.logoAlias,
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(loc.translate('settings.privacy_policy')),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy Policy for Hissab',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Last updated: September 27, 2026',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Core Principle Highlight Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(isDark ? 30 : 20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF10B981).withAlpha(isDark ? 80 : 60),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 20, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Text(
                              'Core Principle: 100% Offline-First',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF0D8065),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hissab operates as an offline-first bookkeeping and cashbook application. All your cash flow entries, transactions, customer balances, and accounts are stored directly in your local device SQLite storage. Google Drive cloud backup is completely voluntary and under your direct control.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildSection(
                    isDark,
                    number: '1',
                    title: 'Information We Collect and Process',
                    content:
                        '• Financial & Transactional Data: Book names, accounts, parties/contacts, transactions, categories, and receipts you enter are stored locally in your device isolated SQLite database.\n'
                        '• Google Account Information: If you voluntarily connect your Google Account for cloud backups, we receive your Google Account stable identifier (sub), email address, and profile name. We do NOT receive your Google Account password.\n'
                        '• Client Encryption Key: When cloud backup is enabled, an authenticated 16-character recovery key is generated client-side to encrypt your data before uploading to your Google Drive.',
                  ),

                  _buildSection(
                    isDark,
                    number: '2',
                    title: 'Google User Data & Drive API Scopes',
                    content:
                        'Hissab accesses Google APIs solely to provide seamless cloud backup and cross-device restoration:\n'
                        '• Google Identity Services: Authenticates your account and binds backups exclusively to your Google Account.\n'
                        '• Google Drive Scope (drive.file): We request the narrowest possible Drive scope. Hissab ONLY accesses, creates, and restores files created specifically by Hissab in your private Google Drive. Hissab CANNOT access, view, or modify any other files or folders in your Google Drive.',
                  ),

                  _buildSection(
                    isDark,
                    number: '3',
                    title: 'Limited Use Requirements & Data Protection',
                    content:
                        'Hissab adheres to the Google API Services User Data Policy, including the Limited Use requirements:\n'
                        '• We do NOT sell, rent, lease, or monetize your personal or financial records.\n'
                        '• We do NOT use or transfer Google user data for advertising, retargeting, or marketing.\n'
                        '• We do NOT permit human reading of your financial data unless required by applicable law.\n'
                        '• Backups are encrypted with AES-256 authenticated encryption before leaving your device.',
                  ),

                  _buildSection(
                    isDark,
                    number: '4',
                    title: 'Data Retention and Account Deletion',
                    content:
                        '• Local Data: You can reset or delete any book or transaction at any time from within the app.\n'
                        '• Cloud Backups: Backups in your Google Drive can be deleted by disconnecting cloud backup or deleting the backup file directly from your Google Drive storage.',
                  ),

                  _buildSection(
                    isDark,
                    number: '5',
                    title: 'Contact Information',
                    content:
                        'If you have questions or concerns regarding this Privacy Policy or data security:\n'
                        '• WhatsApp Support: +966 50 376 3410\n'
                        '• Official Website: https://hamarahissab.web.app\n'
                        '• Developer: Muhammad Usman (Portfolio: https://usman-professional-portfolio.netlify.app/)',
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(bool isDark, {required String number, required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(isDark ? 50 : 25),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
