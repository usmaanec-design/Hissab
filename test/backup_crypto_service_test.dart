import 'package:flutter_test/flutter_test.dart';
import 'package:hissab/core/services/backup_crypto_service.dart';

void main() {
  group('BackupCryptoService Unit Tests', () {
    test('Recovery Key format and validation', () {
      final key = BackupCryptoService.generateRecoveryKey();
      expect(key.length, 19); // 16 chars + 3 hyphens
      expect(BackupCryptoService.isValidKeyFormat(key), isTrue);

      final normalized = BackupCryptoService.normalizeKey(key);
      expect(normalized.length, 16);

      final formatted = BackupCryptoService.formatKey(normalized);
      expect(formatted, key);

      expect(BackupCryptoService.isValidKeyFormat('INVALID-KEY-1234'), isFalse);
    });

    test('Encrypt and Decrypt roundtrip with identical Google User ID', () {
      const sampleJson = '{"app":"Hissab","books":[{"id":"b1","name":"Main Store"}],"balance":55555555555500}';
      final key = BackupCryptoService.generateRecoveryKey();
      const googleSub = 'google-sub-1092837465';

      final encrypted = BackupCryptoService.encryptBackup(
        rawJson: sampleJson,
        recoveryKey: key,
        googleUserId: googleSub,
      );

      expect(encrypted.contains('"hissab_envelope":1'), isTrue);
      expect(encrypted.contains('Main Store'), isFalse); // Confidentiality: No plaintext

      final decrypted = BackupCryptoService.decryptBackup(
        encryptedEnvelopeJson: encrypted,
        recoveryKey: key,
        googleUserId: googleSub,
      );

      expect(decrypted, sampleJson);
    });

    test('Decryption fails with Wrong Recovery Key', () {
      const sampleJson = '{"transactions":[{"id":"tx1","amount":1000}]}';
      final key1 = BackupCryptoService.generateRecoveryKey();
      final key2 = BackupCryptoService.generateRecoveryKey();
      const googleSub = 'google-sub-1092837465';

      final encrypted = BackupCryptoService.encryptBackup(
        rawJson: sampleJson,
        recoveryKey: key1,
        googleUserId: googleSub,
      );

      expect(
        () => BackupCryptoService.decryptBackup(
          encryptedEnvelopeJson: encrypted,
          recoveryKey: key2,
          googleUserId: googleSub,
        ),
        throwsA(isA<BackupCryptoException>()),
      );
    });

    test('Decryption fails with Wrong Google Account ID (Account isolation)', () {
      const sampleJson = '{"books":[{"id":"b1"}]}';
      final key = BackupCryptoService.generateRecoveryKey();
      const accountA = 'google-sub-user-A';
      const accountB = 'google-sub-user-B';

      final encrypted = BackupCryptoService.encryptBackup(
        rawJson: sampleJson,
        recoveryKey: key,
        googleUserId: accountA,
      );

      // Attempt to decrypt using Account B
      expect(
        () => BackupCryptoService.decryptBackup(
          encryptedEnvelopeJson: encrypted,
          recoveryKey: key,
          googleUserId: accountB,
        ),
        throwsA(isA<BackupCryptoException>()),
      );
    });

    test('Decryption fails on Tampered Envelope/Ciphertext (Integrity)', () {
      const sampleJson = '{"secret":"data"}';
      final key = BackupCryptoService.generateRecoveryKey();
      const googleSub = 'google-sub-999';

      final encrypted = BackupCryptoService.encryptBackup(
        rawJson: sampleJson,
        recoveryKey: key,
        googleUserId: googleSub,
      );

      // Tamper with ciphertext by replacing characters
      final tampered = encrypted.replaceAll(RegExp(r'"ciphertext":"[a-zA-Z0-9+/=]{10}'), '"ciphertext":"AAAAAAAAAA');

      expect(
        () => BackupCryptoService.decryptBackup(
          encryptedEnvelopeJson: tampered,
          recoveryKey: key,
          googleUserId: googleSub,
        ),
        throwsA(isA<BackupCryptoException>()),
      );
    });
  });
}
