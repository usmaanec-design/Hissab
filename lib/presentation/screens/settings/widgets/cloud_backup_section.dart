import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hissab/core/services/backup_crypto_service.dart';
import 'package:hissab/core/services/cloud_backup_service.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/presentation/controllers/book_controller.dart';
import 'package:hissab/presentation/controllers/cloud_backup_controller.dart';
import 'package:hissab/presentation/controllers/transaction_controller.dart';
import 'package:hissab/presentation/widgets/google_web_sign_in_button.dart';

class CloudBackupSection extends StatelessWidget {
  const CloudBackupSection({super.key});

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '0 KB';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Never';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  void _showRecoveryKeyDialog(BuildContext context, String key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Your Recovery Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This 16-character recovery key encrypts your financial data. You will need this key along with your Google Account to restore backups on another device.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black26
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    key,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    tooltip: 'Copy Key',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: key));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recovery Key copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: AppColors.moneyIn),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Stored safely with AES-256 authenticated encryption.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
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

  void _showBackupProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Consumer<CloudBackupController>(
          builder: (_, ctrl, __) {
            final isDone = ctrl.backupStep == BackupProgressStep.completed;
            final isFail = ctrl.backupStep == BackupProgressStep.failed;

            return AlertDialog(
              title: Row(
                children: [
                  if (isDone)
                    const Icon(Icons.check_circle_rounded, color: AppColors.moneyIn)
                  else if (isFail)
                    const Icon(Icons.error_outline_rounded, color: AppColors.moneyOut)
                  else
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  const SizedBox(width: 12),
                  Text(isDone ? 'Backup Complete' : (isFail ? 'Backup Failed' : 'Cloud Backup')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ctrl.statusMessage ?? 'Processing...'),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: isDone
                        ? 1.0
                        : (isFail
                            ? 0.0
                            : (ctrl.backupStep.index / (BackupProgressStep.values.length - 2))),
                  ),
                  const SizedBox(height: 12),
                  if (isDone)
                    Text(
                      'Your data was encrypted and saved to your Google Drive.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
              actions: [
                if (isDone || isFail)
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRestoreDialog(BuildContext context) async {
    final backupCtrl = context.read<CloudBackupController>();
    final messenger = ScaffoldMessenger.of(context);

    // Refresh Drive check
    await backupCtrl.refreshDiscoveredBackup();
    final file = backupCtrl.discoveredBackup;

    if (!context.mounted) return;

    if (file == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Backup Found'),
          content: const Text(
            'No existing Hissab backup was found on this Google Account. Please create a backup first or check if you are signed in with the correct account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final keyController = TextEditingController(text: backupCtrl.recoveryKey ?? '');
    final booksCount = file.properties['booksCount'] ?? '1+';
    final txCount = file.properties['transactionsCount'] ?? '0';
    final partiesCount = file.properties['partiesCount'] ?? '0';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_download_rounded, color: AppColors.primaryLight),
            SizedBox(width: 8),
            Text('Restore Backup'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Backup Date', DateFormat('dd MMM yyyy, hh:mm a').format(file.modifiedTime)),
                    const SizedBox(height: 6),
                    _buildInfoRow('Books', booksCount),
                    const SizedBox(height: 6),
                    _buildInfoRow('Transactions', txCount),
                    const SizedBox(height: 6),
                    _buildInfoRow('Parties', partiesCount),
                    const SizedBox(height: 6),
                    _buildInfoRow('Backup Size', _formatBytes(file.sizeBytes)),
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
              const SizedBox(height: 12),
              const Text(
                'WARNING: Restoring will safely replace current local data with the cloud backup.',
                style: TextStyle(fontSize: 11, color: AppColors.moneyOut, fontWeight: FontWeight.bold),
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
              final key = keyController.text.trim();
              if (!BackupCryptoService.isValidKeyFormat(key)) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Please enter a valid 16-character recovery key.')),
                );
                return;
              }

              final nav = Navigator.of(ctx);
              nav.pop();

              final bookCtrl = context.read<BookController>();
              final txCtrl = context.read<TransactionController>();

              final result = await backupCtrl.restoreBackup(
                fileId: file.id,
                recoveryKey: key,
                replaceExisting: true,
              );

              if (result.isSuccess) {
                await bookCtrl.loadBooks();
                final active = bookCtrl.activeBook;
                if (active != null) {
                  await txCtrl.loadForBook(active);
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Successfully restored ${result.booksRestored} books and ${result.transactionsRestored} transactions!'),
                    backgroundColor: AppColors.moneyIn,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(result.errorMessage ?? 'Restore failed. Please check recovery key.'),
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _handleConnectGoogle(BuildContext context, CloudBackupController ctrl) async {
    if (ctrl.supportsAuthenticate) {
      final messenger = ScaffoldMessenger.of(context);
      final success = await ctrl.signIn();
      if (!context.mounted) return;
      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Connected to Google Account: ${ctrl.currentUser?.email}'),
            backgroundColor: AppColors.moneyIn,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(ctrl.statusMessage ?? 'Google Sign-In could not complete.'),
            backgroundColor: AppColors.moneyOut,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      _showWebSignInDialog(context, ctrl);
    }
  }

  void _showWebSignInDialog(BuildContext context, CloudBackupController ctrl) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer<CloudBackupController>(
          builder: (_, backupController, __) {
            // Auto close dialog upon successful sign-in
            if (backupController.isConnected) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(ctx)) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Connected to Google Account: ${backupController.currentUser?.email}'),
                      backgroundColor: AppColors.moneyIn,
                    ),
                  );
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.account_circle_outlined, color: AppColors.primaryLight),
                  SizedBox(width: 8),
                  Text('Sign in with Google'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Sign in using your Google Account to protect and sync your Hissab records across devices.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // The official Google Identity Services rendered button on Web
                  const GoogleWebSignInWidget(),
                  const SizedBox(height: 16),
                  const Text(
                    'Your data stays end-to-end encrypted with your private recovery key.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CloudBackupController>(
      builder: (context, ctrl, _) {
        final user = ctrl.currentUser;
        final isConnected = ctrl.isConnected;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '☁ Google Cloud Backup & Cross-Device Restore',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),

            // Card 1: Google Account Connection
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: isConnected && user != null
                  ? Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.1),
                              child: Text(
                                (user.displayName != null && user.displayName!.isNotEmpty)
                                    ? user.displayName![0].toUpperCase()
                                    : 'G',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          user.displayName ?? 'Google User',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.moneyIn.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          '● Connected',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.moneyIn,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.email,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Account ID: ${user.id.substring(0, user.id.length > 8 ? 8 : user.id.length)}...',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.switch_account_outlined, size: 16),
                              label: const Text('Change Account'),
                              onPressed: () => ctrl.changeAccount(),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(foregroundColor: AppColors.moneyOut),
                              icon: const Icon(Icons.link_off_rounded, size: 16),
                              label: const Text('Disconnect'),
                              onPressed: () => ctrl.signOut(),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.cloud_outlined, color: AppColors.primaryLight, size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Protect your accounting data against app uninstall or phone change.',
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: ctrl.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              ctrl.isLoading ? 'Connecting...' : 'Connect Google Account',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: ctrl.isLoading ? null : () => _handleConnectGoogle(context, ctrl),
                          ),
                        ),
                      ],
                    ),
            ),

            if (isConnected) ...[
              const SizedBox(height: 12),

              // Card 2: Backup Details & Recovery Key
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud_done_outlined, color: AppColors.moneyIn),
                      title: const Text('Last Cloud Backup'),
                      subtitle: Text(_formatDateTime(ctrl.lastBackupTime)),
                      trailing: Text(
                        _formatBytes(ctrl.lastBackupSizeBytes),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.sync_rounded, color: AppColors.primaryLight),
                      title: const Text('Auto Backup'),
                      subtitle: Text(
                        ctrl.isPendingOffline
                            ? 'Pending (will backup once connected)'
                            : 'Debounced background backup on data changes',
                        style: TextStyle(
                          color: ctrl.isPendingOffline ? Colors.orange : null,
                        ),
                      ),
                      value: ctrl.isAutoBackupEnabled,
                      onChanged: (val) => ctrl.toggleAutoBackup(val),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.vpn_key_rounded, color: AppColors.accent),
                      title: const Text('Hissab Recovery Key'),
                      subtitle: const Text('Tap to view and save your cross-device restore key'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        if (ctrl.recoveryKey != null) {
                          _showRecoveryKeyDialog(context, ctrl.recoveryKey!);
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Actions: Backup Now and Restore Backup
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.backup_rounded),
                      label: const Text('Backup Now', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        _showBackupProgressDialog(context);
                        await ctrl.backupNow();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('Restore Cloud'),
                      onPressed: () => _showRestoreDialog(context),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
