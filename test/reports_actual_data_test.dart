import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/data/models/account.dart';
import 'package:personal_finance/data/models/transaction.dart';
import 'package:personal_finance/data/repositories/account_repository.dart';
import 'package:personal_finance/data/repositories/transaction_repository.dart';
import 'package:personal_finance/data/models/category.dart';
import 'package:personal_finance/data/repositories/category_repository.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:personal_finance/ui/dashboard/widgets/cash_flow_line_chart.dart';
import 'package:personal_finance/ui/dashboard/widgets/category_comparison_bar_chart.dart';
import 'package:personal_finance/ui/dashboard/widgets/category_donut_chart.dart';
import 'package:personal_finance/ui/dashboard/widgets/financial_funnel_chart.dart';
import 'package:personal_finance/ui/dashboard/widgets/monthly_stacked_bar_chart.dart';
import 'package:personal_finance/ui/dashboard/widgets/net_worth_area_chart.dart';
import 'package:personal_finance/ui/reports/widgets/runway_estimation_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reports Module - Actual Data & Transfer Integrity Tests', () {
    late AppDatabase db;
    late AccountRepository accountRepo;
    late TransactionRepository txRepo;

    setUp(() async {
      db = AppDatabase.inMemory();
      accountRepo = AccountRepository(db);
      txRepo = TransactionRepository(db);

      // Create two real test accounts
      await accountRepo.createAccount(const Account(
        id: 'acc_bank',
        name: 'HDFC Savings',
        type: 'bank',
        openingBalance: 50000.0,
        currentBalance: 50000.0,
      ));

      await accountRepo.createAccount(const Account(
        id: 'acc_wallet',
        name: 'PayTM Wallet',
        type: 'wallet',
        openingBalance: 5000.0,
        currentBalance: 5000.0,
      ));
    });

    tearDown(() async {
      await db.close();
    });

    test('Transfers do NOT affect net income or expense, but update account balances correctly', () async {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // 1. Record Income of ₹30,000 to Bank
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_inc_1',
        sourceAccountId: 'acc_bank',
        type: 'income',
        amount: 30000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Record Expense of ₹10,000 from Bank
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_exp_1',
        sourceAccountId: 'acc_bank',
        type: 'expense',
        amount: 10000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      // 3. Record Internal Transfer of ₹5,000 from Bank to Wallet
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_trans_1',
        sourceAccountId: 'acc_bank',
        destinationAccountId: 'acc_wallet',
        type: 'transfer',
        amount: 5000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      // Verify global cash flow
      final summary = await txRepo.getCashFlowSummary(startDate, endDate);

      // Income must be exactly 30000, Expense exactly 10000, Savings exactly 20000
      expect(summary['income'], 30000.0);
      expect(summary['expense'], 10000.0);
      expect(summary['savings'], 20000.0);
      // Transfers tracked separately
      expect(summary['transfers'], 5000.0);

      // Verify account balances reflect transfer accurately:
      // Bank: 50000 + 30000 - 10000 - 5000 = 65000
      final bank = await accountRepo.getAccountById('acc_bank');
      expect(bank?.currentBalance, 65000.0);

      // Wallet: 5000 + 5000 = 10000
      final wallet = await accountRepo.getAccountById('acc_wallet');
      expect(wallet?.currentBalance, 10000.0);

      // Net Worth across both accounts: 65000 + 10000 = 75000
      // Initial Net Worth was 50000 + 5000 = 55000. Net gain is 20000 (Savings).
      // Transfer did NOT alter total net savings or leak into income/expense!
      final netWorth = (bank?.currentBalance ?? 0) + (wallet?.currentBalance ?? 0);
      expect(netWorth, 75000.0);
    });

    test('Account-filtered cash flow reflects account perspective without corrupting totals', () async {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Transfer from Bank to Wallet
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_trans_2',
        sourceAccountId: 'acc_bank',
        destinationAccountId: 'acc_wallet',
        type: 'transfer',
        amount: 7000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      // From Bank's perspective
      final bankSummary = await txRepo.getCashFlowSummary(startDate, endDate, accountId: 'acc_bank');
      expect(bankSummary['income'], 0.0);
      expect(bankSummary['expense'], 0.0);
      expect(bankSummary['transfersOut'], 7000.0);
      expect(bankSummary['transfersIn'], 0.0);

      // From Wallet's perspective
      final walletSummary = await txRepo.getCashFlowSummary(startDate, endDate, accountId: 'acc_wallet');
      expect(walletSummary['income'], 0.0);
      expect(walletSummary['expense'], 0.0);
      expect(walletSummary['transfersIn'], 7000.0);
      expect(walletSummary['transfersOut'], 0.0);
    });
  });

  group('Reports Chart Widgets - Zero Dummy Data & Empty State Tests', () {
    testWidgets('FinancialFunnelChart displays empty state when grossInflow and actualOutflow are zero', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FinancialFunnelChart(
              grossInflow: 0.0,
              budgetAllocated: 0.0,
              actualOutflow: 0.0,
              netSavings: 0.0,
              currency: '₹',
            ),
          ),
        ),
      );

      // Must display empty state, NOT fake 100000.0 or simulated stages
      expect(find.text('No income or expense data in this period'), findsOneWidget);
      expect(find.text('₹ 1,00,000.00'), findsNothing);
      expect(find.text('Stage 1: Gross Cash Inflow'), findsNothing);
    });

    testWidgets('FinancialFunnelChart uses actual data without fallback multipliers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FinancialFunnelChart(
              grossInflow: 45000.0,
              budgetAllocated: 30000.0,
              actualOutflow: 25000.0,
              netSavings: 20000.0,
              currency: '₹',
            ),
          ),
        ),
      );

      expect(find.text('Financial Conversion Flow (Funnel Chart)'), findsOneWidget);
      expect(find.text('Stage 1: Gross Cash Inflow'), findsOneWidget);
      expect(find.text('Stage 3: Actual Realized Outflow'), findsOneWidget);
      expect(find.text('Stage 4: Net Retained Wealth'), findsOneWidget);
      expect(find.text('44.4% Conversion'), findsOneWidget);
    });

    testWidgets('MonthlyStackedBarChart displays empty state when no transactions exist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonthlyStackedBarChart(
              transactions: [],
              currency: '₹',
            ),
          ),
        ),
      );

      // Must display clean empty state instead of hardcoded 18000, 21000 sample bars
      expect(find.text('No historical monthly transaction data'), findsOneWidget);
      expect(find.text('Capital Movement (Stacked Bar Chart)'), findsNothing);
    });

    testWidgets('NetWorthAreaChart displays empty state when currentNetWorth is 0 and transactions empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NetWorthAreaChart(
              currentNetWorth: 0.0,
              transactions: [],
              currency: '₹',
            ),
          ),
        ),
      );

      expect(find.text('No net worth history available'), findsOneWidget);
      expect(find.text('Cumulative Wealth Progression (Area Chart)'), findsNothing);
    });

    testWidgets('CashFlowLineChart displays empty state when no transactions exist in window', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CashFlowLineChart(
              transactions: [],
              currency: '₹',
            ),
          ),
        ),
      );

      expect(find.text('No cash flow activity in past 7 active days'), findsOneWidget);
      expect(find.text('Cash Flow Trajectory (Line Chart)'), findsNothing);
    });
  });

  group('Reports Module - Income Breakdown & Account Flows Tests', () {
    late AppDatabase db;
    late AccountRepository accountRepo;
    late CategoryRepository categoryRepo;
    late TransactionRepository txRepo;

    setUp(() async {
      db = AppDatabase.inMemory();
      accountRepo = AccountRepository(db);
      categoryRepo = CategoryRepository(db);
      txRepo = TransactionRepository(db);

      await accountRepo.createAccount(const Account(
        id: 'acc_salary',
        name: 'Salary Account',
        type: 'bank',
        openingBalance: 20000.0,
        currentBalance: 20000.0,
      ));

      await accountRepo.createAccount(const Account(
        id: 'acc_credit',
        name: 'Credit Card',
        type: 'credit card',
        openingBalance: 0.0,
        currentBalance: -5000.0,
      ));

      await categoryRepo.createCategory(const Category(
        id: 'cat_salary',
        name: 'Salary',
        type: 'income',
        icon: 'work',
        color: '0xFF10B981',
      ));

      await categoryRepo.createCategory(const Category(
        id: 'cat_freelance',
        name: 'Freelance',
        type: 'income',
        icon: 'laptop',
        color: '0xFF3B82F6',
      ));

      await categoryRepo.createCategory(const Category(
        id: 'cat_groceries',
        name: 'Groceries',
        type: 'expense',
        icon: 'shopping_cart',
        color: '0xFFEF4444',
      ));
    });

    tearDown(() async {
      await db.close();
    });

    test('getCategoryIncomeSummary accurately aggregates income by category and filters by account', () async {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      await txRepo.createTransaction(TransactionModel(
        id: 'tx_inc_sal',
        sourceAccountId: 'acc_salary',
        categoryId: 'cat_salary',
        type: 'income',
        amount: 50000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      await txRepo.createTransaction(TransactionModel(
        id: 'tx_inc_free',
        sourceAccountId: 'acc_salary',
        categoryId: 'cat_freelance',
        type: 'income',
        amount: 15000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      // Global income breakdown
      final incomeList = await txRepo.getCategoryIncomeSummary(startDate, endDate);
      expect(incomeList.length, 2);
      expect(incomeList[0]['categoryName'], 'Salary');
      expect(incomeList[0]['amount'], 50000.0);
      expect(incomeList[1]['categoryName'], 'Freelance');
      expect(incomeList[1]['amount'], 15000.0);

      // Account filtered breakdown (matching account)
      final salAccountIncome = await txRepo.getCategoryIncomeSummary(startDate, endDate, accountId: 'acc_salary');
      expect(salAccountIncome.length, 2);

      // Account filtered breakdown (non-matching account)
      final creditAccountIncome = await txRepo.getCategoryIncomeSummary(startDate, endDate, accountId: 'acc_credit');
      expect(creditAccountIncome.isEmpty, true);
    });

    test('getAccountFlowSummary computes exact inflow, outflow, direct expense, and transfers for each account', () async {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // 1. Income of ₹40,000 to Salary Account
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_inc',
        sourceAccountId: 'acc_salary',
        categoryId: 'cat_salary',
        type: 'income',
        amount: 40000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Direct Expense of ₹8,000 from Salary Account
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_exp_sal',
        sourceAccountId: 'acc_salary',
        categoryId: 'cat_groceries',
        type: 'expense',
        amount: 8000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      // 3. Direct Expense of ₹3,000 from Credit Card
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_exp_cc',
        sourceAccountId: 'acc_credit',
        categoryId: 'cat_groceries',
        type: 'expense',
        amount: 3000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      // 4. Inter-account Transfer of ₹5,000 from Salary to Credit Card (payment)
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_trans',
        sourceAccountId: 'acc_salary',
        destinationAccountId: 'acc_credit',
        type: 'transfer',
        amount: 5000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      final flows = await txRepo.getAccountFlowSummary(startDate, endDate);
      expect(flows.length, 2);

      final salaryFlow = flows.firstWhere((f) => f['accountId'] == 'acc_salary');
      // Salary Inflow: 40,000 (direct income) + 0 (transfers in) = 40,000
      expect(salaryFlow['income'], 40000.0);
      expect(salaryFlow['transfersIn'], 0.0);
      expect(salaryFlow['totalInflow'], 40000.0);
      // Salary Outflow: 8,000 (direct expense) + 5,000 (transfer out) = 13,000
      expect(salaryFlow['expense'], 8000.0);
      expect(salaryFlow['transfersOut'], 5000.0);
      expect(salaryFlow['totalOutflow'], 13000.0);
      // Salary Net Flow: 40,000 - 13,000 = 27,000
      expect(salaryFlow['netFlow'], 27000.0);

      final creditFlow = flows.firstWhere((f) => f['accountId'] == 'acc_credit');
      // Credit Card Inflow: 0 (direct income) + 5,000 (transfers in) = 5,000
      expect(creditFlow['income'], 0.0);
      expect(creditFlow['transfersIn'], 5000.0);
      expect(creditFlow['totalInflow'], 5000.0);
      // Credit Card Outflow: 3,000 (direct expense) + 0 (transfers out) = 3,000
      expect(creditFlow['expense'], 3000.0);
      expect(creditFlow['transfersOut'], 0.0);
      expect(creditFlow['totalOutflow'], 3000.0);
      // Credit Card Net Flow: 5,000 - 3,000 = 2,000
      expect(creditFlow['netFlow'], 2000.0);
    });

    testWidgets('CategoryDonutChart and CategoryComparisonBarChart support Income customization', (tester) async {
      final sampleIncome = [
        {'categoryId': 'c1', 'categoryName': 'Salary', 'amount': 60000.0, 'categoryColor': '0xFF10B981'},
        {'categoryId': 'c2', 'categoryName': 'Bonus', 'amount': 15000.0, 'categoryColor': '0xFF3B82F6'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  CategoryDonutChart(
                    categorySpending: sampleIncome,
                    currency: '₹',
                    title: 'Income Share (Donut Chart)',
                    subtitle: 'Percentage breakdown of income categories & streams',
                  ),
                  CategoryComparisonBarChart(
                    categorySpending: sampleIncome,
                    currency: '₹',
                    title: 'Category Income (Bar Chart)',
                    subtitle: 'Cross-category income volume comparison',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Income Share (Donut Chart)'), findsOneWidget);
      expect(find.text('Category Income (Bar Chart)'), findsOneWidget);
      expect(find.text('Salary'), findsNWidgets(2));
      expect(find.text('Bonus'), findsNWidgets(2));
    });

    test('getMonthlyTrends fills gap months and computes savings, savingsRate, and momGrowth correctly', () async {
      final now = DateTime.now();
      // Month 1 (2 months ago): Income 50,000, Expense 20,000 -> Savings 30,000
      final twoMonthsAgo = DateTime(now.year, now.month - 2, 15);
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_m1_inc',
        sourceAccountId: 'acc_bank',
        type: 'income',
        amount: 50000.0,
        date: twoMonthsAgo,
        createdAt: twoMonthsAgo,
        updatedAt: twoMonthsAgo,
      ));
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_m1_exp',
        sourceAccountId: 'acc_bank',
        type: 'expense',
        amount: 20000.0,
        date: twoMonthsAgo,
        createdAt: twoMonthsAgo,
        updatedAt: twoMonthsAgo,
      ));

      // Month 2 (last month): Zero transactions (gap month)

      // Month 3 (this month): Income 60,000, Expense 15,000 -> Savings 45,000
      final thisMonth = DateTime(now.year, now.month, 5);
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_m3_inc',
        sourceAccountId: 'acc_bank',
        type: 'income',
        amount: 60000.0,
        date: thisMonth,
        createdAt: thisMonth,
        updatedAt: thisMonth,
      ));
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_m3_exp',
        sourceAccountId: 'acc_bank',
        type: 'expense',
        amount: 15000.0,
        date: thisMonth,
        createdAt: thisMonth,
        updatedAt: thisMonth,
      ));

      final trends = await txRepo.getMonthlyTrends(monthsCount: 6);
      expect(trends.length, 6);

      // Verify this month (last element in trends)
      final currentMonthTrend = trends.last;
      expect(currentMonthTrend['income'], 60000.0);
      expect(currentMonthTrend['expense'], 15000.0);
      expect(currentMonthTrend['savings'], 45000.0);
      expect(currentMonthTrend['savingsRate'], closeTo(75.0, 0.01));

      // Verify gap month (second to last)
      final gapMonthTrend = trends[trends.length - 2];
      expect(gapMonthTrend['income'], 0.0);
      expect(gapMonthTrend['expense'], 0.0);
      expect(gapMonthTrend['savings'], 0.0);
      expect(gapMonthTrend['savingsRate'], 0.0);

      // Verify two months ago (third to last)
      final twoMonthsAgoTrend = trends[trends.length - 3];
      expect(twoMonthsAgoTrend['income'], 50000.0);
      expect(twoMonthsAgoTrend['expense'], 20000.0);
      expect(twoMonthsAgoTrend['savings'], 30000.0);
      expect(twoMonthsAgoTrend['savingsRate'], closeTo(60.0, 0.01));
    });

    test('getMultiMonthCategoryTrends correctly aggregates income and expense across categories', () async {
      final catRepo = CategoryRepository(db);
      await catRepo.createCategory(const Category(
        id: 'cat_salary',
        name: 'Salary',
        type: 'income',
        color: '#10B981',
        icon: 'attach_money',
      ));
      await catRepo.createCategory(const Category(
        id: 'cat_groceries',
        name: 'Groceries',
        type: 'expense',
        color: '#EF4444',
        icon: 'shopping_cart',
      ));

      final now = DateTime.now();
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_cat_inc_1',
        sourceAccountId: 'acc_bank',
        categoryId: 'cat_salary',
        type: 'income',
        amount: 80000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));
      await txRepo.createTransaction(TransactionModel(
        id: 'tx_cat_exp_1',
        sourceAccountId: 'acc_bank',
        categoryId: 'cat_groceries',
        type: 'expense',
        amount: 12000.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      final multiCatTrends = await txRepo.getMultiMonthCategoryTrends(monthsCount: 6);
      expect(multiCatTrends.isNotEmpty, true);

      final salaryCat = multiCatTrends.firstWhere((c) => c['categoryId'] == 'cat_salary');
      expect(salaryCat['type'], 'income');
      expect(salaryCat['categoryName'], 'Salary');
      expect(salaryCat['amount'], 80000.0);

      final groceryCat = multiCatTrends.firstWhere((c) => c['categoryId'] == 'cat_groceries');
      expect(groceryCat['type'], 'expense');
      expect(groceryCat['categoryName'], 'Groceries');
      expect(groceryCat['amount'], 12000.0);
    });

    testWidgets('RunwayEstimationChart renders graph representation without text calculation formulas', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RunwayEstimationChart(
                runwayDays: 90,
                isInfiniteRunway: false,
                liquidAssets: 90000.0,
                avgDailyOutflow: 1000.0,
                currency: '₹',
              ),
            ),
          ),
        ),
      );

      // Verify Chart & Graphical elements
      expect(find.text('Financial Runway Estimation'), findsOneWidget);
      expect(find.text('Liquidity Depletion Trajectory'), findsOneWidget);
      expect(find.text('Runway Horizon Scale'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);

      // Verify Metric Badges
      expect(find.text('Available Balance'), findsOneWidget);
      expect(find.text('Avg Daily Outflow'), findsOneWidget);
      expect(find.text('Runway Horizon'), findsOneWidget);

      // Verify old text calculation formula is NOT present
      expect(find.textContaining('Calculation Methodology'), findsNothing);
      expect(find.textContaining('÷ Estimated Average Daily Outflow'), findsNothing);
    });
  });
}
