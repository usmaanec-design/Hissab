import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'backup_crypto_service.dart';
import 'backup_export_service.dart';
import 'backup_restore_service.dart';
import 'cloud_auth_service.dart';
import 'cloud_drive_service.dart';

enum BackupProgressStep {
  idle,
  preparing,
  exporting,
  encrypting,
  uploading,
  verifying,
  completed,
  failed,
}

enum RestoreProgressStep {
  idle,
  downloading,
  decrypting,
  validating,
  restoring,
  completed,
  failed,
}

class CloudBackupResult {
  final bool isSuccess;
  final String? errorMessage;
  final DateTime? backupTime;
  final int? sizeBytes;
  final Map<String, dynamic>? summary;

  const CloudBackupResult({
    required this.isSuccess,
    this.errorMessage,
    this.backupTime,
    this.sizeBytes,
    this.summary,
  });
}

class CloudRestoreResult {
  final bool isSuccess;
  final String? errorMessage;
  final int booksRestored;
  final int transactionsRestored;

  const CloudRestoreResult({
    required this.isSuccess,
    this.errorMessage,
    this.booksRestored = 0,
    this.transactionsRestored = 0,
  });
}

class CloudBackupService {
  static const String keyPrefRecoveryKey = 'hissab_cloud_recovery_key';
  static const String keyPrefAutoBackup = 'hissab_cloud_auto_backup';
  static const String keyPrefLastBackupTime = 'hissab_cloud_last_backup_time';
  static const String keyPrefLastBackupSize = 'hissab_cloud_last_backup_size';
  static const String keyPrefPendingOffline = 'hissab_cloud_pending_offline';

  final ICloudAuthService authService;
  final ICloudDriveService driveService;
  final BackupExportService exportService;
  final BackupRestoreService restoreService;

  Timer? _debounceTimer;
  bool _isBackingUp = false;

  CloudBackupService({
    required this.authService,
    required this.driveService,
    BackupExportService? exportService,
    BackupRestoreService? restoreService,
  })  : exportService = exportService ?? BackupExportService(),
        restoreService = restoreService ?? BackupRestoreService();

  /// Retrieves existing recovery key from storage, or generates and saves a new one
  Future<String> getOrCreateRecoveryKey() async {
    final prefs = await SharedPreferences.getInstance();
    String? key = prefs.getString(keyPrefRecoveryKey);
    if (key == null || !BackupCryptoService.isValidKeyFormat(key)) {
      key = BackupCryptoService.generateRecoveryKey();
      await prefs.setString(keyPrefRecoveryKey, key);
    }
    return key;
  }

  /// Sets or imports a recovery key (e.g. when entering it on a new device)
  Future<void> saveRecoveryKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyPrefRecoveryKey, BackupCryptoService.formatKey(key));
  }

  /// Checks if auto-backup is enabled
  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyPrefAutoBackup) ?? false;
  }

  /// Toggles auto-backup setting
  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyPrefAutoBackup, enabled);
  }

  /// Checks if there is a pending offline backup
  Future<bool> isPendingOffline() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyPrefPendingOffline) ?? false;
  }

  Future<void> setPendingOffline(bool pending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyPrefPendingOffline, pending);
  }

  /// Schedules a debounced auto-backup after data changes (coalescing multiple rapid edits)
  void scheduleDebouncedAutoBackup({
    Duration delay = const Duration(seconds: 15),
    Database? overrideDb,
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () async {
      final autoEnabled = await isAutoBackupEnabled();
      if (!autoEnabled) return;

      final user = await authService.getCurrentUser();
      if (user == null) return;

      try {
        await performBackup(overrideDb: overrideDb);
      } catch (e) {
        debugPrint('Auto-backup background failure (queued as pending): $e');
        await setPendingOffline(true);
      }
    });
  }

  /// Executes full production backup pipeline:
  /// SQLite -> JSON Export -> Validate -> Compress -> Encrypt -> Upload -> Verify
  Future<CloudBackupResult> performBackup({
    void Function(BackupProgressStep step)? onProgress,
    Database? overrideDb,
  }) async {
    if (_isBackingUp) {
      return const CloudBackupResult(
        isSuccess: false,
        errorMessage: 'Backup already in progress.',
      );
    }

    _isBackingUp = true;
    onProgress?.call(BackupProgressStep.preparing);

    try {
      // 1. Check Google Auth
      final user = await authService.getCurrentUser();
      if (user == null) {
        onProgress?.call(BackupProgressStep.failed);
        return const CloudBackupResult(
          isSuccess: false,
          errorMessage: 'Please sign in to your Google Account first.',
        );
      }

      final recoveryKey = await getOrCreateRecoveryKey();

      // 2. Export SQLite database to logical JSON
      onProgress?.call(BackupProgressStep.exporting);
      final rawData = await exportService.createLogicalBackupData(
        googleAccountId: user.id,
        overrideDb: overrideDb,
      );
      final rawJson = jsonEncode(rawData);

      // 3. Authenticated Encryption with AES-256-CBC, PBKDF2 & HMAC
      onProgress?.call(BackupProgressStep.encrypting);
      final encryptedContent = BackupCryptoService.encryptBackup(
        rawJson: rawJson,
        recoveryKey: recoveryKey,
        googleUserId: user.id,
      );

      // 4. Upload to Google Drive (Hissab/Hissab_Backup.hsb)
      onProgress?.call(BackupProgressStep.uploading);
      final summary = rawData['summary'] as Map<String, dynamic>;
      final properties = <String, String>{
        'booksCount': '${summary['booksCount'] ?? 0}',
        'transactionsCount': '${summary['transactionsCount'] ?? 0}',
        'partiesCount': '${summary['partiesCount'] ?? 0}',
        'accountsCount': '${summary['accountsCount'] ?? 0}',
        'createdAt': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
        'googleUserId': user.id,
      };

      final uploadedFile = await driveService.uploadBackup(
        encryptedContent: encryptedContent,
        properties: properties,
      );

      // 5. Verification
      onProgress?.call(BackupProgressStep.verifying);
      if (uploadedFile.sizeBytes <= 0) {
        throw Exception('Drive verification failed: Uploaded file size is 0 bytes.');
      }

      // 6. Save metadata to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyPrefLastBackupTime, uploadedFile.modifiedTime.toIso8601String());
      await prefs.setInt(keyPrefLastBackupSize, uploadedFile.sizeBytes);
      await setPendingOffline(false);

      onProgress?.call(BackupProgressStep.completed);
      return CloudBackupResult(
        isSuccess: true,
        backupTime: uploadedFile.modifiedTime,
        sizeBytes: uploadedFile.sizeBytes,
        summary: summary,
      );
    } catch (e) {
      debugPrint('Cloud backup error: $e');
      await setPendingOffline(true);
      onProgress?.call(BackupProgressStep.failed);
      return CloudBackupResult(
        isSuccess: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      _isBackingUp = false;
    }
  }

  /// Discovers existing Hissab backup on Google Drive
  Future<BackupDriveFile?> checkCloudBackup() async {
    try {
      final user = await authService.getCurrentUser();
      if (user == null) return null;
      return await driveService.findLatestBackup();
    } catch (e) {
      debugPrint('Error checking cloud backup: $e');
      return null;
    }
  }

  /// Restores from Google Drive backup:
  /// Download -> Decrypt -> Validate -> Integrity Check -> Atomic Commit
  Future<CloudRestoreResult> performRestore({
    required String fileId,
    required String recoveryKey,
    required bool replaceExisting,
    void Function(RestoreProgressStep step)? onProgress,
    Database? overrideDb,
  }) async {
    onProgress?.call(RestoreProgressStep.downloading);

    try {
      // 1. Verify user identity
      final user = await authService.getCurrentUser();
      if (user == null) {
        onProgress?.call(RestoreProgressStep.failed);
        return const CloudRestoreResult(
          isSuccess: false,
          errorMessage: 'Please sign in to Google to restore backup.',
        );
      }

      // 2. Download encrypted payload from Google Drive
      final encryptedEnvelope = await driveService.downloadBackup(fileId);

      // 3. Decrypt & Authenticate
      onProgress?.call(RestoreProgressStep.decrypting);
      final rawJson = BackupCryptoService.decryptBackup(
        encryptedEnvelopeJson: encryptedEnvelope,
        recoveryKey: recoveryKey,
        googleUserId: user.id,
      );

      // 4. Validate Schema & Accounting Integrity
      onProgress?.call(RestoreProgressStep.validating);
      final data = jsonDecode(rawJson) as Map<String, dynamic>;
      final validation = restoreService.validateBackupData(
        data,
        activeGoogleAccountId: user.id,
      );

      if (!validation.isValid) {
        onProgress?.call(RestoreProgressStep.failed);
        return CloudRestoreResult(
          isSuccess: false,
          errorMessage: validation.errorMessage ?? 'Backup validation failed.',
        );
      }

      // 5. Atomic SQLite restore with rollback protection
      onProgress?.call(RestoreProgressStep.restoring);
      final result = await restoreService.executeAtomicRestore(
        data,
        replaceExisting: replaceExisting,
        overrideDb: overrideDb,
      );

      if (!result.isSuccess) {
        onProgress?.call(RestoreProgressStep.failed);
        return CloudRestoreResult(
          isSuccess: false,
          errorMessage: result.errorMessage ?? 'Database restore failed.',
        );
      }

      // Save valid recovery key
      await saveRecoveryKey(recoveryKey);

      onProgress?.call(RestoreProgressStep.completed);
      return CloudRestoreResult(
        isSuccess: true,
        booksRestored: result.booksRestored,
        transactionsRestored: result.transactionsRestored,
      );
    } catch (e) {
      debugPrint('Cloud restore error: $e');
      onProgress?.call(RestoreProgressStep.failed);
      return CloudRestoreResult(
        isSuccess: false,
        errorMessage: e.toString().replaceFirst('Exception: ', '').replaceFirst('BackupCryptoException: ', ''),
      );
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}
