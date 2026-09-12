import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/data/models/account.dart';
import 'package:personal_finance/data/models/attachment.dart';
import 'package:personal_finance/data/models/transaction.dart';
import 'package:personal_finance/data/repositories/account_repository.dart';
import 'package:personal_finance/data/repositories/attachment_repository.dart';
import 'package:personal_finance/data/repositories/transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase testDb;
  late AccountRepository accountRepo;
  late TransactionRepository txRepo;
  late AttachmentRepository attachmentRepo;
  late Directory tempStorageDir;

  setUp(() async {
    testDb = AppDatabase.inMemory();
    accountRepo = AccountRepository(testDb);
    txRepo = TransactionRepository(testDb);
    tempStorageDir = Directory.systemTemp.createTempSync('pf_attachment_test_');
    attachmentRepo = AttachmentRepository(testDb, tempStorageDir);

    // Create a base account
    await accountRepo.createAccount(const Account(
      id: 'acc_main',
      name: 'Main Checking',
      type: 'checking',
      openingBalance: 5000.0,
      currentBalance: 5000.0,
    ));
  });

  tearDown(() async {
    await testDb.close();
    if (await tempStorageDir.exists()) {
      await tempStorageDir.delete(recursive: true);
    }
  });

  group('AttachmentModel Unit Tests', () {
    test('Correctly identifies image, pdf, and text types', () {
      final img = AttachmentModel(
        id: 'att_1',
        transactionId: 'tx_1',
        fileName: 'receipt_target.jpg',
        filePath: '/path/receipt_target.jpg',
        fileType: 'image/jpeg',
        fileSize: 1024 * 500, // 500 KB
        uploadedAt: DateTime.now(),
      );

      final pdf = AttachmentModel(
        id: 'att_2',
        transactionId: 'tx_1',
        fileName: 'statement_march.pdf',
        filePath: '/path/statement_march.pdf',
        fileType: 'application/pdf',
        fileSize: 1024 * 1024 * 2, // 2 MB
        uploadedAt: DateTime.now(),
      );

      final txt = AttachmentModel(
        id: 'att_3',
        transactionId: 'tx_1',
        fileName: 'invoice_notes.txt',
        filePath: '/path/invoice_notes.txt',
        fileType: 'text/plain',
        fileSize: 350, // 350 B
        uploadedAt: DateTime.now(),
      );

      expect(img.isImage, isTrue);
      expect(img.isPdf, isFalse);
      expect(img.fileExtension, 'JPG');
      expect(img.formattedSize, '500.0 KB');

      expect(pdf.isPdf, isTrue);
      expect(pdf.isImage, isFalse);
      expect(pdf.fileExtension, 'PDF');
      expect(pdf.formattedSize, '2.00 MB');

      expect(txt.isText, isTrue);
      expect(txt.isImage, isFalse);
      expect(txt.fileExtension, 'TXT');
      expect(txt.formattedSize, '350 B');
    });

    test('Serializes to and from SQLite map accurately', () {
      final now = DateTime.parse('2026-09-10T12:00:00.000Z');
      final att = AttachmentModel(
        id: 'att_map_1',
        transactionId: 'tx_123',
        fileName: 'sample_doc.png',
        filePath: 'attachments/transactions/tx_123/sample_doc.png',
        fileType: 'image/png',
        fileSize: 2048,
        uploadedAt: now,
      );

      final map = att.toMap();
      expect(map['id'], 'att_map_1');
      expect(map['transaction_id'], 'tx_123');
      expect(map['file_name'], 'sample_doc.png');
      expect(map['file_path'], 'attachments/transactions/tx_123/sample_doc.png');
      expect(map['file_type'], 'image/png');
      expect(map['file_size'], 2048);

      final fromMap = AttachmentModel.fromMap(map);
      expect(fromMap.id, att.id);
      expect(fromMap.transactionId, att.transactionId);
      expect(fromMap.fileName, att.fileName);
      expect(fromMap.filePath, att.filePath);
      expect(fromMap.fileType, att.fileType);
      expect(fromMap.fileSize, att.fileSize);
      expect(fromMap.uploadedAt, att.uploadedAt);
    });
  });

  group('AttachmentRepository Integration Tests', () {
    test('Persists, retrieves, and counts attachments for a transaction', () async {
      // 1. Create a transaction
      final tx = TransactionModel(
        id: 'tx_with_att',
        sourceAccountId: 'acc_main',
        type: 'expense',
        amount: 150.0,
        date: DateTime.now(),
        description: 'Office Supplies with Receipts',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await txRepo.createTransaction(tx);

      // Verify initially 0 attachments
      var fetchedTx = await txRepo.getTransactionById('tx_with_att');
      expect(fetchedTx, isNotNull);
      expect(fetchedTx!.attachmentCount, 0);

      // 2. Create a source file to simulate user-selected file
      final sourceFile = File('${tempStorageDir.path}/test_receipt.png');
      await sourceFile.writeAsString('FAKE_IMAGE_DATA_12345');

      // 3. Save attachment
      final savedAtt = await attachmentRepo.copyAndSaveAttachment(
        transactionId: 'tx_with_att',
        sourcePath: sourceFile.path,
        fileName: 'receipt_jan.png',
      );

      expect(savedAtt.id, isNotEmpty);
      expect(savedAtt.fileName, 'receipt_jan.png');
      expect(savedAtt.isImage, isTrue);
      expect(await File(savedAtt.filePath).exists(), isTrue);

      // 4. Query attachments by transaction
      final attList = await attachmentRepo.getAttachmentsByTransaction('tx_with_att');
      expect(attList.length, 1);
      expect(attList.first.id, savedAtt.id);
      expect(attList.first.fileName, 'receipt_jan.png');

      // 5. Query transactions and verify attachment_count is 1
      final allTx = await txRepo.getTransactions(searchQuery: 'Office Supplies');
      expect(allTx.length, 1);
      expect(allTx.first.attachmentCount, 1);

      fetchedTx = await txRepo.getTransactionById('tx_with_att');
      expect(fetchedTx!.attachmentCount, 1);

      // 6. Test SHA-256 Checksum calculation
      final sha = await attachmentRepo.getSha256Checksum(savedAtt);
      expect(sha, isNotNull);
      expect(sha!.length, 64); // SHA-256 hex string length

      // 7. Test export/copy attachment
      final exportTarget = '${tempStorageDir.path}/exported_receipt.png';
      final exportSuccess = await attachmentRepo.exportAttachment(
        attachment: savedAtt,
        destinationPath: exportTarget,
      );
      expect(exportSuccess, isTrue);
      expect(await File(exportTarget).exists(), isTrue);

      // 8. Test deleting single attachment
      await attachmentRepo.deleteAttachment(savedAtt.id);
      final remaining = await attachmentRepo.getAttachmentsByTransaction('tx_with_att');
      expect(remaining.isEmpty, isTrue);
      expect(await File(savedAtt.filePath).exists(), isFalse);

      fetchedTx = await txRepo.getTransactionById('tx_with_att');
      expect(fetchedTx!.attachmentCount, 0);
    });

    test('Supports multiple attachments per transaction', () async {
      final tx = TransactionModel(
        id: 'tx_multi_att',
        sourceAccountId: 'acc_main',
        type: 'expense',
        amount: 800.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await txRepo.createTransaction(tx);

      final f1 = File('${tempStorageDir.path}/f1.pdf')..writeAsStringSync('PDF_CONTENT');
      final f2 = File('${tempStorageDir.path}/f2.jpg')..writeAsStringSync('JPEG_CONTENT');
      final f3 = File('${tempStorageDir.path}/f3.txt')..writeAsStringSync('TEXT_CONTENT');

      await attachmentRepo.copyAndSaveAttachment(
        transactionId: 'tx_multi_att',
        sourcePath: f1.path,
        fileName: 'contract.pdf',
      );
      await attachmentRepo.copyAndSaveAttachment(
        transactionId: 'tx_multi_att',
        sourcePath: f2.path,
        fileName: 'bill.jpg',
      );
      await attachmentRepo.copyAndSaveAttachment(
        transactionId: 'tx_multi_att',
        sourcePath: f3.path,
        fileName: 'memo.txt',
      );

      final list = await attachmentRepo.getAttachmentsByTransaction('tx_multi_att');
      expect(list.length, 3);
      expect(list.any((a) => a.isPdf), isTrue);
      expect(list.any((a) => a.isImage), isTrue);
      expect(list.any((a) => a.isText), isTrue);

      final fetched = await txRepo.getTransactionById('tx_multi_att');
      expect(fetched!.attachmentCount, 3);

      // Clean up all for transaction
      await attachmentRepo.deleteAllForTransaction('tx_multi_att');
      final afterDelete = await attachmentRepo.getAttachmentsByTransaction('tx_multi_att');
      expect(afterDelete.isEmpty, isTrue);
    });

    test('Handles duplicate file names without overwriting', () async {
      final tx = TransactionModel(
        id: 'tx_collision',
        sourceAccountId: 'acc_main',
        type: 'expense',
        amount: 25.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await txRepo.createTransaction(tx);

      final f1 = File('${tempStorageDir.path}/collision_source.png')..writeAsStringSync('FILE_ONE');

      final a1 = await attachmentRepo.copyAndSaveAttachment(
        transactionId: 'tx_collision',
        sourcePath: f1.path,
        fileName: 'receipt.png',
      );

      final a2 = await attachmentRepo.copyAndSaveAttachment(
        transactionId: 'tx_collision',
        sourcePath: f1.path,
        fileName: 'receipt.png',
      );

      expect(a1.filePath != a2.filePath, isTrue);
      expect(await File(a1.filePath).exists(), isTrue);
      expect(await File(a2.filePath).exists(), isTrue);

      final list = await attachmentRepo.getAttachmentsByTransaction('tx_collision');
      expect(list.length, 2);

      // Test getAttachmentById
      final fetchedA1 = await attachmentRepo.getAttachmentById(a1.id);
      expect(fetchedA1, isNotNull);
      expect(fetchedA1!.id, a1.id);
      expect(fetchedA1.fileName, a1.fileName);
    });

    test('AttachmentModel copyWith updates fields properly', () {
      final original = AttachmentModel(
        id: 'att_orig',
        transactionId: 'tx_orig',
        fileName: 'old.pdf',
        filePath: '/old/path.pdf',
        fileType: 'application/pdf',
        fileSize: 100,
        uploadedAt: DateTime.now(),
      );

      final modified = original.copyWith(
        fileName: 'new.pdf',
        fileSize: 200,
      );

      expect(modified.id, 'att_orig');
      expect(modified.fileName, 'new.pdf');
      expect(modified.fileSize, 200);
      expect(modified.filePath, '/old/path.pdf');
    });
  });
}

