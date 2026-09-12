import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/core/database/database_tables.dart';
import 'package:personal_finance/data/models/account.dart';
import 'package:personal_finance/data/models/budget.dart';
import 'package:personal_finance/data/models/category.dart';
import 'package:personal_finance/data/models/transaction.dart';
import 'package:personal_finance/data/repositories/account_repository.dart';
import 'package:personal_finance/data/repositories/budget_repository.dart';
import 'package:personal_finance/data/repositories/category_repository.dart';
import 'package:personal_finance/data/repositories/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase testDb;
  late AccountRepository accountRepo;
  late TransactionRepository txRepo;
  late BudgetRepository budgetRepo;
  late CategoryRepository categoryRepo;

  Future<int> getRowCount(Database db, String table) async {
    final res = await db.rawQuery('SELECT COUNT(*) AS count FROM $table');
    return (res.first['count'] as num).toInt();
  }

  setUp(() async {
    testDb = AppDatabase.inMemory();
    accountRepo = AccountRepository(testDb);
    txRepo = TransactionRepository(testDb);
    budgetRepo = BudgetRepository(testDb);
    categoryRepo = CategoryRepository(testDb);
  });

  tearDown(() async {
    await testDb.close();
  });

  test('clearAllData completely wipes all financial tables without re-inserting dummy data', () async {
    final db = await testDb.database;

    // 1. Insert an account, category, transaction, and budget
    await categoryRepo.createCategory(const Category(
      id: 'cat_groceries',
      name: 'Groceries',
      type: 'expense',
      icon: 'shopping_cart',
      color: '#10B981',
    ));

    await accountRepo.createAccount(const Account(
      id: 'acc_test_custom',
      name: 'My Personal Bank',
      type: 'Bank Account',
      openingBalance: 15000,
      currentBalance: 15000,
      currency: 'INR',
    ));

    await txRepo.createTransaction(TransactionModel(
      id: 'tx_test_1',
      sourceAccountId: 'acc_test_custom',
      type: 'expense',
      amount: 450,
      date: DateTime.now(),
      description: 'Grocery shopping',
      status: 'completed',
      categoryId: 'cat_groceries',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    await budgetRepo.createBudget(Budget(
      id: 'b_test_1',
      name: 'Food Allowance',
      categoryId: 'cat_groceries',
      amountLimit: 5000,
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 30),
    ));

    // Verify records exist before clearing
    expect((await accountRepo.getAllAccounts()).isNotEmpty, isTrue);
    final countBeforeTx = await getRowCount(db, DatabaseTables.transactions);
    expect(countBeforeTx > 0, isTrue);
    final countBeforeBudget = await getRowCount(db, DatabaseTables.budgets);
    expect(countBeforeBudget > 0, isTrue);

    // 2. Execute clearAllData()
    await testDb.clearAllData();

    // 3. Verify accounts table is completely empty
    expect(await accountRepo.getAllAccounts(), isEmpty);

    // Verify transactions table is completely empty (0 rows)
    expect(await getRowCount(db, DatabaseTables.transactions), 0);

    // Verify budgets table is completely empty (0 rows)
    expect(await getRowCount(db, DatabaseTables.budgets), 0);

    // Verify attachments table is completely empty (0 rows)
    expect(await getRowCount(db, DatabaseTables.attachments), 0);

    // Verify loans table is empty (0 rows)
    expect(await getRowCount(db, DatabaseTables.loans), 0);

    // Verify recurring transactions table is empty (0 rows)
    expect(await getRowCount(db, DatabaseTables.recurringTransactions), 0);

    // Verify financial goals table is empty (0 rows)
    expect(await getRowCount(db, DatabaseTables.financialGoals), 0);

    // Verify default categories are preserved so new transactions/budgets can be categorized
    final categories = await categoryRepo.getAllCategories();
    expect(categories.isNotEmpty, isTrue);

    // Verify that NO dummy demo accounts or dummy transactions were reseeded
    final accounts = await accountRepo.getAllAccounts();
    expect(accounts.any((a) => a.id == 'acc_demo_savings'), isFalse);
    expect(accounts, isEmpty);
  });
}
