import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/data/models/account.dart';
import 'package:personal_finance/data/models/transaction.dart';
import 'package:personal_finance/data/repositories/account_repository.dart';
import 'package:personal_finance/data/repositories/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Account Adjustment Tests', () {
    late AppDatabase db;
    late AccountRepository accountRepo;
    late TransactionRepository txRepo;

    setUp(() async {
      db = AppDatabase.inMemory();
      accountRepo = AccountRepository(db);
      txRepo = TransactionRepository(db);
    });

    test('Adjusts balance upwards, preserves original transactions, and records audit trail', () async {
      // 1. Create Account
      final acc = Account(
        id: 'acc-adj-test',
        name: 'Savings Bank Account',
        type: 'Bank Account',
        openingBalance: 10000,
        currentBalance: 10000,
        currency: 'INR',
      );
      await accountRepo.createAccount(acc);

      // 2. Add an original transaction
      final tx = TransactionModel(
        id: 'orig-tx-1',
        sourceAccountId: acc.id,
        amount: 2500,
        type: 'expense',
        date: DateTime.now().subtract(const Duration(days: 2)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        description: 'Grocery Shopping',
      );
      await txRepo.createTransaction(tx);

      // Balance after expense is 7,500
      final fetchedAccBefore = await accountRepo.getAccountById(acc.id);
      expect(fetchedAccBefore?.currentBalance, 7500.0);

      // 3. User realizes actual bank statement has 9,000 (diff: +1,500 adjustment)
      final adjustment = await accountRepo.adjustAccountBalance(
        accountId: acc.id,
        newBalance: 9000,
        reason: 'Reconciled with passbook entry; interest credited',
        timestamp: DateTime.now(),
      );

      // 4. Verify account balance reflects exact reconciled amount
      final fetchedAccAfter = await accountRepo.getAccountById(acc.id);
      expect(fetchedAccAfter?.currentBalance, 9000.0);

      // 5. Verify adjustment record
      expect(adjustment.accountId, acc.id);
      expect(adjustment.previousBalance, 7500.0);
      expect(adjustment.newBalance, 9000.0);
      expect(adjustment.adjustmentAmount, 1500.0);
      expect(adjustment.adjustmentType, 'increase');
      expect(adjustment.reason, 'Reconciled with passbook entry; interest credited');

      // 6. Verify adjustment history query
      final history = await accountRepo.getAccountAdjustments(acc.id);
      expect(history.length, 1);
      expect(history.first.adjustmentAmount, 1500.0);

      // 7. Verify original transaction is NOT touched or deleted
      final origTx = await txRepo.getTransactionById('orig-tx-1');
      expect(origTx, isNotNull);
      expect(origTx?.amount, 2500.0);
      expect(origTx?.isDeleted, isFalse);

      // 8. Verify adjustment appears in transaction history as 'adjustment'
      final allTxs = await txRepo.getTransactions(accountId: acc.id);
      expect(allTxs.any((t) => t.isAdjustment && t.amount == 1500.0), isTrue);
    });

    test('Adjusts balance downwards accurately', () async {
      final acc = Account(
        id: 'acc-adj-down',
        name: 'Cash Wallet',
        type: 'Cash',
        openingBalance: 5000,
        currentBalance: 5000,
      );
      await accountRepo.createAccount(acc);

      final adjustment = await accountRepo.adjustAccountBalance(
        accountId: acc.id,
        newBalance: 4200,
        reason: 'Physical cash count difference',
      );

      final fetchedAcc = await accountRepo.getAccountById(acc.id);
      expect(fetchedAcc?.currentBalance, 4200.0);
      expect(adjustment.adjustmentAmount, 800.0);
      expect(adjustment.adjustmentType, 'decrease');
    });
  });
}
