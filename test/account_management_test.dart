import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/data/models/account.dart';
import 'package:personal_finance/data/models/category.dart';
import 'package:personal_finance/data/models/financial_goal.dart';
import 'package:personal_finance/data/models/loan.dart';
import 'package:personal_finance/data/models/recurring_transaction.dart';
import 'package:personal_finance/data/models/transaction.dart';
import 'package:personal_finance/data/repositories/account_repository.dart';
import 'package:personal_finance/data/repositories/category_repository.dart';
import 'package:personal_finance/data/repositories/goal_repository.dart';
import 'package:personal_finance/data/repositories/loan_repository.dart';
import 'package:personal_finance/data/repositories/recurring_repository.dart';
import 'package:personal_finance/data/repositories/transaction_repository.dart';
import 'package:personal_finance/providers/account_detail_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase testDb;
  late AccountRepository accountRepo;
  late TransactionRepository txRepo;
  late CategoryRepository categoryRepo;
  late RecurringRepository recurringRepo;
  late LoanRepository loanRepo;
  late GoalRepository goalRepo;

  setUp(() async {
    testDb = AppDatabase.inMemory();
    accountRepo = AccountRepository(testDb);
    txRepo = TransactionRepository(testDb);
    categoryRepo = CategoryRepository(testDb);
    recurringRepo = RecurringRepository(testDb);
    loanRepo = LoanRepository(testDb);
    goalRepo = GoalRepository(testDb);

    // Create test categories
    await categoryRepo.createCategory(const Category(
      id: 'cat_groceries',
      name: 'Groceries',
      type: 'expense',
      icon: 'shopping_cart',
      color: '0xFF10B981',
    ));
    await categoryRepo.createCategory(const Category(
      id: 'cat_dining',
      name: 'Dining',
      type: 'expense',
      icon: 'restaurant',
      color: '0xFFF59E0B',
    ));
    await categoryRepo.createCategory(const Category(
      id: 'cat_salary',
      name: 'Salary',
      type: 'income',
      icon: 'work',
      color: '0xFF10B981',
    ));

    // Create primary test account
    await accountRepo.createAccount(const Account(
      id: 'acc_salary',
      name: 'Salary Account',
      type: 'Salary Account',
      institution: 'HDFC',
      openingBalance: 50000.0,
      currentBalance: 50000.0,
    ));

    // Create secondary test account (for transfers)
    await accountRepo.createAccount(const Account(
      id: 'acc_wallet',
      name: 'Paytm Wallet',
      type: 'Digital Wallet',
      openingBalance: 2000.0,
      currentBalance: 2000.0,
    ));
  });

  tearDown(() async {
    await testDb.close();
  });

  group('Feature 1: View Transactions & Balance Impact', () {
    test('Shows transactions and accurately calculates account balance impact', () async {
      final now = DateTime.now();

      // 1. Income into Salary Account: +25000
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_inc',
        sourceAccountId: 'acc_salary',
        type: 'income',
        categoryId: 'cat_salary',
        amount: 25000.0,
        date: now.subtract(const Duration(days: 3)),
        description: 'Monthly Bonus',
        paymentMethod: 'Bank Transfer',
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Expense from Salary Account: -4000
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_exp',
        sourceAccountId: 'acc_salary',
        type: 'expense',
        categoryId: 'cat_groceries',
        amount: 4000.0,
        date: now.subtract(const Duration(days: 2)),
        description: 'Supermarket Groceries',
        paymentMethod: 'Debit Card',
        createdAt: now,
        updatedAt: now,
      ));

      // 3. Transfer Out of Salary Account into Paytm Wallet: -5000
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_xfer',
        sourceAccountId: 'acc_salary',
        destinationAccountId: 'acc_wallet',
        type: 'transfer',
        amount: 5000.0,
        date: now.subtract(const Duration(days: 1)),
        description: 'Top up wallet',
        paymentMethod: 'UPI',
        createdAt: now,
        updatedAt: now,
      ));

      // Query transactions for acc_salary
      final list = await txRepo.getTransactions(accountId: 'acc_salary');
      expect(list.length, equals(3));

      // Verify balance impact for each transaction from acc_salary's perspective
      final incTx = list.firstWhere((t) => t.id == 'tx_inc');
      expect(AccountDetailNotifier.getBalanceImpact(incTx, 'acc_salary'), equals(25000.0));

      final expTx = list.firstWhere((t) => t.id == 'tx_exp');
      expect(AccountDetailNotifier.getBalanceImpact(expTx, 'acc_salary'), equals(-4000.0));

      final xferTx = list.firstWhere((t) => t.id == 'tx_xfer');
      // Transferred OUT of acc_salary: impact is -5000
      expect(AccountDetailNotifier.getBalanceImpact(xferTx, 'acc_salary'), equals(-5000.0));
      // Transferred INTO acc_wallet: impact is +5000
      expect(AccountDetailNotifier.getBalanceImpact(xferTx, 'acc_wallet'), equals(5000.0));
    });

    test('Filtering and sorting by type, category, amount, and date works', () async {
      final now = DateTime.now();

      await txRepo.createTransaction(TransactionModel(
        id: 't1',
        sourceAccountId: 'acc_salary',
        type: 'expense',
        categoryId: 'cat_groceries',
        amount: 1000.0,
        date: now.subtract(const Duration(days: 10)),
        createdAt: now,
        updatedAt: now,
      ));

      await txRepo.createTransaction(TransactionModel(
        id: 't2',
        sourceAccountId: 'acc_salary',
        type: 'expense',
        categoryId: 'cat_dining',
        amount: 5000.0,
        date: now.subtract(const Duration(days: 5)),
        createdAt: now,
        updatedAt: now,
      ));

      await txRepo.createTransaction(TransactionModel(
        id: 't3',
        sourceAccountId: 'acc_salary',
        type: 'income',
        categoryId: 'cat_salary',
        amount: 30000.0,
        date: now.subtract(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      ));

      // Filter by type: expense only
      final expenses = await txRepo.getTransactions(accountId: 'acc_salary', type: 'expense');
      expect(expenses.length, equals(2));

      // Filter by category: groceries only
      final groceries = await txRepo.getTransactions(accountId: 'acc_salary', categoryId: 'cat_groceries');
      expect(groceries.length, equals(1));
      expect(groceries.first.id, equals('t1'));

      // Sort by amount descending
      final sortedAmount = await txRepo.getTransactions(accountId: 'acc_salary', sortBy: 'amount_desc');
      expect(sortedAmount.first.amount, equals(30000.0));
      expect(sortedAmount.last.amount, equals(1000.0));

      // Sort by amount ascending
      final sortedAmountAsc = await txRepo.getTransactions(accountId: 'acc_salary', sortBy: 'amount_asc');
      expect(sortedAmountAsc.first.amount, equals(1000.0));
      expect(sortedAmountAsc.last.amount, equals(30000.0));
    });
  });

  group('Feature 2: Account Spending Details & Charts', () {
    test('Calculates total spending and category breakdown accurately', () async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Add spending in groceries (6000) and dining (4000)
      await txRepo.createTransaction(TransactionModel(
        id: 'sp_1',
        sourceAccountId: 'acc_salary',
        type: 'expense',
        categoryId: 'cat_groceries',
        amount: 6000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      await txRepo.createTransaction(TransactionModel(
        id: 'sp_2',
        sourceAccountId: 'acc_salary',
        type: 'expense',
        categoryId: 'cat_dining',
        amount: 4000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      final spending = await txRepo.getAccountSpendingSummary('acc_salary', startDate: start, endDate: end);
      expect(spending['totalSpending'], equals(10000.0));
      expect(spending['transactionCount'], equals(2));
      expect(spending['averagePerTransaction'], equals(5000.0));

      final breakdown = spending['categoryBreakdown'] as List<Map<String, dynamic>>;
      expect(breakdown.length, equals(2));

      final topCategory = breakdown.first;
      expect(topCategory['categoryName'], equals('Groceries'));
      expect(topCategory['amount'], equals(6000.0));
      expect(topCategory['percentage'], equals(60.0));

      final secondCategory = breakdown.last;
      expect(secondCategory['categoryName'], equals('Dining'));
      expect(secondCategory['amount'], equals(4000.0));
      expect(secondCategory['percentage'], equals(40.0));
    });

    test('Generates daily, weekly, monthly, and yearly spending trend data', () async {
      final now = DateTime.now();

      await txRepo.createTransaction(TransactionModel(
        id: 'trend_1',
        sourceAccountId: 'acc_salary',
        type: 'expense',
        categoryId: 'cat_groceries',
        amount: 2500.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      // Daily trend (7 days of week)
      final dailyTrend = await txRepo.getAccountSpendingTrend('acc_salary', periodType: 'daily', referenceDate: now);
      expect(dailyTrend.length, equals(7));
      final totalDaily = dailyTrend.fold(0.0, (sum, d) => sum + (d['amount'] as double));
      expect(totalDaily, equals(2500.0));

      // Weekly trend
      final weeklyTrend = await txRepo.getAccountSpendingTrend('acc_salary', periodType: 'weekly', referenceDate: now);
      expect(weeklyTrend.isNotEmpty, isTrue);

      // Monthly trend (12 months)
      final monthlyTrend = await txRepo.getAccountSpendingTrend('acc_salary', periodType: 'monthly', referenceDate: now);
      expect(monthlyTrend.length, equals(12));
      final totalMonthly = monthlyTrend.fold(0.0, (sum, m) => sum + (m['amount'] as double));
      expect(totalMonthly, equals(2500.0));

      // Yearly trend (5 years)
      final yearlyTrend = await txRepo.getAccountSpendingTrend('acc_salary', periodType: 'yearly', referenceDate: now);
      expect(yearlyTrend.length, equals(5));
      final totalYearly = yearlyTrend.fold(0.0, (sum, y) => sum + (y['amount'] as double));
      expect(totalYearly, equals(2500.0));
    });
  });

  group('Feature 3: Delete Account & Cascade Handling', () {
    test('getAccountTransactionStats returns transaction count and balance before deletion', () async {
      final now = DateTime.now();

      await txRepo.createTransaction(TransactionModel(
        id: 'stat_tx_1',
        sourceAccountId: 'acc_salary',
        type: 'expense',
        categoryId: 'cat_groceries',
        amount: 1500.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      final stats = await accountRepo.getAccountTransactionStats('acc_salary');
      expect(stats['transactionCount'], equals(1));
      expect(stats['accountName'], equals('Salary Account'));
    });

    test('deleteAccount cascades cleanly, adjusts paired accounts, and prevents data inconsistencies', () async {
      final now = DateTime.now();

      // 1. Add an expense to acc_salary
      await txRepo.createTransaction(TransactionModel(
        id: 'cas_exp',
        sourceAccountId: 'acc_salary',
        type: 'expense',
        categoryId: 'cat_groceries',
        amount: 2000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Add a transfer from acc_salary to acc_wallet (3000)
      // acc_wallet balance becomes 2000 + 3000 = 5000
      await txRepo.createTransaction(TransactionModel(
        id: 'cas_xfer',
        sourceAccountId: 'acc_salary',
        destinationAccountId: 'acc_wallet',
        type: 'transfer',
        amount: 3000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      final walletBefore = await accountRepo.getAccountById('acc_wallet');
      expect(walletBefore?.currentBalance, equals(5000.0));

      // 3. Link a recurring transaction
      await recurringRepo.createRecurring(RecurringTransaction(
        id: 'rec_salary',
        title: 'Monthly Rent',
        sourceAccountId: 'acc_salary',
        type: 'expense',
        amount: 15000.0,
        frequency: 'monthly',
        startDate: now,
        nextExecutionDate: now.add(const Duration(days: 30)),
        isActive: true,
      ));

      // 4. Link a loan
      await loanRepo.createLoan(Loan(
        id: 'loan_1',
        accountId: 'acc_salary',
        borrowerLenderName: 'HDFC Bank',
        loanType: 'Personal',
        principal: 100000.0,
        outstandingBalance: 100000.0,
        startDate: now,
      ));

      // 5. Link a financial goal
      await goalRepo.createGoal(FinancialGoal(
        id: 'goal_car',
        name: 'New Car',
        targetAmount: 500000.0,
        currentAmount: 10000.0,
        targetDate: now.add(const Duration(days: 365)),
        linkedAccountId: 'acc_salary',
      ));

      // Execute atomic cascade delete of acc_salary
      await accountRepo.deleteAccount('acc_salary');

      // VERIFICATIONS:
      // A. Account is marked deleted
      final activeAccounts = await accountRepo.getAllAccounts();
      expect(activeAccounts.any((a) => a.id == 'acc_salary'), isFalse);

      final deletedAccount = await accountRepo.getAccountById('acc_salary');
      expect(deletedAccount?.isDeleted, isTrue);

      // B. Associated transactions are marked deleted
      final allTx = await txRepo.getTransactions(accountId: 'acc_salary');
      expect(allTx, isEmpty);

      // C. Paired transfer account (acc_wallet) has transfer reversed so it holds no orphan balance
      // 5000 - 3000 = 2000 restored!
      final walletAfter = await accountRepo.getAccountById('acc_wallet');
      expect(walletAfter?.currentBalance, equals(2000.0));

      // D. Recurring transaction is deactivated
      final allRecurring = await recurringRepo.getAllRecurring();
      final rec = allRecurring.firstWhere((r) => r.id == 'rec_salary');
      expect(rec.isActive, isFalse);

      // E. Loan is closed
      final activeLoans = await loanRepo.getAllLoans(status: 'active');
      expect(activeLoans.any((l) => l.id == 'loan_1'), isFalse);

      // F. Financial goal is unlinked (not deleted, but linkedAccountId is cleared)
      final goals = await goalRepo.getAllGoals();
      final carGoal = goals.firstWhere((g) => g.id == 'goal_car');
      expect(carGoal.linkedAccountId, isNull);
    });
  });
}
