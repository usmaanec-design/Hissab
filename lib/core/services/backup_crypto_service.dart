import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class BackupCryptoException implements Exception {
  final String message;
  const BackupCryptoException(this.message);

  @override
  String toString() => 'BackupCryptoException: $message';
}

/// Production-grade authenticated encryption for Hissab financial backups.
/// Pipeline:
/// JSON -> GZIP Compress -> AES-256-CBC Encrypt -> HMAC-SHA256 Auth -> Envelope
class BackupCryptoService {
  static const String _charset = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const int _pbkdf2Iterations = 10000;
  static const String _currentAlgorithm = 'AES-256-CBC-HMAC-SHA256-GZIP';

  /// Generates a cryptographically secure 16-character recovery key.
  /// Format: XXXX-XXXX-XXXX-XXXX
  /// Excludes visually ambiguous characters (0, O, 1, I).
  static String generateRecoveryKey() {
    final rand = Random.secure();
    final chars = List.generate(16, (_) => _charset[rand.nextInt(_charset.length)]);
    return '${chars.sublist(0, 4).join()}-${chars.sublist(4, 8).join()}-${chars.sublist(8, 12).join()}-${chars.sublist(12, 16).join()}';
  }

  /// Normalizes and validates recovery key format
  static String normalizeKey(String key) {
    return key.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static bool isValidKeyFormat(String key) {
    final normalized = normalizeKey(key);
    if (normalized.length != 16) return false;
    for (int i = 0; i < normalized.length; i++) {
      if (!_charset.contains(normalized[i])) return false;
    }
    return true;
  }

  /// Formats raw 16-character string into XXXX-XXXX-XXXX-XXXX
  static String formatKey(String key) {
    final norm = normalizeKey(key);
    if (norm.length != 16) return norm;
    return '${norm.substring(0, 4)}-${norm.substring(4, 8)}-${norm.substring(8, 12)}-${norm.substring(12, 16)}';
  }

  /// Key Derivation: derives 64 bytes (32 bytes AES key + 32 bytes HMAC key)
  /// using PBKDF2-HMAC-SHA256 with 10,000 iterations from recoveryKey + googleSub + salt.
  static DerivedKeys _deriveKeys({
    required String recoveryKey,
    required String googleUserId,
    required Uint8List salt,
  }) {
    final normalizedKey = normalizeKey(recoveryKey);
    final keyMaterial = utf8.encode('$normalizedKey:$googleUserId');
    
    // PBKDF2 implementation using HMAC-SHA256
    Uint8List deriveBlock(int blockIndex) {
      final hmac = Hmac(sha256, keyMaterial);
      final saltWithIndex = Uint8List(salt.length + 4);
      saltWithIndex.setRange(0, salt.length, salt);
      final bdata = ByteData.view(saltWithIndex.buffer, salt.length, 4);
      bdata.setUint32(0, blockIndex, Endian.big);

      Uint8List u = Uint8List.fromList(hmac.convert(saltWithIndex).bytes);
      final result = Uint8List.fromList(u);

      for (int i = 1; i < _pbkdf2Iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (int k = 0; k < result.length; k++) {
          result[k] ^= u[k];
        }
      }
      return result;
    }

    final block1 = deriveBlock(1); // 32 bytes for AES
    final block2 = deriveBlock(2); // 32 bytes for HMAC

    return DerivedKeys(
      aesKey: block1,
      hmacKey: block2,
    );
  }

  /// Encrypts logical backup JSON into authenticated encrypted payload
  static String encryptBackup({
    required String rawJson,
    required String recoveryKey,
    required String googleUserId,
  }) {
    if (!isValidKeyFormat(recoveryKey)) {
      throw const BackupCryptoException('Invalid recovery key format. Expected 16 alphanumeric characters.');
    }
    if (googleUserId.trim().isEmpty) {
      throw const BackupCryptoException('Google User ID (sub) cannot be empty.');
    }

    final rawBytes = utf8.encode(rawJson);
    final checksum = sha256.convert(rawBytes).toString();

    // 1. Compress with GZip
    final compressedBytes = GZipEncoder().encode(rawBytes);

    // 2. Generate random Salt (32 bytes) and IV (16 bytes)
    final rand = Random.secure();
    final salt = Uint8List.fromList(List.generate(32, (_) => rand.nextInt(256)));
    final ivBytes = Uint8List.fromList(List.generate(16, (_) => rand.nextInt(256)));

    // 3. Derive AES and HMAC keys
    final keys = _deriveKeys(
      recoveryKey: recoveryKey,
      googleUserId: googleUserId,
      salt: salt,
    );

    // 4. Encrypt with AES-256-CBC
    final encrypter = enc.Encrypter(enc.AES(
      enc.Key(keys.aesKey),
      mode: enc.AESMode.cbc,
      padding: 'PKCS7',
    ));
    final encrypted = encrypter.encryptBytes(
      compressedBytes,
      iv: enc.IV(ivBytes),
    );

    // 5. Compute HMAC-SHA256 over: algorithm + salt + iv + ciphertext
    final hmacInput = <int>[
      ...utf8.encode(_currentAlgorithm),
      ...salt,
      ...ivBytes,
      ...encrypted.bytes,
    ];
    final hmac = Hmac(sha256, keys.hmacKey).convert(hmacInput).toString();

    // 6. Assemble Envelope
    final envelope = {
      'hissab_envelope': 1,
      'version': 1,
      'algorithm': _currentAlgorithm,
      'createdAt': DateTime.now().toIso8601String(),
      'salt': base64Encode(salt),
      'iv': base64Encode(ivBytes),
      'hmac': hmac,
      'checksum': checksum,
      'ciphertext': encrypted.base64,
    };

    return jsonEncode(envelope);
  }

  /// Decrypts and verifies backup envelope.
  /// Throws BackupCryptoException on any tampering, wrong key, or wrong Google account.
  static String decryptBackup({
    required String encryptedEnvelopeJson,
    required String recoveryKey,
    required String googleUserId,
  }) {
    if (!isValidKeyFormat(recoveryKey)) {
      throw const BackupCryptoException('Invalid recovery key format.');
    }
    if (googleUserId.trim().isEmpty) {
      throw const BackupCryptoException('Google User ID (sub) cannot be empty.');
    }

    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(encryptedEnvelopeJson) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupCryptoException('Backup file is not a valid Hissab envelope.');
    }

    if (envelope['hissab_envelope'] != 1 || envelope['algorithm'] != _currentAlgorithm) {
      throw const BackupCryptoException('Unsupported backup format or encryption algorithm.');
    }

    final salt = base64Decode(envelope['salt'] as String);
    final ivBytes = base64Decode(envelope['iv'] as String);
    final expectedHmac = envelope['hmac'] as String;
    final expectedChecksum = envelope['checksum'] as String;
    final ciphertextBytes = base64Decode(envelope['ciphertext'] as String);

    // 1. Derive keys
    final keys = _deriveKeys(
      recoveryKey: recoveryKey,
      googleUserId: googleUserId,
      salt: salt,
    );

    // 2. Authenticate HMAC (Constant-time comparison)
    final hmacInput = <int>[
      ...utf8.encode(_currentAlgorithm),
      ...salt,
      ...ivBytes,
      ...ciphertextBytes,
    ];
    final computedHmac = Hmac(sha256, keys.hmacKey).convert(hmacInput).toString();
    if (!_constantTimeEquals(computedHmac, expectedHmac)) {
      throw const BackupCryptoException(
        'Decryption failed: Incorrect recovery key, wrong Google Account, or file was modified.',
      );
    }

    // 3. Decrypt AES-256-CBC
    Uint8List decryptedCompressed;
    try {
      final encrypter = enc.Encrypter(enc.AES(
        enc.Key(keys.aesKey),
        mode: enc.AESMode.cbc,
        padding: 'PKCS7',
      ));
      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(ciphertextBytes),
        iv: enc.IV(ivBytes),
      );
      decryptedCompressed = Uint8List.fromList(decrypted);
    } catch (e) {
      throw BackupCryptoException('Ciphertext decryption failed: $e');
    }

    // 4. Decompress GZip
    List<int>? decompressed;
    try {
      decompressed = GZipDecoder().decodeBytes(decryptedCompressed);
    } catch (e) {
      throw BackupCryptoException('Decompression failed: $e');
    }

    // 5. Verify SHA-256 Checksum
    final actualChecksum = sha256.convert(decompressed).toString();
    if (actualChecksum != expectedChecksum) {
      throw const BackupCryptoException('Data integrity check failed: payload checksum mismatch.');
    }

    return utf8.decode(decompressed);
  }

  /// Constant-time string equality to prevent timing attacks on HMAC
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

class DerivedKeys {
  final Uint8List aesKey;
  final Uint8List hmacKey;

  const DerivedKeys({
    required this.aesKey,
    required this.hmacKey,
  });
}
