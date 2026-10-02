import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hissab/core/services/backup_export_service.dart';
import 'package:hissab/core/services/backup_restore_service.dart';
import 'package:hissab/core/services/cloud_auth_service.dart';
import 'package:hissab/core/services/cloud_backup_service.dart';
import 'package:hissab/core/services/cloud_drive_service.dart';
import 'package:hissab/data/database/tables.dart';

void main() {
  late Database dbDeviceA;
  late Database dbDeviceB;
  late MockCloudAuthService mockAuth;
  late MockCloudDriveService mockDrive;
  late CloudBackupService backupServiceA;
  late CloudBackupService backupServiceB;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> createIsolatedDb(String dbName) async {
    return await openDatabase(
      'file:$dbName?mode=memory&cache=private',
      version: 1,
      onCreate: (db, version) async {
        await db.execute(Tables.createBooksTable);
        await db.execute(Tables.createAccountsTable);
        await db.execute(Tables.createCategoriesTable);
        await db.execute(Tables.createPartiesTable);
        await db.execute(Tables.createTransactionsTable);
        await db.execute(Tables.createAuditLogsTable);
        await db.execute(Tables.createDescriptionHistoryTable);
        await db.execute(Tables.createCategoryLearningsTable);
        await db.execute(Tables.createContactHistoryTable);
        for (final idx in Tables.createIndexes) {
          await db.execute(idx);
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final ts = DateTime.now().microsecondsSinceEpoch;
    dbDeviceA = await createIsolatedDb('device_a_$ts');
    dbDeviceB = await createIsolatedDb('device_b_$ts');

    mockAuth = MockCloudAuthService(
      initialUser: const CloudUser(
        id: 'google-sub-user-12345',
        email: 'usman@gmail.com',
        displayName: 'Usman Ali',
      ),
    );
    mockDrive = MockCloudDriveService();

    backupServiceA = CloudBackupService(
      authService: mockAuth,
      driveService: mockDrive,
      exportService: BackupExportService(),
      restoreService: BackupRestoreService(),
    );

    backupServiceB = CloudBackupService(
      authService: mockAuth,
      driveService: mockDrive,
      exportService: BackupExportService(),
      restoreService: BackupRestoreService(),
    );
  });

  tearDown(() async {
    await dbDeviceA.close();
    await dbDeviceB.close();
  });

  group('Full Cloud Backup & Cross-Device Restore Matrix', () {
    test('1. Populate Device A with Multi-Book Accounting Data including Transfers and Large Amounts', () async {
      final now = DateTime.now().toIso8601String();

      // Create Book 1: Retail Store with Custom Logo
      await dbDeviceA.insert(Tables.books, {
        'id': 'book-retail-1',
        'name': 'Retail Store',
        'currency': 'SAR',
        'opening_balance_minor': 100000, // 1,000.00 SAR
        'opening_balance_date': '2026-09-01',
        'color': 4280656875,
        'logo': 'bank:al_rajhi',
        'created_at': now,
        'updated_at': now,
      });

      // Create Book 2: Wholesale Hub with Extreme Large Number
      await dbDeviceA.insert(Tables.books, {
        'id': 'book-wholesale-2',
        'name': 'Wholesale Hub',
        'currency': 'SAR',
        'opening_balance_minor': 55555555555500, // SAR 555,555,555,555.00 (Requirement 29)
        'opening_balance_date': '2026-09-01',
        'color': 4282384396,
        'logo': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        'created_at': now,
        'updated_at': now,
      });

      // Accounts
      await dbDeviceA.insert(Tables.accounts, {
        'id': 'acc-cash-1',
        'book_id': 'book-retail-1',
        'name': 'Cash Drawer',
        'type': 'cash',
        'opening_balance_minor': 0,
        'created_at': now,
        'updated_at': now,
      });
      await dbDeviceA.insert(Tables.accounts, {
        'id': 'acc-bank-1',
        'book_id': 'book-retail-1',
        'name': 'Al Rajhi Business',
        'type': 'bank',
        'opening_balance_minor': 0,
        'created_at': now,
        'updated_at': now,
      });

      // Categories
      await dbDeviceA.insert(Tables.categories, {
        'id': 'cat-sales',
        'book_id': 'book-retail-1',
        'name': 'Store Sales',
        'type': 'income',
        'icon': 'shopping_bag',
        'color': 0xFF059669,
        'created_at': now,
      });
      await dbDeviceA.insert(Tables.categories, {
        'id': 'cat-rent',
        'book_id': 'book-retail-1',
        'name': 'Store Rent',
        'type': 'expense',
        'icon': 'home',
        'color': 0xFF8B5CF6,
        'created_at': now,
      });

      // Party
      await dbDeviceA.insert(Tables.parties, {
        'id': 'party-supplier-1',
        'book_id': 'book-retail-1',
        'name': 'Ahmed Distribution Co',
        'phone': '+966501234567',
        'type': 'supplier',
        'created_at': now,
        'updated_at': now,
      });

      // Transactions: Income (5,000 SAR) and Expense (2,000 SAR)
      await dbDeviceA.insert(Tables.transactions, {
        'id': 'tx-inc-1',
        'book_id': 'book-retail-1',
        'account_id': 'acc-cash-1',
        'category_id': 'cat-sales',
        'party_id': 'party-supplier-1',
        'type': 'in',
        'amount_minor': 500000, // 5,000.00 SAR
        'date': '2026-09-20',
        'time': '10:30',
        'description': 'Bulk daily sales receipt',
        'payment_method': 'cash',
        'created_at': now,
        'updated_at': now,
      });

      await dbDeviceA.insert(Tables.transactions, {
        'id': 'tx-exp-1',
        'book_id': 'book-retail-1',
        'account_id': 'acc-cash-1',
        'category_id': 'cat-rent',
        'type': 'out',
        'amount_minor': 200000, // 2,000.00 SAR
        'date': '2026-09-21',
        'time': '14:15',
        'description': 'Shop advance rent payment',
        'payment_method': 'cash',
        'created_at': now,
        'updated_at': now,
      });

      // Internal Transfer (Requirement 27: TRANSFER_OUT + TRANSFER_IN linked via transfer_id)
      const transferId = 'transfer-uuid-987';
      await dbDeviceA.insert(Tables.transactions, {
        'id': 'tx-tr-out',
        'book_id': 'book-retail-1',
        'account_id': 'acc-cash-1',
        'type': 'transfer_out',
        'amount_minor': 100000, // 1,000.00 SAR
        'date': '2026-09-22',
        'time': '16:00',
        'description': 'Deposit Cash into Bank',
        'transfer_id': transferId,
        'created_at': now,
        'updated_at': now,
      });

      await dbDeviceA.insert(Tables.transactions, {
        'id': 'tx-tr-in',
        'book_id': 'book-retail-1',
        'account_id': 'acc-bank-1',
        'type': 'transfer_in',
        'amount_minor': 100000, // 1,000.00 SAR
        'date': '2026-09-22',
        'time': '16:00',
        'description': 'Deposit Cash into Bank',
        'transfer_id': transferId,
        'created_at': now,
        'updated_at': now,
      });

      // 2. Perform Backup on Device A
      final backupResult = await backupServiceA.performBackup(overrideDb: dbDeviceA);
      expect(backupResult.isSuccess, isTrue);
      expect(backupResult.sizeBytes, greaterThan(0));

      final latestFile = await mockDrive.findLatestBackup();
      expect(latestFile, isNotNull);
      expect(latestFile!.name, 'Hissab_Backup.hsb');
      expect(latestFile.properties['booksCount'], '2');
      expect(latestFile.properties['transactionsCount'], '4');

      // 3. Destructive Uninstall / Device B Emulation:
      // Device B starts with a completely empty database
      final bBooksBefore = await dbDeviceB.query(Tables.books);
      expect(bBooksBefore.isEmpty, isTrue);

      // Sign in on Device B with SAME Google Account
      final userB = await backupServiceB.authService.getCurrentUser();
      expect(userB?.id, 'google-sub-user-12345');

      // Find backup on Google Drive
      final cloudFile = await backupServiceB.checkCloudBackup();
      expect(cloudFile, isNotNull);
      expect(cloudFile!.properties['booksCount'], '2');

      // Read recovery key used during backup
      final recoveryKey = await backupServiceA.getOrCreateRecoveryKey();

      // Restore onto Device B
      final restoreResult = await backupServiceB.performRestore(
        fileId: cloudFile.id,
        recoveryKey: recoveryKey,
        replaceExisting: true,
        overrideDb: dbDeviceB,
      );

      expect(restoreResult.isSuccess, isTrue);
      expect(restoreResult.booksRestored, 2);
      expect(restoreResult.transactionsRestored, 4);

      // 4. Verify Accounting & Data Integrity on Device B
      final restoredBooks = await dbDeviceB.query(Tables.books, orderBy: 'id ASC');
      expect(restoredBooks.length, 2);
      expect(restoredBooks[0]['id'], 'book-retail-1');
      expect(restoredBooks[0]['name'], 'Retail Store');
      expect(restoredBooks[0]['logo'], 'bank:al_rajhi');

      // Extreme large number check (Requirement 29)
      expect(restoredBooks[1]['id'], 'book-wholesale-2');
      expect(restoredBooks[1]['opening_balance_minor'], 55555555555500);

      final restoredParties = await dbDeviceB.query(Tables.parties);
      expect(restoredParties.length, 1);
      expect(restoredParties.first['name'], 'Ahmed Distribution Co');

      final restoredAccounts = await dbDeviceB.query(Tables.accounts);
      expect(restoredAccounts.length, 2);

      final restoredTxs = await dbDeviceB.query(Tables.transactions, orderBy: 'date ASC');
      expect(restoredTxs.length, 4);

      // Linked transfer check (Requirement 27)
      final transferOut = restoredTxs.firstWhere((t) => t['type'] == 'transfer_out');
      final transferIn = restoredTxs.firstWhere((t) => t['type'] == 'transfer_in');
      expect(transferOut['transfer_id'], transferId);
      expect(transferIn['transfer_id'], transferId);
      expect(transferOut['amount_minor'], 100000);
      expect(transferIn['amount_minor'], 100000);

      // Accounting Ledger Balance calculation check (Requirement 26)
      // Opening = 1,000.00 (100,000), In = 5,000.00 (500,000), Out = 2,000.00 (200,000)
      // Transfers net to 0. Net balance = 100,000 + 500,000 - 200,000 = 400,000 (4,000.00 SAR)
      int calcBalance = restoredBooks[0]['opening_balance_minor'] as int;
      for (final tx in restoredTxs) {
        if (tx['book_id'] != 'book-retail-1') continue;
        final type = tx['type'] as String;
        final amt = tx['amount_minor'] as int;
        if (type == 'in') calcBalance += amt;
        if (type == 'out') calcBalance -= amt;
      }
      expect(calcBalance, 400000); // Exact 4,000.00 SAR
    });

    test('2. Wrong Google Account Isolation Test (Requirement 21)', () async {
      // 1. Create backup with Account A
      await dbDeviceA.insert(Tables.books, {
        'id': 'secret-book',
        'name': 'Personal Secrets',
        'currency': 'SAR',
        'opening_balance_minor': 1000,
        'opening_balance_date': '2026-09-01',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await backupServiceA.performBackup(overrideDb: dbDeviceA);
      final cloudFile = await mockDrive.findLatestBackup();
      expect(cloudFile, isNotNull);

      final recoveryKey = await backupServiceA.getOrCreateRecoveryKey();

      // 2. User B logs in with a DIFFERENT Google Account (Account B)
      mockAuth.setMockUser(const CloudUser(
        id: 'google-sub-user-DIFFERENT',
        email: 'other_user@gmail.com',
      ));

      // Attempt restore with Account B
      final restoreResult = await backupServiceB.performRestore(
        fileId: cloudFile!.id,
        recoveryKey: recoveryKey,
        replaceExisting: true,
        overrideDb: dbDeviceB,
      );

      // Must fail and reject with wrong account protection
      expect(restoreResult.isSuccess, isFalse);
      expect(restoreResult.errorMessage, isNotNull);

      // Verify dbDeviceB is still clean
      final booksB = await dbDeviceB.query(Tables.books);
      expect(booksB.isEmpty, isTrue);
    });

    test('3. Atomic Rollback on Corrupted or Invalid Data (Requirement 17)', () async {
      // Add existing local data to Device B
      await dbDeviceB.insert(Tables.books, {
        'id': 'local-book-do-not-delete',
        'name': 'Existing Device B Book',
        'currency': 'SAR',
        'opening_balance_minor': 5000,
        'opening_balance_date': '2026-09-01',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Prepare corrupted restore payload
      final corruptedPayload = 'CORRUPTED_NON_JSON_DATA';
      await mockDrive.uploadBackup(
        encryptedContent: corruptedPayload,
        properties: {},
      );

      final cloudFile = await mockDrive.findLatestBackup();
      final recoveryKey = await backupServiceA.getOrCreateRecoveryKey();

      final restoreResult = await backupServiceB.performRestore(
        fileId: cloudFile!.id,
        recoveryKey: recoveryKey,
        replaceExisting: true,
        overrideDb: dbDeviceB,
      );

      expect(restoreResult.isSuccess, isFalse);

      // Verify local data on Device B was NOT deleted or corrupted!
      final preservedBooks = await dbDeviceB.query(Tables.books);
      expect(preservedBooks.length, 1);
      expect(preservedBooks.first['name'], 'Existing Device B Book');
    });
  });
}
