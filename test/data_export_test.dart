// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/data/models/account.dart';
import 'package:personal_finance/data/models/category.dart';
import 'package:personal_finance/data/models/transaction.dart';
import 'package:personal_finance/data/repositories/account_repository.dart';
import 'package:personal_finance/data/repositories/category_repository.dart';
import 'package:personal_finance/data/repositories/settings_repository.dart';
import 'package:personal_finance/data/repositories/transaction_repository.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;

  @override
  Future<String?> getDownloadsPath() async => tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase testDb;
  late AccountRepository accountRepo;
  late TransactionRepository txRepo;
  late CategoryRepository categoryRepo;
  late SettingsRepository settingsRepo;
  late Directory tempTestDir;

  setUp(() async {
    tempTestDir = Directory.systemTemp.createTempSync('pf_export_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempTestDir);

    testDb = AppDatabase.inMemory();
    accountRepo = AccountRepository(testDb);
    txRepo = TransactionRepository(testDb);
    categoryRepo = CategoryRepository(testDb);
    settingsRepo = SettingsRepository(testDb, txRepo);

    // Setup initial data
    await categoryRepo.createCategory(const Category(
      id: 'cat_groceries',
      name: 'Groceries',
      type: 'expense',
      icon: 'shopping_cart',
      color: '0xFF10B981',
    ));
    await categoryRepo.createCategory(const Category(
      id: 'cat_salary',
      name: 'Salary',
      type: 'income',
      icon: 'work',
      color: '0xFF10B981',
    ));

    await accountRepo.createAccount(const Account(
      id: 'acc_checking',
      name: 'Checking Account',
      type: 'checking',
      openingBalance: 5000.0,
      currentBalance: 5000.0,
      currency: 'INR',
    ));

    await accountRepo.createAccount(const Account(
      id: 'acc_savings',
      name: 'High Yield Savings',
      type: 'savings',
      openingBalance: 20000.0,
      currentBalance: 20000.0,
      currency: 'INR',
    ));

    // Add transactions
    await txRepo.createTransaction(TransactionModel(
      id: 'tx_1',
      sourceAccountId: 'acc_checking',
      categoryId: 'cat_groceries',
      type: 'expense',
      amount: 150.0,
      date: DateTime(2026, 3, 10, 10, 0),
      description: 'Supermarket weekly run',
      paymentMethod: 'Debit Card',
      referenceNumber: 'REF-001',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    await txRepo.createTransaction(TransactionModel(
      id: 'tx_2',
      sourceAccountId: 'acc_checking',
      categoryId: 'cat_salary',
      type: 'income',
      amount: 4000.0,
      date: DateTime(2026, 3, 1, 9, 0),
      description: 'March Monthly Salary',
      paymentMethod: 'Direct Deposit',
      referenceNumber: 'REF-002',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    await txRepo.createTransaction(TransactionModel(
      id: 'tx_3',
      sourceAccountId: 'acc_savings',
      type: 'income',
      amount: 250.0,
      date: DateTime(2026, 2, 15, 12, 0),
      description: 'Interest Credit',
      paymentMethod: 'Bank Credit',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  });

  tearDown(() async {
    await testDb.close();
    if (tempTestDir.existsSync()) {
      tempTestDir.deleteSync(recursive: true);
    }
  });

  group('Data Export Tests', () {
    test('exportTransactionsCsv includes expected CSV headers and all records when unfiltered', () async {
      final csvString = await settingsRepo.exportTransactionsCsv();
      final rows = csv.decode(csvString);

      expect(rows.length, 4); // 1 header row + 3 data rows
      final headers = rows.first.map((e) => e.toString()).toList();
      expect(headers, contains('Date'));
      expect(headers, contains('Type'));
      expect(headers, contains('Amount'));
      expect(headers, contains('Category'));
      expect(headers, contains('Source Account'));
      expect(headers, contains('Description'));
      expect(headers, contains('Payment Method'));
      expect(headers, contains('Reference Number'));
    });

    test('exportTransactionsCsv filters properly by account ID', () async {
      final checkingCsv = await settingsRepo.exportTransactionsCsv(accountId: 'acc_checking');
      final rows = csv.decode(checkingCsv);

      expect(rows.length, 3); // 1 header + 2 checking transactions
      // Data rows should only belong to Checking Account (column index 5: Source Account)
      for (int i = 1; i < rows.length; i++) {
        expect(rows[i][5], 'Checking Account');
      }

      final savingsCsv = await settingsRepo.exportTransactionsCsv(accountId: 'acc_savings');
      final savingsRows = csv.decode(savingsCsv);
      expect(savingsRows.length, 2); // 1 header + 1 savings transaction
      expect(savingsRows[1][5], 'High Yield Savings');
    });

    test('exportTransactionsCsv filters properly by date range', () async {
      final marchCsv = await settingsRepo.exportTransactionsCsv(
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31, 23, 59),
      );
      final rows = csv.decode(marchCsv);

      // Only tx_1 and tx_2 were in March
      expect(rows.length, 3); // 1 header + 2 transactions

      final februaryCsv = await settingsRepo.exportTransactionsCsv(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28, 23, 59),
      );
      final febRows = csv.decode(februaryCsv);
      expect(febRows.length, 2); // 1 header + tx_3
      expect(febRows[1][8], 'Interest Credit');
    });

    test('exportFullBackupJson exports all financial entities with valid structure and metadata', () async {
      final jsonString = await settingsRepo.exportFullBackupJson();
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded.containsKey('metadata'), isTrue);
      expect(decoded.containsKey('accounts'), isTrue);
      expect(decoded.containsKey('transactions'), isTrue);
      expect(decoded.containsKey('categories'), isTrue);
      expect(decoded.containsKey('budgets'), isTrue);

      final metadata = decoded['metadata'] as Map<String, dynamic>;
      expect(metadata['appName'], 'Personal Finance Ledger');
      expect(metadata['version'], 1);

      final counts = metadata['counts'] as Map<String, dynamic>;
      expect(counts['accounts'], 2);
      expect(counts['transactions'], 3);
      expect(counts['categories'], 2);

      final accountsList = decoded['accounts'] as List;
      expect(accountsList.length, 2);
      final transactionsList = decoded['transactions'] as List;
      expect(transactionsList.length, 3);
    });

    test('saveToFile writes content to file system via fallback directory in test environment', () async {
      final savedPath = await settingsRepo.saveToFile(
        content: 'Date,Type,Amount\n2026-03-10,expense,50.0',
        defaultFileName: 'statement_test.csv',
        fileExtension: 'csv',
        dialogTitle: 'Export CSV',
      );

      expect(savedPath, isNotNull);
      final savedFile = File(savedPath!);
      expect(savedFile.existsSync(), isTrue);
      final readContent = savedFile.readAsStringSync();
      expect(readContent.contains('2026-03-10,expense,50.0'), isTrue);
    });

    test('importTransactionsCsv parses rows and persists new transactions in SQLite', () async {
      const mockCsv = '''Date,Type,Amount,Category,Account,Target Account,Description,Payment Method,Reference
2026-03-15,expense,85.50,Groceries,Checking Account,,Organic Market,Card,REF-999
2026-03-16,income,500.00,Bonus,Checking Account,,Performance Award,Transfer,REF-1000''';

      final count = await settingsRepo.importTransactionsCsv(mockCsv, 'acc_checking');
      expect(count, 2);

      final allTxs = await txRepo.getTransactions(accountId: 'acc_checking');
      expect(allTxs.length, 4); // 2 existing + 2 newly imported
      final refNumbers = allTxs.map((t) => t.referenceNumber).toList();
      expect(refNumbers, contains('REF-999'));
      expect(refNumbers, contains('REF-1000'));
    });

    test('importBackupJson restores multiple entities in atomic transaction', () async {
      final backupData = {
        'metadata': {'appName': 'Personal Finance Ledger', 'version': 1},
        'accounts': [
          {
            'id': 'acc_imported_wallet',
            'name': 'Cash Wallet',
            'type': 'cash',
            'opening_balance': 350.0,
            'current_balance': 350.0,
            'currency': 'INR',
            'status': 'active',
            'is_deleted': 0,
          }
        ],
        'categories': [
          {
            'id': 'cat_imported_books',
            'name': 'Books & Learning',
            'type': 'expense',
            'icon': 'menu_book',
            'color': '0xFF3B82F6',
          }
        ],
        'transactions': [
          {
            'id': 'tx_imported_book',
            'source_account_id': 'acc_imported_wallet',
            'category_id': 'cat_imported_books',
            'type': 'expense',
            'amount': 45.0,
            'date': DateTime(2026, 3, 5).toIso8601String(),
            'description': 'Flutter Architecture Book',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'is_deleted': 0,
          }
        ],
        'budgets': [],
        'recurringTransactions': [],
        'loans': [],
        'financialGoals': [],
        'settings': [],
      };

      final jsonString = jsonEncode(backupData);
      final importStats = await settingsRepo.importBackupJson(jsonString);

      expect(importStats['accounts'], 1);
      expect(importStats['transactions'], 1);

      final walletAcc = await accountRepo.getAccountById('acc_imported_wallet');
      expect(walletAcc, isNotNull);
      expect(walletAcc!.name, 'Cash Wallet');

      final allCats = await categoryRepo.getAllCategories();
      final importedCat = allCats.firstWhere((c) => c.id == 'cat_imported_books');
      expect(importedCat.name, 'Books & Learning');

      final allTxs = await txRepo.getTransactions(accountId: 'acc_imported_wallet');
      final importedTx = allTxs.firstWhere((t) => t.id == 'tx_imported_book');
      expect(importedTx.description, 'Flutter Architecture Book');
    });
  });
}
