import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hissab/core/services/cloud_auth_service.dart';
import 'package:hissab/core/services/cloud_backup_service.dart';
import 'package:hissab/core/services/cloud_drive_service.dart';

class CloudBackupController extends ChangeNotifier {
  final CloudBackupService _backupService;

  CloudUser? _currentUser;
  bool _isLoading = false;
  BackupProgressStep _backupStep = BackupProgressStep.idle;
  RestoreProgressStep _restoreStep = RestoreProgressStep.idle;
  String? _statusMessage;
  DateTime? _lastBackupTime;
  int? _lastBackupSizeBytes;
  bool _autoBackupEnabled = false;
  bool _isPendingOffline = false;
  String? _recoveryKey;
  BackupDriveFile? _discoveredBackup;

  CloudBackupController({CloudBackupService? backupService})
      : _backupService = backupService ??
            CloudBackupService(
              authService: GoogleAuthService(),
              driveService: GoogleDriveService(
                clientProvider: () => GoogleAuthService().getAuthenticatedClient(),
              ),
            );

  CloudBackupService get backupService => _backupService;
  CloudUser? get currentUser => _currentUser;
  bool get isConnected => _currentUser != null;
  bool get isLoading => _isLoading;
  BackupProgressStep get backupStep => _backupStep;
  RestoreProgressStep get restoreStep => _restoreStep;
  String? get statusMessage => _statusMessage;
  DateTime? get lastBackupTime => _lastBackupTime;
  int? get lastBackupSizeBytes => _lastBackupSizeBytes;
  bool get isAutoBackupEnabled => _autoBackupEnabled;
  bool get isPendingOffline => _isPendingOffline;
  String? get recoveryKey => _recoveryKey;
  BackupDriveFile? get discoveredBackup => _discoveredBackup;
  bool get supportsAuthenticate => _backupService.authService.supportsAuthenticate;

  StreamSubscription<CloudUser?>? _authSubscription;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _autoBackupEnabled = await _backupService.isAutoBackupEnabled();
      _isPendingOffline = await _backupService.isPendingOffline();

      final savedTime = prefs.getString(CloudBackupService.keyPrefLastBackupTime);
      if (savedTime != null) {
        _lastBackupTime = DateTime.tryParse(savedTime);
      }
      _lastBackupSizeBytes = prefs.getInt(CloudBackupService.keyPrefLastBackupSize);

      _recoveryKey = await _backupService.getOrCreateRecoveryKey();

      _authSubscription ??= _backupService.authService.authStateChanges.listen((user) async {
        _currentUser = user;
        if (user != null) {
          _statusMessage = 'Connected as ${user.email}';
          await refreshDiscoveredBackup();
          if (_isPendingOffline && _autoBackupEnabled) {
            backupNow();
          }
        } else {
          _discoveredBackup = null;
        }
        notifyListeners();
      });

      // Silent sign-in
      _currentUser = await _backupService.authService.getCurrentUser();
      if (_currentUser != null) {
        await refreshDiscoveredBackup();
      }
    } catch (e) {
      debugPrint('CloudBackupController initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn() async {
    _isLoading = true;
    _statusMessage = 'Connecting to Google Account...';
    notifyListeners();

    try {
      final user = await _backupService.authService.signIn();
      _currentUser = user;
      if (user != null) {
        _statusMessage = 'Connected as ${user.email}';
        await refreshDiscoveredBackup();
        // If pending backup was queued while offline, trigger backup now
        if (_isPendingOffline && _autoBackupEnabled) {
          backupNow();
        }
        return true;
      } else {
        _statusMessage = 'Google Sign-In was cancelled.';
        return false;
      }
    } catch (e) {
      debugPrint('CloudBackupController signIn error: $e');
      final msg = e.toString();
      if (msg.contains('canceled') ||
          msg.contains('cancelled') ||
          msg.contains('USER_CANCELED') ||
          msg.contains('sign_in_canceled')) {
        _statusMessage = 'Sign-In cancelled.';
      } else if (msg.contains('10') || msg.contains('DEVELOPER_ERROR')) {
        _statusMessage = 'Configuration Error (10): Android OAuth Client ID / SHA-1 must be added in Google Cloud Console.';
      } else {
        _statusMessage = 'Google Sign-In failed: $e';
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _backupService.authService.signOut();
      _currentUser = null;
      _discoveredBackup = null;
      _statusMessage = 'Google Account disconnected.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changeAccount() async {
    await signOut();
    await signIn();
  }

  Future<void> refreshDiscoveredBackup() async {
    if (_currentUser == null) return;
    try {
      _discoveredBackup = await _backupService.checkCloudBackup();
      notifyListeners();
    } catch (e) {
      debugPrint('Error searching Google Drive: $e');
    }
  }

  Future<void> toggleAutoBackup(bool enabled) async {
    _autoBackupEnabled = enabled;
    await _backupService.setAutoBackupEnabled(enabled);
    notifyListeners();
  }

  /// Triggers non-blocking manual backup with progress tracking
  Future<CloudBackupResult> backupNow() async {
    _isLoading = true;
    _backupStep = BackupProgressStep.preparing;
    _statusMessage = 'Preparing backup...';
    notifyListeners();

    try {
      final result = await _backupService.performBackup(
        onProgress: (step) {
          _backupStep = step;
          switch (step) {
            case BackupProgressStep.preparing:
              _statusMessage = 'Preparing backup...';
              break;
            case BackupProgressStep.exporting:
              _statusMessage = 'Exporting data...';
              break;
            case BackupProgressStep.encrypting:
              _statusMessage = 'Encrypting financial records...';
              break;
            case BackupProgressStep.uploading:
              _statusMessage = 'Uploading to Google Drive...';
              break;
            case BackupProgressStep.verifying:
              _statusMessage = 'Verifying cloud backup...';
              break;
            case BackupProgressStep.completed:
              _statusMessage = 'Backup complete!';
              break;
            case BackupProgressStep.failed:
              _statusMessage = 'Backup failed.';
              break;
            default:
              break;
          }
          notifyListeners();
        },
      );

      if (result.isSuccess) {
        _lastBackupTime = result.backupTime;
        _lastBackupSizeBytes = result.sizeBytes;
        _isPendingOffline = false;
        _statusMessage = 'Backup complete!';
        await refreshDiscoveredBackup();
      } else {
        _isPendingOffline = true;
        _statusMessage = result.errorMessage ?? 'Backup failed.';
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Triggers non-blocking restore
  Future<CloudRestoreResult> restoreBackup({
    required String fileId,
    required String recoveryKey,
    required bool replaceExisting,
  }) async {
    _isLoading = true;
    _restoreStep = RestoreProgressStep.downloading;
    _statusMessage = 'Downloading backup from Google Drive...';
    notifyListeners();

    try {
      final result = await _backupService.performRestore(
        fileId: fileId,
        recoveryKey: recoveryKey,
        replaceExisting: replaceExisting,
        onProgress: (step) {
          _restoreStep = step;
          switch (step) {
            case RestoreProgressStep.downloading:
              _statusMessage = 'Downloading from Google Drive...';
              break;
            case RestoreProgressStep.decrypting:
              _statusMessage = 'Authenticating & decrypting...';
              break;
            case RestoreProgressStep.validating:
              _statusMessage = 'Validating accounting integrity...';
              break;
            case RestoreProgressStep.restoring:
              _statusMessage = 'Restoring database tables...';
              break;
            case RestoreProgressStep.completed:
              _statusMessage = 'Restore complete!';
              break;
            case RestoreProgressStep.failed:
              _statusMessage = 'Restore failed.';
              break;
            default:
              break;
          }
          notifyListeners();
        },
      );

      if (result.isSuccess) {
        _recoveryKey = recoveryKey;
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called whenever transactions or books change to debounce auto-backup
  void onDataChanged() {
    if (_autoBackupEnabled && isConnected) {
      _backupService.scheduleDebouncedAutoBackup();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
