import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../models/transaction.dart';
import 'transaction_repository.dart';

class SettingsRepository {
  final AppDatabase _dbManager;
  final TransactionRepository _txRepo;
  final _uuid = const Uuid();

  SettingsRepository([AppDatabase? dbManager, TransactionRepository? txRepo])
      : _dbManager = dbManager ?? AppDatabase.instance,
        _txRepo = txRepo ?? TransactionRepository(dbManager);

  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final db = await _dbManager.database;
    final maps = await db.query(
      DatabaseTables.settings,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isEmpty) return defaultValue;
    return maps.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _dbManager.database;
    await db.insert(
      DatabaseTables.settings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Exports transactions into CSV format with optional account and date range filters
  Future<String> exportTransactionsCsv({
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final transactions = await _txRepo.getTransactions(
      accountId: accountId,
      startDate: startDate,
      endDate: endDate,
      sortBy: 'date_desc',
    );
    final currency = await getSetting('currency', defaultValue: '₹');

    final List<List<dynamic>> csvRows = [
      [
        'ID',
        'Date',
        'Type',
        'Amount',
        'Currency',
        'Source Account',
        'Destination Account',
        'Category',
        'Description',
        'Payee/Payer',
        'Payment Method',
        'Reference Number',
        'Status',
        'Notes',
        'Is Reconciled'
      ]
    ];

    for (final t in transactions) {
      csvRows.add([
        t.id,
        t.date.toIso8601String(),
        t.type,
        t.amount,
        currency,
        t.sourceAccountName ?? t.sourceAccountId,
        t.destinationAccountName ?? t.destinationAccountId ?? '',
        t.categoryName ?? t.categoryId ?? '',
        t.description ?? '',
        t.payeePayer ?? '',
        t.paymentMethod ?? '',
        t.referenceNumber ?? '',
        t.status,
        t.notes ?? '',
        t.isReconciled ? 'Yes' : 'No',
      ]);
    }

    return csv.encode(csvRows);
  }

  /// Exports full financial ledger into formatted JSON backup
  Future<String> exportFullBackupJson() async {
    final db = await _dbManager.database;

    final accounts = await db.query(DatabaseTables.accounts, where: 'is_deleted = 0');
    final categories = await db.query(DatabaseTables.categories);
    final transactions = await db.query(DatabaseTables.transactions, where: 'is_deleted = 0');
    final budgets = await db.query(DatabaseTables.budgets, where: 'is_deleted = 0');
    final recurring = await db.query(DatabaseTables.recurringTransactions);
    final paymentRecords = await db.query(DatabaseTables.paymentRecords);
    final loans = await db.query(DatabaseTables.loans);
    final loanRepayments = await db.query(DatabaseTables.loanRepayments);
    final investments = await db.query(DatabaseTables.investments, where: 'is_deleted = 0');
    final goals = await db.query(DatabaseTables.financialGoals);
    final settings = await db.query(DatabaseTables.settings);
    final users = await db.query(DatabaseTables.users);
    final accountAdjustments = await db.query(DatabaseTables.accountAdjustments);

    final backupData = {
      'metadata': {
        'appName': 'Personal Finance Ledger',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'counts': {
          'accounts': accounts.length,
          'categories': categories.length,
          'transactions': transactions.length,
          'budgets': budgets.length,
          'recurringTransactions': recurring.length,
          'paymentRecords': paymentRecords.length,
          'loans': loans.length,
          'loanRepayments': loanRepayments.length,
          'investments': investments.length,
          'financialGoals': goals.length,
          'users': users.length,
          'accountAdjustments': accountAdjustments.length,
        },
      },
      'accounts': accounts,
      'categories': categories,
      'transactions': transactions,
      'budgets': budgets,
      'recurringTransactions': recurring,
      'paymentRecords': paymentRecords,
      'loans': loans,
      'loanRepayments': loanRepayments,
      'investments': investments,
      'financialGoals': goals,
      'settings': settings,
      'users': users,
      'accountAdjustments': accountAdjustments,
    };

    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  /// Prompts the user to save content to disk via FilePicker, with fallback to Downloads/Documents
  Future<String?> saveToFile({
    required String content,
    required String defaultFileName,
    required String fileExtension,
    required String dialogTitle,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: defaultFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: [fileExtension],
      );

      if (uri != null) {
        final path = uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
        // Ensure file exists and has the content written
        final file = File(path);
        if (!await file.exists()) {
          await file.writeAsBytes(bytes);
        }
        return path;
      }
      // If user canceled the picker dialog, return null
      return null;
    } catch (_) {
      // Platform might not support saveFile or threw error (e.g. headless/test env)
    }

    // Fallback: save to Downloads or Documents
    try {
      Directory? targetDir = await getDownloadsDirectory();
      targetDir ??= await getApplicationDocumentsDirectory();

      final targetPath = p.join(targetDir.path, defaultFileName);
      final file = File(targetPath);
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Reads string content from a local file path
  Future<String> readContentFromFile(String filePath) async {
    final file = File(filePath);
    return await file.readAsString();
  }

  /// Imports transactions from CSV content with dynamic column header detection
  Future<int> importTransactionsCsv(String csvContent, String defaultAccountId) async {
    final rows = csv.decode(csvContent);
    if (rows.length <= 1) return 0;

    // Detect column indexes from header row
    final headerRow = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
    int dateIdx = headerRow.indexWhere((h) => h == 'date' || h.contains('tx_date'));
    int typeIdx = headerRow.indexWhere((h) => h == 'type');
    int amountIdx = headerRow.indexWhere((h) => h == 'amount');
    int descIdx = headerRow.indexWhere((h) => h.contains('description') || h == 'desc' || h == 'memo');
    int payeeIdx = headerRow.indexWhere((h) => h.contains('payee') || h.contains('payer'));
    int refNumIdx = headerRow.indexWhere((h) => h.contains('reference') || h == 'ref');
    int paymentMethodIdx = headerRow.indexWhere((h) => h.contains('payment method') || h == 'method');

    // Default fallbacks if standard exported CSV without header match:
    if (dateIdx == -1) dateIdx = 1;
    if (typeIdx == -1) typeIdx = 2;
    if (amountIdx == -1) amountIdx = 3;

    int importedCount = 0;
    final now = DateTime.now();

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= amountIdx) continue;

      try {
        final amount = double.tryParse(row[amountIdx].toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
        if (amount <= 0) continue;

        String type = 'expense';
        if (typeIdx >= 0 && row.length > typeIdx) {
          final t = row[typeIdx].toString().toLowerCase().trim();
          if (t == 'expense' || t == 'income' || t == 'transfer') {
            type = t;
          }
        }

        DateTime date = now;
        if (dateIdx >= 0 && row.length > dateIdx) {
          date = DateTime.tryParse(row[dateIdx].toString().trim()) ?? now;
        }

        String desc = 'Imported Transaction';
        if (descIdx >= 0 && row.length > descIdx && row[descIdx].toString().trim().isNotEmpty) {
          desc = row[descIdx].toString().trim();
        }

        String? payee;
        if (payeeIdx >= 0 && row.length > payeeIdx && row[payeeIdx].toString().trim().isNotEmpty) {
          payee = row[payeeIdx].toString().trim();
        }

        String? paymentMethod;
        if (paymentMethodIdx >= 0 && row.length > paymentMethodIdx && row[paymentMethodIdx].toString().trim().isNotEmpty) {
          paymentMethod = row[paymentMethodIdx].toString().trim();
        }

        String? refNum;
        if (refNumIdx >= 0 && row.length > refNumIdx && row[refNumIdx].toString().trim().isNotEmpty) {
          refNum = row[refNumIdx].toString().trim();
        }

        final tx = TransactionModel(
          id: _uuid.v4(),
          sourceAccountId: defaultAccountId,
          type: type,
          amount: amount,
          date: date,
          description: desc,
          payeePayer: payee,
          paymentMethod: paymentMethod,
          referenceNumber: refNum,
          createdAt: now,
          updatedAt: now,
        );

        await _txRepo.createTransaction(tx);
        importedCount++;
      } catch (_) {
        // Skip malformed row
      }
    }

    return importedCount;
  }

  /// Imports complete backup JSON into database
  Future<Map<String, int>> importBackupJson(String jsonContent) async {
    final dynamic parsed = jsonDecode(jsonContent);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON backup file structure.');
    }
    final data = parsed;
    final db = await _dbManager.database;

    int importedAccounts = 0;
    int importedTransactions = 0;
    int importedBudgets = 0;

    await db.transaction((txn) async {
      // Import categories
      if (data['categories'] is List) {
        for (final c in data['categories']) {
          final map = Map<String, dynamic>.from(c as Map);
          map.remove('created_at');
          map.remove('updated_at');
          await txn.insert(DatabaseTables.categories, map, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Import accounts
      if (data['accounts'] is List) {
        for (final a in data['accounts']) {
          await txn.insert(DatabaseTables.accounts, Map<String, dynamic>.from(a as Map), conflictAlgorithm: ConflictAlgorithm.replace);
          importedAccounts++;
        }
      }

      // Import transactions
      if (data['transactions'] is List) {
        for (final t in data['transactions']) {
          await txn.insert(DatabaseTables.transactions, Map<String, dynamic>.from(t as Map), conflictAlgorithm: ConflictAlgorithm.replace);
          importedTransactions++;
        }
      }

      // Import budgets
      if (data['budgets'] is List) {
        for (final b in data['budgets']) {
          await txn.insert(DatabaseTables.budgets, Map<String, dynamic>.from(b as Map), conflictAlgorithm: ConflictAlgorithm.replace);
          importedBudgets++;
        }
      }

      // Import recurring transactions
      if (data['recurringTransactions'] is List) {
        for (final r in data['recurringTransactions']) {
          await txn.insert(DatabaseTables.recurringTransactions, Map<String, dynamic>.from(r as Map), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Import payment records
      if (data['paymentRecords'] is List) {
        for (final p in data['paymentRecords']) {
          await txn.insert(DatabaseTables.paymentRecords, Map<String, dynamic>.from(p as Map), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Import loans
      if (data['loans'] is List) {
        for (final l in data['loans']) {
          await txn.insert(DatabaseTables.loans, Map<String, dynamic>.from(l as Map), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Import loan repayments
      if (data['loanRepayments'] is List) {
        for (final lr in data['loanRepayments']) {
          await txn.insert(DatabaseTables.loanRepayments, Map<String, dynamic>.from(lr as Map), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Import investments
      if (data['investments'] is List) {
        for (final inv in data['investments']) {
          await txn.insert(DatabaseTables.investments, Map<String, dynamic>.from(inv as Map), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Import goals
      if (data['financialGoals'] is List) {
        for (final g in data['financialGoals']) {
          await txn.insert(DatabaseTables.financialGoals, Map<String, dynamic>.from(g as Map), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Import users
      if (data['users'] is List) {
        for (final u in data['users']) {
          await txn.insert(DatabaseTables.users, Map<String, dynamic>.from(u as Map), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Import account adjustments
      if (data['accountAdjustments'] is List) {
        for (final adj in data['accountAdjustments']) {
          await txn.insert(DatabaseTables.accountAdjustments, Map<String, dynamic>.from(adj as Map), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });

    return {
      'accounts': importedAccounts,
      'transactions': importedTransactions,
      'budgets': importedBudgets,
    };
  }
}
