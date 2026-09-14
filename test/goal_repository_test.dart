import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/data/models/account.dart';
import 'package:personal_finance/data/models/financial_goal.dart';
import 'package:personal_finance/data/models/transaction.dart';
import 'package:personal_finance/data/repositories/account_repository.dart';
import 'package:personal_finance/data/repositories/goal_repository.dart';
import 'package:personal_finance/data/repositories/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late GoalRepository goalRepo;
  late AccountRepository accountRepo;
  late TransactionRepository txRepo;

  setUp(() async {
    db = AppDatabase.inMemory(seedData: false);
    await db.ensureTablesAndDemoUser();
    goalRepo = GoalRepository(db);
    accountRepo = AccountRepository(db);
    txRepo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Creates and retrieves goal for non-demo active user without linked account', () async {
    const regularUserId = 'usr_regular_999';
    final newGoal = FinancialGoal(
      id: 'goal_emergency_fund',
      name: 'Emergency Fund',
      targetAmount: 50000.0,
      currentAmount: 10000.0,
      targetDate: DateTime.now().add(const Duration(days: 180)),
      linkedAccountId: null,
    );

    await goalRepo.createGoal(newGoal);

    final goals = await goalRepo.getAllGoals(userId: regularUserId);
    expect(goals.length, 1);
    expect(goals.first.id, 'goal_emergency_fund');
    expect(goals.first.name, 'Emergency Fund');
    expect(goals.first.targetAmount, 50000.0);
    expect(goals.first.currentAmount, 10000.0);
    expect(goals.first.linkedAccountId, isNull);
  });

  test('Updates existing goal successfully', () async {
    const userId = 'usr_test_user';
    final initialGoal = FinancialGoal(
      id: 'goal_vacation',
      name: 'Vacation',
      targetAmount: 20000.0,
      currentAmount: 5000.0,
      targetDate: DateTime.now().add(const Duration(days: 90)),
    );

    await goalRepo.createGoal(initialGoal);

    final updatedGoal = initialGoal.copyWith(
      name: 'European Vacation',
      targetAmount: 30000.0,
      currentAmount: 15000.0,
    );

    await goalRepo.updateGoal(updatedGoal);

    final goals = await goalRepo.getAllGoals(userId: userId);
    expect(goals.length, 1);
    expect(goals.first.name, 'European Vacation');
    expect(goals.first.targetAmount, 30000.0);
    expect(goals.first.currentAmount, 15000.0);
  });

  test('Withdraws from goal successfully', () async {
    const userId = 'usr_test_user';
    final goal = FinancialGoal(
      id: 'goal_house',
      name: 'House Downpayment',
      targetAmount: 100000.0,
      currentAmount: 40000.0,
      targetDate: DateTime.now().add(const Duration(days: 365)),
    );

    await goalRepo.createGoal(goal);
    await goalRepo.withdrawFromGoal('goal_house', 15000.0);

    final goals = await goalRepo.getAllGoals(userId: userId);
    expect(goals.first.currentAmount, 25000.0);
  });

  test('Automatically syncs linked Goal current amount when transactions occur on linked account', () async {
    const userId = 'usr_test_user';
    final account = Account(
      id: 'acc_savings_goal',
      userId: userId,
      accountToken: 'tok_savings',
      name: 'Goal Savings Account',
      type: 'savings',
      openingBalance: 10000.0,
      currentBalance: 10000.0,
    );
    await accountRepo.createAccount(account);

    final goal = FinancialGoal(
      id: 'goal_car',
      name: 'Car Purchase',
      targetAmount: 50000.0,
      currentAmount: 10000.0,
      targetDate: DateTime.now().add(const Duration(days: 180)),
      linkedAccountId: 'acc_savings_goal',
    );
    await goalRepo.createGoal(goal);

    // 1. Add Income transaction to linked account
    final txIncome = TransactionModel(
      id: 'tx_goal_inc',
      sourceAccountId: 'acc_savings_goal',
      type: 'income',
      amount: 5000.0,
      date: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await txRepo.createTransaction(txIncome);

    var goals = await goalRepo.getAllGoals(userId: userId);
    expect(goals.first.currentAmount, 15000.0);

    // 2. Add Expense transaction from linked account
    final txExpense = TransactionModel(
      id: 'tx_goal_exp',
      sourceAccountId: 'acc_savings_goal',
      type: 'expense',
      amount: 2000.0,
      date: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await txRepo.createTransaction(txExpense);

    goals = await goalRepo.getAllGoals(userId: userId);
    expect(goals.first.currentAmount, 13000.0);
  });

  test('Deletes goal successfully', () async {
    const userId = 'usr_test_user';
    final goal = FinancialGoal(
      id: 'goal_delete_me',
      name: 'Temporary Goal',
      targetAmount: 10000.0,
      targetDate: DateTime.now().add(const Duration(days: 365)),
    );

    await goalRepo.createGoal(goal);
    var goals = await goalRepo.getAllGoals(userId: userId);
    expect(goals.length, 1);

    await goalRepo.deleteGoal('goal_delete_me');
    goals = await goalRepo.getAllGoals(userId: userId);
    expect(goals.isEmpty, true);
  });
}
