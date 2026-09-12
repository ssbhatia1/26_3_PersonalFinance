import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/data/models/account.dart';
import 'package:personal_finance/data/models/transaction.dart';
import 'package:personal_finance/data/repositories/account_repository.dart';
import 'package:personal_finance/data/repositories/transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase testDbManager;
  late AccountRepository accountRepo;
  late TransactionRepository txRepo;

  setUp(() async {
    testDbManager = AppDatabase.inMemory();
    accountRepo = AccountRepository(testDbManager);
    txRepo = TransactionRepository(testDbManager);

    // Create test accounts
    await accountRepo.createAccount(const Account(
      id: 'acc_bank',
      name: 'Test Bank',
      type: 'Bank Account',
      openingBalance: 10000.0,
      currentBalance: 10000.0,
    ));

    await accountRepo.createAccount(const Account(
      id: 'acc_cash',
      name: 'Test Cash',
      type: 'Cash',
      openingBalance: 1000.0,
      currentBalance: 1000.0,
    ));

    await accountRepo.createAccount(const Account(
      id: 'acc_card',
      name: 'Test Credit Card',
      type: 'Credit Card',
      openingBalance: 0.0,
      currentBalance: 0.0,
      creditLimit: 50000.0,
    ));
  });

  tearDown(() async {
    await testDbManager.close();
  });

  group('Accounting Engine Business Logic (PRD §7.3)', () {
    test('Income increases source account balance', () async {
      final tx = TransactionModel(
        id: 'tx_inc_1',
        sourceAccountId: 'acc_bank',
        type: 'income',
        amount: 5000.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await txRepo.createTransaction(tx);

      final updatedBank = await accountRepo.getAccountById('acc_bank');
      expect(updatedBank?.currentBalance, equals(15000.0));
    });

    test('Expense decreases source account balance', () async {
      final tx = TransactionModel(
        id: 'tx_exp_1',
        sourceAccountId: 'acc_cash',
        type: 'expense',
        amount: 350.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await txRepo.createTransaction(tx);

      final updatedCash = await accountRepo.getAccountById('acc_cash');
      expect(updatedCash?.currentBalance, equals(650.0));
    });

    test('Transfer decreases source and increases destination without altering totals', () async {
      final tx = TransactionModel(
        id: 'tx_trf_1',
        sourceAccountId: 'acc_bank',
        destinationAccountId: 'acc_cash',
        type: 'transfer',
        amount: 2000.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await txRepo.createTransaction(tx);

      final updatedBank = await accountRepo.getAccountById('acc_bank');
      final updatedCash = await accountRepo.getAccountById('acc_cash');

      expect(updatedBank?.currentBalance, equals(8000.0));
      expect(updatedCash?.currentBalance, equals(3000.0));

      // Check cash flow totals: Transfers must NOT count as income or expense!
      final summary = await txRepo.getCashFlowSummary(
        DateTime.now().subtract(const Duration(days: 1)),
        DateTime.now().add(const Duration(days: 1)),
      );

      expect(summary['income'], equals(0.0));
      expect(summary['expense'], equals(0.0));
    });

    test('Zero or negative amounts are rejected at repository level', () async {
      final badTx = TransactionModel(
        id: 'tx_bad_1',
        sourceAccountId: 'acc_bank',
        type: 'income',
        amount: -100.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(() => txRepo.createTransaction(badTx), throwsArgumentError);
    });

    test('Transfer with same source and destination is rejected', () async {
      final badTransfer = TransactionModel(
        id: 'tx_bad_2',
        sourceAccountId: 'acc_bank',
        destinationAccountId: 'acc_bank',
        type: 'transfer',
        amount: 500.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(() => txRepo.createTransaction(badTransfer), throwsArgumentError);
    });

    test('Deleting a transaction exactly restores prior balances', () async {
      final tx = TransactionModel(
        id: 'tx_exp_del',
        sourceAccountId: 'acc_cash',
        type: 'expense',
        amount: 400.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await txRepo.createTransaction(tx);
      var cash = await accountRepo.getAccountById('acc_cash');
      expect(cash?.currentBalance, equals(600.0));

      // Now delete (reversal)
      await txRepo.deleteTransaction(tx.id);
      cash = await accountRepo.getAccountById('acc_cash');
      expect(cash?.currentBalance, equals(1000.0)); // Restored!
    });

    test('Net Worth calculates Assets minus Liabilities correctly', () async {
      // acc_bank = 10000 (Asset)
      // acc_cash = 1000 (Asset)
      // Card purchase of 2500 (increases liability)
      final cardExpense = TransactionModel(
        id: 'tx_card_exp',
        sourceAccountId: 'acc_card',
        type: 'expense',
        amount: 2500.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await txRepo.createTransaction(cardExpense);

      final summary = await accountRepo.getNetWorthSummary();
      expect(summary['totalAssets'], equals(11000.0)); // 10000 bank + 1000 cash
      expect(summary['totalLiabilities'], equals(2500.0)); // 2500 credit card debt
      expect(summary['netWorth'], equals(8500.0)); // 11000 - 2500 = 8500
    });
  });
}
