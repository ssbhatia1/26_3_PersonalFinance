import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../models/budget.dart';
import '../models/transaction.dart';

class BudgetRepository {
  final AppDatabase _dbManager;
  final _uuid = const Uuid();

  BudgetRepository([AppDatabase? dbManager]) : _dbManager = dbManager ?? AppDatabase.instance;

  /// Retrieves all active budgets overlapping with the specified month,
  /// along with their dynamically calculated spent amounts.
  Future<List<Budget>> getBudgetsForMonth(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return getBudgetsForPeriod(startOfMonth, endOfMonth);
  }

  /// Retrieves all active budgets overlapping with the given period date range
  Future<List<Budget>> getBudgetsForPeriod(DateTime start, DateTime end) async {
    final db = await _dbManager.database;

    final query = '''
      SELECT 
        b.*,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color,
        COALESCE(
          (
            SELECT SUM(t.amount) 
            FROM ${DatabaseTables.transactions} t 
            INNER JOIN ${DatabaseTables.accounts} sa ON t.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
            WHERE t.is_deleted = 0 
              AND t.type = 'expense'
              AND (
                (b.scope = 'category' AND t.category_id = b.category_id)
                OR (b.scope = 'overall')
              )
              AND t.date >= b.start_date 
              AND t.date <= b.end_date
          ), 0.0
        ) AS spent_amount
      FROM ${DatabaseTables.budgets} b
      LEFT JOIN ${DatabaseTables.categories} c ON b.category_id = c.id
      WHERE b.is_deleted = 0
        AND b.start_date <= ? AND b.end_date >= ?
      ORDER BY b.amount_limit DESC
    ''';

    final rows = await db.rawQuery(query, [end.toIso8601String(), start.toIso8601String()]);
    return rows.map((r) {
      final spent = (r['spent_amount'] as num?)?.toDouble() ?? 0.0;
      return Budget.fromMap(r, spent: spent);
    }).toList();
  }

  /// Retrieves individual expense transactions associated with this budget's category and date range
  Future<List<TransactionModel>> getTransactionsForBudget(Budget budget) async {
    final db = await _dbManager.database;
    final List<dynamic> args = [
      budget.startDate.toIso8601String(),
      budget.endDate.toIso8601String(),
    ];

    String categoryClause = '';
    if (budget.scope == 'category' && budget.categoryId != null) {
      categoryClause = 'AND t.category_id = ?';
      args.insert(0, budget.categoryId);
    }

    final query = '''
      SELECT 
        t.*,
        sa.name AS source_account_name,
        da.name AS destination_account_name,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color
      FROM ${DatabaseTables.transactions} t
      INNER JOIN ${DatabaseTables.accounts} sa ON t.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
      LEFT JOIN ${DatabaseTables.accounts} da ON t.destination_account_id = da.id
      LEFT JOIN ${DatabaseTables.categories} c ON t.category_id = c.id
      WHERE t.is_deleted = 0 
        AND t.type = 'expense'
        $categoryClause
        AND t.date >= ? 
        AND t.date <= ?
      ORDER BY t.date DESC
    ''';

    final rows = await db.rawQuery(query, args);
    return rows.map((r) => TransactionModel.fromMap(r)).toList();
  }

  /// Retrieves historical budget records for the same category/name across previous periods
  Future<List<Budget>> getBudgetHistory(Budget budget) async {
    final db = await _dbManager.database;
    final List<dynamic> args = [];
    String matchClause;

    if (budget.scope == 'category' && budget.categoryId != null) {
      matchClause = '(b.category_id = ? OR (b.name IS NOT NULL AND b.name = ?))';
      args.add(budget.categoryId);
      args.add(budget.name ?? '');
    } else {
      matchClause = "(b.scope = 'overall' OR (b.name IS NOT NULL AND b.name = ?))";
      args.add(budget.name ?? 'Overall Budget');
    }

    final query = '''
      SELECT 
        b.*,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color,
        COALESCE(
          (
            SELECT SUM(t.amount) 
            FROM ${DatabaseTables.transactions} t 
            WHERE t.is_deleted = 0 
              AND t.type = 'expense'
              AND (
                (b.scope = 'category' AND t.category_id = b.category_id)
                OR (b.scope = 'overall')
              )
              AND t.date >= b.start_date 
              AND t.date <= b.end_date
          ), 0.0
        ) AS spent_amount
      FROM ${DatabaseTables.budgets} b
      LEFT JOIN ${DatabaseTables.categories} c ON b.category_id = c.id
      WHERE b.is_deleted = 0
        AND $matchClause
      ORDER BY b.start_date DESC
    ''';

    final rows = await db.rawQuery(query, args);
    return rows.map((r) {
      final spent = (r['spent_amount'] as num?)?.toDouble() ?? 0.0;
      return Budget.fromMap(r, spent: spent);
    }).toList();
  }

  /// Retrieves all historical budgets across all categories, ordered by period
  Future<List<Budget>> getAllBudgetHistory() async {
    final db = await _dbManager.database;
    final query = '''
      SELECT 
        b.*,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color,
        COALESCE(
          (
            SELECT SUM(t.amount) 
            FROM ${DatabaseTables.transactions} t 
            WHERE t.is_deleted = 0 
              AND t.type = 'expense'
              AND (
                (b.scope = 'category' AND t.category_id = b.category_id)
                OR (b.scope = 'overall')
              )
              AND t.date >= b.start_date 
              AND t.date <= b.end_date
          ), 0.0
        ) AS spent_amount
      FROM ${DatabaseTables.budgets} b
      LEFT JOIN ${DatabaseTables.categories} c ON b.category_id = c.id
      WHERE b.is_deleted = 0
      ORDER BY b.start_date DESC, b.amount_limit DESC
    ''';
    final rows = await db.rawQuery(query);
    return rows.map((r) {
      final spent = (r['spent_amount'] as num?)?.toDouble() ?? 0.0;
      return Budget.fromMap(r, spent: spent);
    }).toList();
  }

  /// Automatically rolls forward recurring weekly, monthly, and yearly budgets into the target month/period
  /// without modifying past periods.
  Future<int> checkAndRenewRecurringBudgets(DateTime targetMonth) async {
    final db = await _dbManager.database;
    final recurringRows = await db.query(
      DatabaseTables.budgets,
      where: 'is_recurring = 1 AND is_deleted = 0',
    );

    if (recurringRows.isEmpty) return 0;

    int createdCount = 0;
    final targetMonthStart = DateTime(targetMonth.year, targetMonth.month, 1);
    final targetMonthEnd = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);

    for (final row in recurringRows) {
      final periodType = (row['period_type'] as String?) ?? 'monthly';
      final categoryId = row['category_id'] as String?;
      final scope = (row['scope'] as String?) ?? 'category';
      final name = row['name'] as String?;
      final limit = (row['amount_limit'] as num).toDouble();
      final startDate = DateTime.parse(row['start_date'] as String);

      DateTime newStart;
      DateTime newEnd;

      if (periodType == 'monthly') {
        newStart = targetMonthStart;
        newEnd = targetMonthEnd;
      } else if (periodType == 'yearly') {
        newStart = DateTime(targetMonth.year, 1, 1);
        newEnd = DateTime(targetMonth.year, 12, 31, 23, 59, 59);
      } else if (periodType == 'weekly') {
        // Find weekly start relative to targetMonth
        newStart = targetMonthStart;
        newEnd = targetMonthStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      } else {
        continue;
      }

      // If the recurring template itself is for the same or later date, don't duplicate
      if (startDate.isAtSameMomentAs(newStart) || startDate.isAfter(newStart)) {
        continue;
      }

      // Check if an instance already exists for this period
      final existing = await db.query(
        DatabaseTables.budgets,
        where: 'is_deleted = 0 AND start_date = ? AND end_date = ? AND '
            '((category_id IS NULL AND ? IS NULL) OR category_id = ?) AND scope = ?',
        whereArgs: [newStart.toIso8601String(), newEnd.toIso8601String(), categoryId, categoryId, scope],
        limit: 1,
      );

      if (existing.isEmpty) {
        final newBudget = Budget(
          id: _uuid.v4(),
          name: name,
          categoryId: categoryId,
          scope: scope,
          periodType: periodType,
          amountLimit: limit,
          startDate: newStart,
          endDate: newEnd,
          isRecurring: true,
        );
        await db.insert(DatabaseTables.budgets, newBudget.toMap());
        createdCount++;
      }
    }

    return createdCount;
  }

  Future<void> createBudget(Budget budget) async {
    final db = await _dbManager.database;
    await db.insert(
      DatabaseTables.budgets,
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateBudget(Budget budget) async {
    final db = await _dbManager.database;
    await db.update(
      DatabaseTables.budgets,
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<void> deleteBudget(String id) async {
    final db = await _dbManager.database;
    await db.update(
      DatabaseTables.budgets,
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Batch upserts category budgets for a specific month
  Future<void> batchSetBudgets(List<Budget> budgets) async {
    final db = await _dbManager.database;
    await db.transaction((txn) async {
      for (final b in budgets) {
        if (b.categoryId == null) continue;
        final existing = await txn.query(
          DatabaseTables.budgets,
          where: 'category_id = ? AND start_date = ? AND is_deleted = 0',
          whereArgs: [b.categoryId, b.startDate.toIso8601String()],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          await txn.update(
            DatabaseTables.budgets,
            {
              'amount_limit': b.amountLimit,
              'name': b.name,
              'is_recurring': b.isRecurring ? 1 : 0,
            },
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        } else {
          await txn.insert(
            DatabaseTables.budgets,
            b.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}
