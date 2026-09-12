import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/data/models/account.dart';
import 'package:personal_finance/data/models/category.dart';
import 'package:personal_finance/data/models/transaction.dart';
import 'package:personal_finance/data/repositories/account_repository.dart';
import 'package:personal_finance/data/repositories/category_repository.dart';
import 'package:personal_finance/data/repositories/transaction_repository.dart';
import 'package:personal_finance/providers/database_provider.dart';
import 'package:personal_finance/ui/reports/reports_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ReportsScreen renders clean simplified layout without 8-tab clutter', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final inMemDb = AppDatabase.inMemory();
    final txRepo = TransactionRepository(inMemDb);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemDb),
          transactionRepositoryProvider.overrideWithValue(txRepo),
        ],
        child: const MaterialApp(
          home: ReportsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Verify AppBar title and actions
    expect(find.text('Reports & Analytics'), findsOneWidget);
    expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    // 2. Verify clean period selector chips exist
    expect(find.text('This Month'), findsOneWidget);
    expect(find.text('Last Month'), findsOneWidget);
    expect(find.text('Last 3 Months'), findsOneWidget);
    expect(find.text('This Year'), findsOneWidget);

    // 3. Verify Period Cash Flow Summary card
    expect(find.text('Period Cash Flow Summary'), findsOneWidget);
    expect(find.text('Total Income'), findsOneWidget);
    expect(find.text('Total Expense'), findsOneWidget);
    expect(find.text('Net Savings'), findsOneWidget);

    // 4. Verify friendly empty state is rendered (preventing the empty black void)
    expect(find.text('No transactions in this period'), findsOneWidget);
    expect(find.text('Add Transaction'), findsOneWidget);

    // 5. Verify NO cluttered tabs exist on the screen
    expect(find.text('Loans & Debt Freedom'), findsNothing);
    expect(find.text('Goals & Savings Velocity'), findsNothing);
    expect(find.text('Recurring Commitments'), findsNothing);
    expect(find.text('Budget & Variance'), findsNothing);
  });

  testWidgets('ReportsScreen renders without overflow on compact mobile screen (360x640)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final inMemDb = AppDatabase.inMemory();
    final txRepo = TransactionRepository(inMemDb);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemDb),
          transactionRepositoryProvider.overrideWithValue(txRepo),
        ],
        child: const MaterialApp(
          home: ReportsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Reports & Analytics'), findsOneWidget);
    expect(find.text('Financial Runway Estimation'), findsOneWidget);
  });

  testWidgets('ReportsScreen renders Period Cash Flow Summary with transaction data', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final inMemDb = AppDatabase.inMemory();
    final accRepo = AccountRepository(inMemDb);
    final txRepo = TransactionRepository(inMemDb);

    await accRepo.createAccount(const Account(
      id: 'acc_main',
      name: 'Main Checking',
      type: 'bank',
      openingBalance: 10000.0,
      currentBalance: 10000.0,
    ));

    final now = DateTime.now();
    await txRepo.createTransaction(TransactionModel(
      id: 'tx_income_test',
      sourceAccountId: 'acc_main',
      type: 'income',
      amount: 50000.0,
      date: now,
      createdAt: now,
      updatedAt: now,
    ));
    await txRepo.createTransaction(TransactionModel(
      id: 'tx_expense_test',
      sourceAccountId: 'acc_main',
      type: 'expense',
      amount: 20000.0,
      date: now,
      createdAt: now,
      updatedAt: now,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemDb),
          transactionRepositoryProvider.overrideWithValue(txRepo),
        ],
        child: const MaterialApp(
          home: ReportsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Period Cash Flow Summary card
    expect(find.text('Period Cash Flow Summary'), findsOneWidget);
    expect(find.text('Total Income'), findsOneWidget);
    expect(find.text('Total Expense'), findsOneWidget);
    expect(find.text('Net Savings'), findsOneWidget);
    expect(find.textContaining('Exceptional'), findsOneWidget);
    expect(find.textContaining('Inflow Coverage'), findsOneWidget);
  });

  testWidgets('ReportsScreen Breakdown Tab supports Income vs Exp segmented toggle', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final inMemDb = AppDatabase.inMemory();
    final accRepo = AccountRepository(inMemDb);
    final catRepo = CategoryRepository(inMemDb);
    final txRepo = TransactionRepository(inMemDb);

    await accRepo.createAccount(const Account(
      id: 'acc_main',
      name: 'Main Checking',
      type: 'bank',
      openingBalance: 10000.0,
      currentBalance: 10000.0,
    ));
    await catRepo.createCategory(const Category(
      id: 'cat_salary',
      name: 'Salary',
      type: 'income',
      color: '#10B981',
      icon: 'attach_money',
    ));
    await catRepo.createCategory(const Category(
      id: 'cat_food',
      name: 'Groceries',
      type: 'expense',
      color: '#EF4444',
      icon: 'shopping_cart',
    ));

    final now = DateTime.now();
    await txRepo.createTransaction(TransactionModel(
      id: 'tx_income_test',
      sourceAccountId: 'acc_main',
      categoryId: 'cat_salary',
      type: 'income',
      amount: 45000.0,
      date: now,
      createdAt: now,
      updatedAt: now,
    ));
    await txRepo.createTransaction(TransactionModel(
      id: 'tx_expense_test',
      sourceAccountId: 'acc_main',
      categoryId: 'cat_food',
      type: 'expense',
      amount: 15000.0,
      date: now,
      createdAt: now,
      updatedAt: now,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemDb),
          transactionRepositoryProvider.overrideWithValue(txRepo),
        ],
        child: const MaterialApp(
          home: ReportsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Breakdown Tab
    await tester.tap(find.text('Breakdown & Account Flows'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify 4-way segmented toggle: Expenses, Income, Income vs Exp, Flows
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Income vs Exp'), findsOneWidget);
    expect(find.text('Flows'), findsOneWidget);

    // Tap "Income vs Exp"
    await tester.tap(find.text('Income vs Exp'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify comparative widgets render
    expect(find.text('Category Inflow vs Outflow'), findsOneWidget);
    expect(find.text('Top Income Sources'), findsOneWidget);
    expect(find.text('Top Expense Sectors'), findsOneWidget);
    expect(find.text('All Active Categories by Volume'), findsOneWidget);
  });

  testWidgets('ReportsScreen Historical Trends Tab displays Multi-Month Financial Comparison and Category Trends', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final inMemDb = AppDatabase.inMemory();
    final accRepo = AccountRepository(inMemDb);
    final catRepo = CategoryRepository(inMemDb);
    final txRepo = TransactionRepository(inMemDb);

    await accRepo.createAccount(const Account(
      id: 'acc_main',
      name: 'Main Checking',
      type: 'bank',
      openingBalance: 10000.0,
      currentBalance: 10000.0,
    ));
    await catRepo.createCategory(const Category(
      id: 'cat_salary',
      name: 'Salary',
      type: 'income',
      color: '#10B981',
      icon: 'attach_money',
    ));

    final now = DateTime.now();
    await txRepo.createTransaction(TransactionModel(
      id: 'tx_inc_1',
      sourceAccountId: 'acc_main',
      categoryId: 'cat_salary',
      type: 'income',
      amount: 50000.0,
      date: now,
      createdAt: now,
      updatedAt: now,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemDb),
          transactionRepositoryProvider.overrideWithValue(txRepo),
        ],
        child: const MaterialApp(
          home: ReportsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Historical Trends Tab
    await tester.tap(find.text('Historical Trends'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Multi-Month Comparison Trend
    expect(find.text('Multi-Month Financial Comparison'), findsOneWidget);
    expect(find.text('Past 6 Months'), findsOneWidget);
    expect(find.text('6-Mo Total Inflow'), findsOneWidget);
    expect(find.text('6-Mo Total Outflow'), findsOneWidget);
    expect(find.text('Avg Monthly Net'), findsOneWidget);

    // Verify Multi-Month Category Trends
    expect(find.text('Multi-Month Category Trends'), findsOneWidget);
    expect(find.text('Income & Expense'), findsOneWidget);
    expect(find.text('Top Inflows (6-Mo)'), findsOneWidget);
    expect(find.text('Top Outflows (6-Mo)'), findsOneWidget);
  });
}
