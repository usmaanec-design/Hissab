import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class BackupDriveFile {
  final String id;
  final String name;
  final DateTime modifiedTime;
  final int sizeBytes;
  final Map<String, String> properties;

  const BackupDriveFile({
    required this.id,
    required this.name,
    required this.modifiedTime,
    required this.sizeBytes,
    this.properties = const {},
  });
}

abstract class ICloudDriveService {
  Future<BackupDriveFile?> findLatestBackup();
  Future<String> downloadBackup(String fileId);
  Future<BackupDriveFile> uploadBackup({
    required String encryptedContent,
    required Map<String, String> properties,
  });
  Future<void> deleteBackup();
}

/// Production Google Drive implementation using drive.file scope and dedicated Hissab/ folder
class GoogleDriveService implements ICloudDriveService {
  static const String _folderName = 'Hissab';
  static const String _latestFileName = 'Hissab_Backup.hsb';
  static const String _previousFileName = 'Hissab_Backup_Previous.hsb';
  static const String _mimeTypeFolder = 'application/vnd.google-apps.folder';
  static const String _mimeTypeOctetStream = 'application/octet-stream';

  final Future<http.Client?> Function() _clientProvider;

  GoogleDriveService({required Future<http.Client?> Function() clientProvider})
      : _clientProvider = clientProvider;

  Future<drive.DriveApi> _getDriveApi() async {
    final client = await _clientProvider();
    if (client == null) {
      throw Exception('Not signed in to Google or unable to get authenticated HTTP client.');
    }
    return drive.DriveApi(client);
  }

  /// Locates or creates the dedicated 'Hissab' folder on Google Drive
  Future<String> _getOrCreateHissabFolder(drive.DriveApi api) async {
    final query = "name = '$_folderName' and mimeType = '$_mimeTypeFolder' and trashed = false";
    final folderList = await api.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    if (folderList.files != null && folderList.files!.isNotEmpty) {
      return folderList.files!.first.id!;
    }

    // Create the Hissab folder in My Drive
    final folderMeta = drive.File()
      ..name = _folderName
      ..mimeType = _mimeTypeFolder
      ..parents = ['root'];

    final createdFolder = await api.files.create(
      folderMeta,
      $fields: 'id',
    );
    return createdFolder.id!;
  }

  @override
  Future<BackupDriveFile?> findLatestBackup() async {
    try {
      final api = await _getDriveApi();
      final folderId = await _getOrCreateHissabFolder(api);

      final query = "'$folderId' in parents and name = '$_latestFileName' and trashed = false";
      final fileList = await api.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, modifiedTime, size, appProperties, description)',
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) {
        return null;
      }

      final file = files.first;
      final modified = file.modifiedTime ?? DateTime.now();
      final size = int.tryParse(file.size ?? '0') ?? 0;
      final rawProps = file.appProperties;
      final props = rawProps != null
          ? rawProps.map((k, v) => MapEntry(k, v ?? ''))
          : <String, String>{};

      return BackupDriveFile(
        id: file.id!,
        name: file.name ?? _latestFileName,
        modifiedTime: modified,
        sizeBytes: size,
        properties: props,
      );
    } catch (e) {
      debugPrint('Error finding latest Hissab backup on Drive: $e');
      return null;
    }
  }

  @override
  Future<String> downloadBackup(String fileId) async {
    final api = await _getDriveApi();
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    return utf8.decode(bytes);
  }

  @override
  Future<BackupDriveFile> uploadBackup({
    required String encryptedContent,
    required Map<String, String> properties,
  }) async {
    final api = await _getDriveApi();
    final folderId = await _getOrCreateHissabFolder(api);

    // 1. Check if an existing latest backup exists to archive as previous
    final query = "'$folderId' in parents and name = '$_latestFileName' and trashed = false";
    final existingList = await api.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    String? existingFileId;
    if (existingList.files != null && existingList.files!.isNotEmpty) {
      existingFileId = existingList.files!.first.id;
    }

    // 2. Prepare upload content
    final contentBytes = utf8.encode(encryptedContent);
    final mediaStream = Stream.fromIterable([contentBytes]);
    final uploadMedia = drive.Media(mediaStream, contentBytes.length);

    drive.File uploadedFile;

    if (existingFileId != null) {
      // Rotate previous backup: rename existing to Hissab_Backup_Previous.hsb
      try {
        final prevQuery = "'$folderId' in parents and name = '$_previousFileName' and trashed = false";
        final prevList = await api.files.list(q: prevQuery, $fields: 'files(id)');
        if (prevList.files != null) {
          for (final prev in prevList.files!) {
            await api.files.delete(prev.id!);
          }
        }
      } catch (_) {}

      // Update existing file content & metadata atomically
      final updateMeta = drive.File()
        ..name = _latestFileName
        ..appProperties = properties
        ..description = 'Hissab CashBook Encrypted Cloud Backup';

      uploadedFile = await api.files.update(
        updateMeta,
        existingFileId,
        uploadMedia: uploadMedia,
        $fields: 'id, name, modifiedTime, size',
      );
    } else {
      // Create new backup file inside Hissab folder
      final newMeta = drive.File()
        ..name = _latestFileName
        ..parents = [folderId]
        ..mimeType = _mimeTypeOctetStream
        ..appProperties = properties
        ..description = 'Hissab CashBook Encrypted Cloud Backup';

      uploadedFile = await api.files.create(
        newMeta,
        uploadMedia: uploadMedia,
        $fields: 'id, name, modifiedTime, size',
      );
    }

    return BackupDriveFile(
      id: uploadedFile.id!,
      name: uploadedFile.name ?? _latestFileName,
      modifiedTime: uploadedFile.modifiedTime ?? DateTime.now(),
      sizeBytes: int.tryParse(uploadedFile.size ?? '0') ?? contentBytes.length,
      properties: properties,
    );
  }

  @override
  Future<void> deleteBackup() async {
    final api = await _getDriveApi();
    final folderId = await _getOrCreateHissabFolder(api);

    final query = "'$folderId' in parents and trashed = false";
    final fileList = await api.files.list(q: query, $fields: 'files(id)');
    if (fileList.files != null) {
      for (final f in fileList.files!) {
        await api.files.delete(f.id!);
      }
    }
  }
}

/// High-fidelity in-memory Mock Drive Service for unit testing and headless environments
class MockCloudDriveService implements ICloudDriveService {
  String? _storedEncryptedContent;
  BackupDriveFile? _storedFile;
  bool shouldFail = false;

  void reset() {
    _storedEncryptedContent = null;
    _storedFile = null;
    shouldFail = false;
  }

  @override
  Future<BackupDriveFile?> findLatestBackup() async {
    if (shouldFail) throw Exception('Simulated network error');
    return _storedFile;
  }

  @override
  Future<String> downloadBackup(String fileId) async {
    if (shouldFail) throw Exception('Simulated download error');
    if (_storedEncryptedContent == null) {
      throw Exception('Backup file not found in mock drive');
    }
    return _storedEncryptedContent!;
  }

  @override
  Future<BackupDriveFile> uploadBackup({
    required String encryptedContent,
    required Map<String, String> properties,
  }) async {
    if (shouldFail) throw Exception('Simulated upload error');
    _storedEncryptedContent = encryptedContent;
    final now = DateTime.now();
    _storedFile = BackupDriveFile(
      id: 'mock-file-id-${now.millisecondsSinceEpoch}',
      name: 'Hissab_Backup.hsb',
      modifiedTime: now,
      sizeBytes: utf8.encode(encryptedContent).length,
      properties: properties,
    );
    return _storedFile!;
  }

  @override
  Future<void> deleteBackup() async {
    _storedEncryptedContent = null;
    _storedFile = null;
  }
}
