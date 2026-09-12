import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/data/models/budget.dart';
import 'package:personal_finance/data/models/category.dart';
import 'package:personal_finance/data/models/account.dart';
import 'package:personal_finance/data/models/transaction.dart';
import 'package:personal_finance/data/repositories/account_repository.dart';
import 'package:personal_finance/data/repositories/budget_repository.dart';
import 'package:personal_finance/data/repositories/category_repository.dart';
import 'package:personal_finance/data/repositories/transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Budget Model Unit Tests', () {
    test('Calculates remaining amount and percentage used correctly', () {
      final budget = Budget(
        id: 'b1',
        amountLimit: 10000.0,
        spentAmount: 4000.0,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );

      expect(budget.remainingAmount, 6000.0);
      expect(budget.percentageUsed, 0.4);
      expect(budget.isOverspent, isFalse);
    });

    test('Alert levels and status labels transition correctly at 75%, 90%, and 100%', () {
      // Normal: < 75%
      final bNormal = Budget(
        id: 'b_norm',
        amountLimit: 1000.0,
        spentAmount: 700.0, // 70%
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );
      expect(bNormal.alertLevel, BudgetAlertLevel.normal);
      expect(bNormal.statusLabel, 'On Track');

      // Near Limit: >= 75% and < 90%
      final bNear = Budget(
        id: 'b_near',
        amountLimit: 1000.0,
        spentAmount: 800.0, // 80%
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );
      expect(bNear.alertLevel, BudgetAlertLevel.nearLimit75);
      expect(bNear.statusLabel, 'Near Limit');

      // Critical: >= 90% and < 100%
      final bCritical = Budget(
        id: 'b_crit',
        amountLimit: 1000.0,
        spentAmount: 950.0, // 95%
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );
      expect(bCritical.alertLevel, BudgetAlertLevel.critical90);
      expect(bCritical.statusLabel, 'Critical (90%)');

      // Over Budget: >= 100%
      final bOver = Budget(
        id: 'b_over',
        amountLimit: 1000.0,
        spentAmount: 1100.0, // 110%
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );
      expect(bOver.alertLevel, BudgetAlertLevel.overBudget100);
      expect(bOver.statusLabel, 'Over Budget');
      expect(bOver.isOverspent, isTrue);
      expect(bOver.remainingAmount, -100.0);
    });

    test('displayName resolves custom name, category name, or default correctly', () {
      final withCustomName = Budget(
        id: 'b1',
        name: 'Weekly Groceries',
        categoryName: 'Food & Dining',
        amountLimit: 5000,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 7),
      );
      expect(withCustomName.displayName, 'Weekly Groceries');

      final withCategoryOnly = Budget(
        id: 'b2',
        categoryName: 'Transportation',
        amountLimit: 3000,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );
      expect(withCategoryOnly.displayName, 'Transportation');

      final overallBudget = Budget(
        id: 'b3',
        scope: 'overall',
        amountLimit: 50000,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );
      expect(overallBudget.displayName, 'Overall Budget');
    });

    test('Serialization toMap and fromMap maintains all fields', () {
      final original = Budget(
        id: 'b_test',
        name: 'Tech & Gadgets',
        categoryId: 'cat_tech',
        scope: 'category',
        periodType: 'monthly',
        amountLimit: 15000.0,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30, 23, 59, 59),
        isRecurring: true,
        isDeleted: false,
        categoryName: 'Tech',
        categoryIcon: 'computer',
        categoryColor: '#3B82F6',
      );

      final map = original.toMap();
      expect(map['name'], 'Tech & Gadgets');
      expect(map['is_recurring'], 1);
      expect(map['amount_limit'], 15000.0);
      expect(map['period_type'], 'monthly');

      final deserialized = Budget.fromMap(map, spent: 3500.0);
      expect(deserialized.id, original.id);
      expect(deserialized.name, original.name);
      expect(deserialized.categoryId, original.categoryId);
      expect(deserialized.isRecurring, isTrue);
      expect(deserialized.spentAmount, 3500.0);
      expect(deserialized.remainingAmount, 11500.0);
    });

    test('Staying duration and long-term budget properties compute correctly', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 1. Monthly budget ending 10 days in the future
      final bMonthly = Budget(
        id: 'b_month',
        periodType: 'monthly',
        amountLimit: 10000.0,
        spentAmount: 2000.0,
        startDate: today.subtract(const Duration(days: 20)),
        endDate: today.add(const Duration(days: 10)),
      );
      expect(bMonthly.totalDurationDays, 31);
      expect(bMonthly.daysRemaining, 10);
      expect(bMonthly.remainingDaysLabel, '10 days left');
      expect(bMonthly.isLongTerm, isFalse);
      expect(bMonthly.dailyAllowance, 800.0); // 8000 remaining / 10 days

      // 2. Long-term yearly budget (365 days)
      final bYearly = Budget(
        id: 'b_year',
        periodType: 'yearly',
        amountLimit: 120000.0,
        spentAmount: 30000.0,
        startDate: DateTime(now.year, 1, 1),
        endDate: DateTime(now.year, 12, 31),
      );
      expect(bYearly.isLongTerm, isTrue);

      // 3. Custom multi-month budget (>60 days duration)
      final bCustomLong = Budget(
        id: 'b_custom',
        periodType: 'custom',
        amountLimit: 50000.0,
        startDate: today,
        endDate: today.add(const Duration(days: 90)),
      );
      expect(bCustomLong.totalDurationDays, 91);
      expect(bCustomLong.isLongTerm, isTrue);

      // 4. Budget ending today
      final bToday = Budget(
        id: 'b_today',
        periodType: 'weekly',
        amountLimit: 5000.0,
        startDate: today.subtract(const Duration(days: 6)),
        endDate: today,
      );
      expect(bToday.daysRemaining, 0);
      expect(bToday.remainingDaysLabel, 'Ends today');
    });
  });

  group('BudgetRepository Integration Tests', () {
    late AppDatabase dbManager;
    late BudgetRepository budgetRepo;
    late TransactionRepository txRepo;
    late AccountRepository accountRepo;
    late CategoryRepository categoryRepo;

    setUp(() async {
      dbManager = AppDatabase.inMemory();
      budgetRepo = BudgetRepository(dbManager);
      txRepo = TransactionRepository(dbManager);
      accountRepo = AccountRepository(dbManager);
      categoryRepo = CategoryRepository(dbManager);

      // Seed account
      await accountRepo.createAccount(const Account(
        id: 'test_acc',
        name: 'Checking Account',
        type: 'Bank Account',
        openingBalance: 50000.0,
        currentBalance: 50000.0,
      ));

      // Seed category
      await categoryRepo.createCategory(const Category(
        id: 'cat_groceries',
        name: 'Groceries',
        type: 'expense',
        icon: 'shopping_cart',
        color: '#10B981',
      ));
    });

    tearDown(() async {
      await dbManager.close();
    });

    test('createBudget, getBudgetsForMonth, and updateBudget works with SQLite', () async {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 30, 23, 59, 59);

      final newBudget = Budget(
        id: 'b_groc',
        name: 'Monthly Food',
        categoryId: 'cat_groceries',
        scope: 'category',
        periodType: 'monthly',
        amountLimit: 12000.0,
        startDate: start,
        endDate: end,
        isRecurring: true,
      );

      await budgetRepo.createBudget(newBudget);

      var list = await budgetRepo.getBudgetsForMonth(start);
      expect(list.length, 1);
      expect(list.first.name, 'Monthly Food');
      expect(list.first.amountLimit, 12000.0);
      expect(list.first.isRecurring, isTrue);

      // Update budget
      final updated = list.first.copyWith(amountLimit: 15000.0);
      await budgetRepo.updateBudget(updated);

      list = await budgetRepo.getBudgetsForMonth(start);
      expect(list.first.amountLimit, 15000.0);
    });

    test('Spent amount is dynamically and accurately calculated from transactions', () async {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 30, 23, 59, 59);

      await budgetRepo.createBudget(Budget(
        id: 'b_groc',
        categoryId: 'cat_groceries',
        amountLimit: 10000.0,
        startDate: start,
        endDate: end,
      ));

      // Record 2 expenses in September for cat_groceries
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_1',
        sourceAccountId: 'test_acc',
        type: 'expense',
        categoryId: 'cat_groceries',
        amount: 3000.0,
        date: DateTime(2026, 9, 5),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await txRepo.createTransaction(TransactionModel(
        id: 'tx_2',
        sourceAccountId: 'test_acc',
        type: 'expense',
        categoryId: 'cat_groceries',
        amount: 4500.0,
        date: DateTime(2026, 9, 15),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Record an expense in October (outside budget date range)
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_out',
        sourceAccountId: 'test_acc',
        type: 'expense',
        categoryId: 'cat_groceries',
        amount: 5000.0,
        date: DateTime(2026, 10, 2),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final budgets = await budgetRepo.getBudgetsForMonth(start);
      expect(budgets.length, 1);
      expect(budgets.first.spentAmount, 7500.0); // 3000 + 4500
      expect(budgets.first.remainingAmount, 2500.0);
      expect(budgets.first.alertLevel, BudgetAlertLevel.nearLimit75); // 75%
    });

    test('getTransactionsForBudget returns matching transactions for budget', () async {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 30, 23, 59, 59);

      final budget = Budget(
        id: 'b_groc',
        categoryId: 'cat_groceries',
        amountLimit: 10000.0,
        startDate: start,
        endDate: end,
      );
      await budgetRepo.createBudget(budget);

      await txRepo.createTransaction(TransactionModel(
        id: 'tx_1',
        sourceAccountId: 'test_acc',
        type: 'expense',
        categoryId: 'cat_groceries',
        amount: 2500.0,
        date: DateTime(2026, 9, 10),
        payeePayer: 'Supermarket',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final expenses = await budgetRepo.getTransactionsForBudget(budget);
      expect(expenses.length, 1);
      expect(expenses.first.amount, 2500.0);
      expect(expenses.first.payeePayer, 'Supermarket');
    });

    test('checkAndRenewRecurringBudgets automatically rolls forward to next period without altering history', () async {
      final septStart = DateTime(2026, 9, 1);
      final septEnd = DateTime(2026, 9, 30, 23, 59, 59);

      // Create a recurring budget in September
      await budgetRepo.createBudget(Budget(
        id: 'b_sept',
        name: 'Groceries Monthly',
        categoryId: 'cat_groceries',
        amountLimit: 8000.0,
        periodType: 'monthly',
        startDate: septStart,
        endDate: septEnd,
        isRecurring: true,
      ));

      // Advancing to October 2026
      final oct = DateTime(2026, 10, 1);
      final createdCount = await budgetRepo.checkAndRenewRecurringBudgets(oct);
      expect(createdCount, 1);

      // Verify October budget exists
      final octBudgets = await budgetRepo.getBudgetsForMonth(oct);
      expect(octBudgets.length, 1);
      expect(octBudgets.first.name, 'Groceries Monthly');
      expect(octBudgets.first.amountLimit, 8000.0);
      expect(octBudgets.first.startDate.month, 10);
      expect(octBudgets.first.isRecurring, isTrue);

      // Verify September budget still exists completely intact in history
      final septBudgets = await budgetRepo.getBudgetsForMonth(septStart);
      expect(septBudgets.length, 1);
      expect(septBudgets.first.startDate.month, 9);
      expect(septBudgets.first.id, 'b_sept');
    });

    test('deleteBudget soft-deletes budget from active list', () async {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 30, 23, 59, 59);

      await budgetRepo.createBudget(Budget(
        id: 'b_del',
        amountLimit: 5000.0,
        startDate: start,
        endDate: end,
      ));

      var list = await budgetRepo.getBudgetsForMonth(start);
      expect(list.length, 1);

      await budgetRepo.deleteBudget('b_del');

      list = await budgetRepo.getBudgetsForMonth(start);
      expect(list.isEmpty, isTrue);
    });
  });
}
