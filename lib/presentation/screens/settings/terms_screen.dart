import 'package:flutter/material.dart';
import 'package:hissab/core/constants/app_assets.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/core/localization/app_localizations.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
            Text(loc.translate('settings.terms_conditions')),
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
                    'Terms & Conditions',
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

                  // Notice Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(isDark ? 30 : 15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.blue.withAlpha(isDark ? 80 : 50),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Important Notice',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hissab is an offline-first bookkeeping and ledger calculation tool designed for personal and small business record-keeping. Hissab is not a chartered accounting firm, bank, or tax advisory service.',
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
                    title: 'Acceptance of Terms',
                    content:
                        'By downloading, installing, accessing, or using Hissab, you agree to be bound by these Terms and Conditions. If you disagree with any part of these terms, please discontinue using the application.',
                  ),

                  _buildSection(
                    isDark,
                    number: '2',
                    title: 'Description of Service & Local Storage',
                    content:
                        'Hissab provides digital cashbook records, multi-book management, party ledger tracking, and report generation. The app functions with an offline-first architecture; records are stored locally in SQLite on your device.',
                  ),

                  _buildSection(
                    isDark,
                    number: '3',
                    title: 'User Responsibilities & Data Accuracy',
                    content:
                        '• You are solely responsible for the accuracy and validity of any financial entries, figures, receipts, and customer balances entered.\n'
                        '• You are responsible for maintaining your device security and creating backups.\n'
                        '• When using Google Drive Cloud Backup, keep your 16-character recovery key in a safe place. Encrypted backups cannot be decrypted without this key.',
                  ),

                  _buildSection(
                    isDark,
                    number: '4',
                    title: 'Cloud Backup & Google Drive Integration',
                    content:
                        '• Google Account connection is voluntary.\n'
                        '• Backups are stored in your private Google Drive under the drive.file scope. We do not host your accounting files on our own servers.\n'
                        '• We are not liable for data loss caused by deleted Google Drive files or lost recovery keys.',
                  ),

                  _buildSection(
                    isDark,
                    number: '5',
                    title: 'Disclaimer of Warranties',
                    content:
                        'The application is provided "AS IS" and "AS AVAILABLE" without warranties of any kind. Hissab does not provide formal tax or audit advice. Always consult a certified financial professional for statutory tax filings.',
                  ),

                  _buildSection(
                    isDark,
                    number: '6',
                    title: 'Limitation of Liability',
                    content:
                        'To the maximum extent permitted by applicable law, Muhammad Usman (the developer) shall not be liable for any indirect, incidental, or consequential damages resulting from the use or inability to use this service.',
                  ),

                  _buildSection(
                    isDark,
                    number: '7',
                    title: 'Contact',
                    content:
                        'For legal inquiries or questions regarding these terms:\n'
                        '• WhatsApp Support: +966 50 376 3410\n'
                        '• Website: https://hamarahissab.web.app',
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
