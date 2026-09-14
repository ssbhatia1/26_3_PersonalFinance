import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../models/financial_goal.dart';
import '../models/transaction.dart';

class TransactionRepository {
  final AppDatabase _dbManager;
  final _uuid = const Uuid();

  TransactionRepository([AppDatabase? dbManager]) : _dbManager = dbManager ?? AppDatabase.instance;

  /// Insert a new transaction with atomic balance updates and audit logging
  Future<TransactionModel> createTransaction(TransactionModel tx) async {
    _validateTransaction(tx);

    final db = await _dbManager.database;
    await db.transaction((txn) async {
      // 1. Update Account Balances
      await _applyBalanceDelta(txn, tx, isReversal: false);

      // 2. Insert Transaction Record
      await txn.insert(
        DatabaseTables.transactions,
        tx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      // 3. Record Audit Log
      await txn.insert(
        DatabaseTables.auditLogs,
        {
          'id': _uuid.v4(),
          'entity_type': 'TRANSACTION',
          'entity_id': tx.id,
          'action': 'CREATE',
          'previous_value_json': null,
          'new_value_json': jsonEncode(tx.toMap()),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    });

    return tx;
  }

  /// Update an existing transaction with atomic reversal and re-application of balances
  Future<void> updateTransaction(TransactionModel updatedTx) async {
    _validateTransaction(updatedTx);

    final db = await _dbManager.database;
    await db.transaction((txn) async {
      // 1. Fetch existing transaction
      final existingMaps = await txn.query(
        DatabaseTables.transactions,
        where: 'id = ?',
        whereArgs: [updatedTx.id],
        limit: 1,
      );

      if (existingMaps.isEmpty) {
        throw StateError('Transaction with id ${updatedTx.id} not found.');
      }

      final oldTx = TransactionModel.fromMap(existingMaps.first);

      // 2. Reverse previous balance effects
      await _applyBalanceDelta(txn, oldTx, isReversal: true);

      // 3. Apply new balance effects
      await _applyBalanceDelta(txn, updatedTx, isReversal: false);

      // 4. Update transaction row
      await txn.update(
        DatabaseTables.transactions,
        updatedTx.toMap(),
        where: 'id = ?',
        whereArgs: [updatedTx.id],
      );

      // 5. Record Audit Log
      await txn.insert(
        DatabaseTables.auditLogs,
        {
          'id': _uuid.v4(),
          'entity_type': 'TRANSACTION',
          'entity_id': updatedTx.id,
          'action': 'UPDATE',
          'previous_value_json': jsonEncode(oldTx.toMap()),
          'new_value_json': jsonEncode(updatedTx.toMap()),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    });
  }

  /// Soft-delete a transaction and reverse its balance effect atomically
  Future<void> deleteTransaction(String transactionId) async {
    final db = await _dbManager.database;
    await db.transaction((txn) async {
      final existingMaps = await txn.query(
        DatabaseTables.transactions,
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [transactionId],
        limit: 1,
      );

      if (existingMaps.isEmpty) return;
      final tx = TransactionModel.fromMap(existingMaps.first);

      // 1. Reverse balance effects
      await _applyBalanceDelta(txn, tx, isReversal: true);

      // 2. Mark soft deleted
      await txn.update(
        DatabaseTables.transactions,
        {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      // 3. Audit log
      await txn.insert(
        DatabaseTables.auditLogs,
        {
          'id': _uuid.v4(),
          'entity_type': 'TRANSACTION',
          'entity_id': transactionId,
          'action': 'DELETE',
          'previous_value_json': jsonEncode(tx.toMap()),
          'new_value_json': null,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    });
  }

  /// Helper to adjust account balances mathematically
  Future<void> _applyBalanceDelta(DatabaseExecutor txn, TransactionModel tx, {required bool isReversal}) async {
    final sign = isReversal ? -1.0 : 1.0;
    final amount = tx.amount;

    if (tx.isIncome) {
      // Income increases source account balance
      final delta = amount * sign;
      await txn.rawUpdate(
        'UPDATE ${DatabaseTables.accounts} SET current_balance = current_balance + ? WHERE id = ?',
        [delta, tx.sourceAccountId],
      );
    } else if (tx.isExpense) {
      // Expense decreases source account balance
      final delta = -amount * sign;
      await txn.rawUpdate(
        'UPDATE ${DatabaseTables.accounts} SET current_balance = current_balance + ? WHERE id = ?',
        [delta, tx.sourceAccountId],
      );
    } else if (tx.isTransfer) {
      if (tx.destinationAccountId == null) {
        throw ArgumentError('Transfer destination account cannot be null');
      }
      // Transfer decreases source account, increases destination account
      final sourceDelta = -amount * sign;
      final destDelta = amount * sign;

      await txn.rawUpdate(
        'UPDATE ${DatabaseTables.accounts} SET current_balance = current_balance + ? WHERE id = ?',
        [sourceDelta, tx.sourceAccountId],
      );
      await txn.rawUpdate(
        'UPDATE ${DatabaseTables.accounts} SET current_balance = current_balance + ? WHERE id = ?',
        [destDelta, tx.destinationAccountId],
      );
    }

    // Sync financial goals linked to source or destination accounts
    await _syncLinkedGoals(txn, tx.sourceAccountId);
    if (tx.destinationAccountId != null) {
      await _syncLinkedGoals(txn, tx.destinationAccountId);
    }
  }

  Future<void> _syncLinkedGoals(DatabaseExecutor txn, String? accountId) async {
    if (accountId == null || accountId.isEmpty) return;

    final goalMaps = await txn.query(
      DatabaseTables.financialGoals,
      where: 'linked_account_id = ?',
      whereArgs: [accountId],
    );
    if (goalMaps.isEmpty) return;

    final accMaps = await txn.query(
      DatabaseTables.accounts,
      columns: ['current_balance'],
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (accMaps.isEmpty) return;

    final balance = (accMaps.first['current_balance'] as num?)?.toDouble() ?? 0.0;
    final newCurrent = balance < 0 ? 0.0 : balance;

    for (final map in goalMaps) {
      final goal = FinancialGoal.fromMap(map);
      final isDone = newCurrent >= goal.targetAmount;
      await txn.update(
        DatabaseTables.financialGoals,
        {
          'current_amount': newCurrent,
          'is_completed': isDone ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [goal.id],
      );
    }
  }

  void _validateTransaction(TransactionModel tx) {
    if (tx.amount <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero.');
    }
    if (tx.isTransfer) {
      if (tx.destinationAccountId == null || tx.destinationAccountId!.isEmpty) {
        throw ArgumentError('Destination account is required for transfers.');
      }
      if (tx.sourceAccountId == tx.destinationAccountId) {
        throw ArgumentError('Source and destination accounts cannot be the same.');
      }
    }
  }

  /// Query transactions with joins to account names and category metadata
  Future<List<TransactionModel>> getTransactions({
    String? accountId,
    String? userId,
    String? type,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    String sortBy = 'date_desc', // 'date_desc', 'date_asc', 'amount_desc', 'amount_asc'
    int? limit,
    int? offset,
  }) async {
    final db = await _dbManager.database;

    final whereClauses = <String>[
      't.is_deleted = 0',
      "sa.account_token IS NOT NULL AND sa.account_token != ''",
    ];
    final whereArgs = <dynamic>[];

    if (accountId != null && accountId.isNotEmpty) {
      whereClauses.add('(t.source_account_id = ? OR t.destination_account_id = ?)');
      whereArgs.addAll([accountId, accountId]);
    } else if (userId != null) {
      if (userId == 'usr_demo_primary') {
        whereClauses.add('(sa.user_id = ? OR sa.user_id IS NULL)');
        whereArgs.add(userId);
      } else {
        whereClauses.add('sa.user_id = ?');
        whereArgs.add(userId);
      }
    }
    if (type != null && type.isNotEmpty && type != 'all') {
      whereClauses.add('t.type = ?');
      whereArgs.add(type);
    }
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      whereClauses.add('t.category_id = ?');
      whereArgs.add(categoryId);
    }
    if (startDate != null) {
      whereClauses.add('t.date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('t.date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(t.description LIKE ? OR t.payee_payer LIKE ? OR t.reference_number LIKE ?)');
      final term = '%${searchQuery.trim()}%';
      whereArgs.addAll([term, term, term]);
    }

    String orderClause;
    switch (sortBy) {
      case 'date_asc':
        orderClause = 't.date ASC, t.created_at ASC';
        break;
      case 'amount_desc':
        orderClause = 't.amount DESC, t.date DESC';
        break;
      case 'amount_asc':
        orderClause = 't.amount ASC, t.date DESC';
        break;
      case 'date_desc':
      default:
        orderClause = 't.date DESC, t.created_at DESC';
        break;
    }

    final query = '''
      SELECT 
        t.*,
        sa.name AS source_account_name,
        da.name AS destination_account_name,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color,
        (SELECT COUNT(*) FROM ${DatabaseTables.attachments} a WHERE a.transaction_id = t.id) AS attachment_count
      FROM ${DatabaseTables.transactions} t
      INNER JOIN ${DatabaseTables.accounts} sa ON t.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
      LEFT JOIN ${DatabaseTables.accounts} da ON t.destination_account_id = da.id
      LEFT JOIN ${DatabaseTables.categories} c ON t.category_id = c.id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY $orderClause
      ${limit != null ? 'LIMIT $limit' : ''}
      ${offset != null ? 'OFFSET $offset' : ''}
    ''';

    final rows = await db.rawQuery(query, whereArgs);
    return rows.map((r) => TransactionModel.fromMap(r)).toList();
  }

  /// Get single transaction by ID with joined metadata and attachment count
  Future<TransactionModel?> getTransactionById(String transactionId) async {
    final db = await _dbManager.database;
    final query = '''
      SELECT 
        t.*,
        sa.name AS source_account_name,
        da.name AS destination_account_name,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color,
        (SELECT COUNT(*) FROM ${DatabaseTables.attachments} a WHERE a.transaction_id = t.id) AS attachment_count
      FROM ${DatabaseTables.transactions} t
      INNER JOIN ${DatabaseTables.accounts} sa ON t.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
      LEFT JOIN ${DatabaseTables.accounts} da ON t.destination_account_id = da.id
      LEFT JOIN ${DatabaseTables.categories} c ON t.category_id = c.id
      WHERE t.id = ? AND t.is_deleted = 0
      LIMIT 1
    ''';

    final rows = await db.rawQuery(query, [transactionId]);
    if (rows.isEmpty) return null;
    return TransactionModel.fromMap(rows.first);
  }

  /// Calculates total spending and category breakdown for a specific account
  Future<Map<String, dynamic>> getAccountSpendingSummary(
    String accountId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _dbManager.database;

    // 1. Total spending for the account in the period
    final totalResult = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) AS tx_count,
        COALESCE(SUM(amount), 0.0) AS total_spending
      FROM ${DatabaseTables.transactions}
      WHERE is_deleted = 0 
        AND source_account_id = ?
        AND source_account_id IN (SELECT id FROM accounts WHERE account_token IS NOT NULL AND account_token != '')
        AND type = 'expense'
        AND date >= ? 
        AND date <= ?
      ''',
      [accountId, startDate.toIso8601String(), endDate.toIso8601String()],
    );

    final totalSpending = (totalResult.first['total_spending'] as num?)?.toDouble() ?? 0.0;
    final txCount = (totalResult.first['tx_count'] as num?)?.toInt() ?? 0;

    // 2. Spending breakdown by category
    final categoryRows = await db.rawQuery(
      '''
      SELECT 
        c.id AS category_id,
        COALESCE(c.name, 'Uncategorized') AS category_name,
        COALESCE(c.icon, 'category') AS category_icon,
        COALESCE(c.color, '0xFF10B981') AS category_color,
        COUNT(t.id) AS category_count,
        SUM(t.amount) AS category_amount
      FROM ${DatabaseTables.transactions} t
      LEFT JOIN ${DatabaseTables.categories} c ON t.category_id = c.id
      WHERE t.is_deleted = 0 
        AND t.source_account_id = ?
        AND t.source_account_id IN (SELECT id FROM accounts WHERE account_token IS NOT NULL AND account_token != '')
        AND t.type = 'expense'
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY c.id
      ORDER BY category_amount DESC
      ''',
      [accountId, startDate.toIso8601String(), endDate.toIso8601String()],
    );

    final categoryBreakdown = categoryRows.map((r) {
      final amt = (r['category_amount'] as num).toDouble();
      final pct = totalSpending > 0 ? (amt / totalSpending * 100) : 0.0;
      return {
        'categoryId': r['category_id'] as String?,
        'categoryName': r['category_name'] as String,
        'categoryIcon': r['category_icon'] as String,
        'categoryColor': r['category_color'] as String,
        'amount': amt,
        'count': (r['category_count'] as num).toInt(),
        'percentage': pct,
      };
    }).toList();

    return {
      'totalSpending': totalSpending,
      'transactionCount': txCount,
      'averagePerTransaction': txCount > 0 ? totalSpending / txCount : 0.0,
      'categoryBreakdown': categoryBreakdown,
    };
  }

  /// Calculates spending pattern trends for a specific account over daily, weekly, monthly, or yearly periods
  Future<List<Map<String, dynamic>>> getAccountSpendingTrend(
    String accountId, {
    required String periodType, // 'daily', 'weekly', 'monthly', 'yearly'
    required DateTime referenceDate,
  }) async {
    final db = await _dbManager.database;

    if (periodType == 'daily') {
      // 7 days of the reference week (Monday through Sunday)
      final monday = referenceDate.subtract(Duration(days: referenceDate.weekday - 1));
      final start = DateTime(monday.year, monday.month, monday.day);
      final end = start.add(const Duration(days: 7));

      final rows = await db.rawQuery(
        '''
        SELECT 
          strftime('%Y-%m-%d', date) AS day_str,
          COALESCE(SUM(amount), 0.0) AS day_total
        FROM ${DatabaseTables.transactions}
        WHERE is_deleted = 0 
          AND source_account_id = ?
          AND type = 'expense'
          AND date >= ? 
          AND date < ?
        GROUP BY day_str
        ''',
        [accountId, start.toIso8601String(), end.toIso8601String()],
      );

      final mapByDay = {for (var r in rows) r['day_str'] as String: (r['day_total'] as num).toDouble()};
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final result = <Map<String, dynamic>>[];

      for (int i = 0; i < 7; i++) {
        final d = start.add(Duration(days: i));
        final key = "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
        result.add({
          'label': dayNames[i],
          'fullDate': key,
          'amount': mapByDay[key] ?? 0.0,
        });
      }
      return result;
    } else if (periodType == 'weekly') {
      // Weeks in reference month
      final firstDay = DateTime(referenceDate.year, referenceDate.month, 1);
      final lastDay = DateTime(referenceDate.year, referenceDate.month + 1, 0, 23, 59, 59);

      final result = <Map<String, dynamic>>[];
      var curStart = firstDay;
      int weekIdx = 1;

      while (curStart.isBefore(lastDay)) {
        var curEnd = curStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        if (curEnd.isAfter(lastDay)) curEnd = lastDay;

        final rows = await db.rawQuery(
          '''
          SELECT COALESCE(SUM(amount), 0.0) AS total
          FROM ${DatabaseTables.transactions}
          WHERE is_deleted = 0 
            AND source_account_id = ?
            AND type = 'expense'
            AND date >= ? 
            AND date <= ?
          ''',
          [accountId, curStart.toIso8601String(), curEnd.toIso8601String()],
        );

        final total = (rows.first['total'] as num?)?.toDouble() ?? 0.0;
        result.add({
          'label': 'W$weekIdx (${curStart.day}-${curEnd.day})',
          'shortLabel': 'W$weekIdx',
          'amount': total,
        });

        curStart = curStart.add(const Duration(days: 7));
        weekIdx++;
      }
      return result;
    } else if (periodType == 'monthly') {
      // 12 months in reference year
      final year = referenceDate.year;
      final start = DateTime(year, 1, 1);
      final end = DateTime(year, 12, 31, 23, 59, 59);

      final rows = await db.rawQuery(
        '''
        SELECT 
          strftime('%m', date) AS m_str,
          COALESCE(SUM(amount), 0.0) AS total
        FROM ${DatabaseTables.transactions}
        WHERE is_deleted = 0 
          AND source_account_id = ?
          AND type = 'expense'
          AND date >= ? 
          AND date <= ?
        GROUP BY m_str
        ''',
        [accountId, start.toIso8601String(), end.toIso8601String()],
      );

      final mapByMonth = {for (var r in rows) int.parse(r['m_str'] as String): (r['total'] as num).toDouble()};
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final result = <Map<String, dynamic>>[];

      for (int m = 1; m <= 12; m++) {
        result.add({
          'label': monthNames[m - 1],
          'month': m,
          'amount': mapByMonth[m] ?? 0.0,
        });
      }
      return result;
    } else {
      // 'yearly': 5 years ending on reference year
      final currentYear = referenceDate.year;
      final result = <Map<String, dynamic>>[];

      for (int y = currentYear - 4; y <= currentYear; y++) {
        final start = DateTime(y, 1, 1);
        final end = DateTime(y, 12, 31, 23, 59, 59);

        final rows = await db.rawQuery(
          '''
          SELECT COALESCE(SUM(amount), 0.0) AS total
          FROM ${DatabaseTables.transactions}
          WHERE is_deleted = 0 
            AND source_account_id = ?
            AND type = 'expense'
            AND date >= ? 
            AND date <= ?
          ''',
          [accountId, start.toIso8601String(), end.toIso8601String()],
        );

        final total = (rows.first['total'] as num?)?.toDouble() ?? 0.0;
        result.add({
          'label': '$y',
          'year': y,
          'amount': total,
        });
      }
      return result;
    }
  }

  /// Calculates total income, expense, and savings for a specified date range, tracking transfers separately
  Future<Map<String, double>> getCashFlowSummary(
    DateTime startDate,
    DateTime endDate, {
    String? accountId,
    String? userId,
  }) async {
    final db = await _dbManager.database;

    if (accountId != null && accountId.isNotEmpty) {
      final result = await db.rawQuery(
        '''
        SELECT 
          SUM(CASE WHEN type = 'income' AND source_account_id = ? THEN amount ELSE 0 END) AS total_income,
          SUM(CASE WHEN type = 'expense' AND source_account_id = ? THEN amount ELSE 0 END) AS total_expense,
          SUM(CASE WHEN type = 'transfer' AND source_account_id = ? THEN amount ELSE 0 END) AS transfers_out,
          SUM(CASE WHEN type = 'transfer' AND destination_account_id = ? THEN amount ELSE 0 END) AS transfers_in
        FROM ${DatabaseTables.transactions}
        WHERE is_deleted = 0 
          AND date >= ? 
          AND date <= ?
          AND (source_account_id = ? OR destination_account_id = ?)
          AND source_account_id IN (SELECT id FROM accounts WHERE account_token IS NOT NULL AND account_token != '')
        ''',
        [
          accountId,
          accountId,
          accountId,
          accountId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          accountId,
          accountId,
        ],
      );

      final row = result.first;
      final totalIncome = (row['total_income'] as num?)?.toDouble() ?? 0.0;
      final totalExpense = (row['total_expense'] as num?)?.toDouble() ?? 0.0;
      final transfersOut = (row['transfers_out'] as num?)?.toDouble() ?? 0.0;
      final transfersIn = (row['transfers_in'] as num?)?.toDouble() ?? 0.0;
      final totalTransfers = transfersOut + transfersIn;

      return {
        'income': totalIncome,
        'expense': totalExpense,
        'savings': totalIncome - totalExpense,
        'transfers': totalTransfers,
        'transfersOut': transfersOut,
        'transfersIn': transfersIn,
      };
    }

    String whereUser = '';
    final args = <dynamic>[startDate.toIso8601String(), endDate.toIso8601String()];
    if (userId != null) {
      if (userId == 'usr_demo_primary') {
        whereUser = 'AND (sa.user_id = ? OR sa.user_id IS NULL)';
        args.add(userId);
      } else {
        whereUser = 'AND sa.user_id = ?';
        args.add(userId);
      }
    }

    final result = await db.rawQuery(
      '''
      SELECT 
        SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END) AS total_income,
        SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END) AS total_expense,
        SUM(CASE WHEN t.type = 'transfer' THEN t.amount ELSE 0 END) AS total_transfers
      FROM ${DatabaseTables.transactions} t
      INNER JOIN ${DatabaseTables.accounts} sa ON t.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
      WHERE t.is_deleted = 0 
        AND t.date >= ? 
        AND t.date <= ?
        $whereUser
      ''',
      args,
    );

    final row = result.first;
    final totalIncome = (row['total_income'] as num?)?.toDouble() ?? 0.0;
    final totalExpense = (row['total_expense'] as num?)?.toDouble() ?? 0.0;
    final totalTransfers = (row['total_transfers'] as num?)?.toDouble() ?? 0.0;

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'savings': totalIncome - totalExpense,
      'transfers': totalTransfers,
      'transfersOut': totalTransfers,
      'transfersIn': totalTransfers,
    };
  }

  /// Expenses grouped by category for donut / pie charts
  Future<List<Map<String, dynamic>>> getCategorySpendingSummary(
    DateTime startDate,
    DateTime endDate, {
    String? accountId,
    String? userId,
  }) async {
    final db = await _dbManager.database;

    String whereAccount = '';
    final args = [
      startDate.toIso8601String(),
      endDate.toIso8601String(),
    ];

    if (accountId != null && accountId.isNotEmpty) {
      whereAccount = 'AND t.source_account_id = ?';
      args.add(accountId);
    } else if (userId != null) {
      if (userId == 'usr_demo_primary') {
        whereAccount = 'AND (sa.user_id = ? OR sa.user_id IS NULL)';
        args.add(userId);
      } else {
        whereAccount = 'AND sa.user_id = ?';
        args.add(userId);
      }
    }

    final rows = await db.rawQuery(
      '''
      SELECT 
        COALESCE(c.id, 'uncategorized') AS category_id,
        COALESCE(c.name, 'Uncategorized') AS category_name,
        COALESCE(c.icon, 'category') AS category_icon,
        COALESCE(c.color, '#EF4444') AS category_color,
        SUM(t.amount) AS total_amount
      FROM ${DatabaseTables.transactions} t
      INNER JOIN ${DatabaseTables.accounts} sa ON t.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
      LEFT JOIN ${DatabaseTables.categories} c ON t.category_id = c.id
      WHERE t.is_deleted = 0 
        AND t.type = 'expense'
        AND t.date >= ? 
        AND t.date <= ?
        $whereAccount
      GROUP BY category_id, category_name, category_icon, category_color
      ORDER BY total_amount DESC
      ''',
      args,
    );

    return rows.map((r) => {
      'categoryId': r['category_id'] as String,
      'categoryName': r['category_name'] as String,
      'categoryIcon': r['category_icon'] as String,
      'categoryColor': r['category_color'] as String,
      'amount': (r['total_amount'] as num).toDouble(),
    }).toList();
  }

  /// Income grouped by category for income distribution / pie charts
  Future<List<Map<String, dynamic>>> getCategoryIncomeSummary(
    DateTime startDate,
    DateTime endDate, {
    String? accountId,
    String? userId,
  }) async {
    final db = await _dbManager.database;

    String whereAccount = '';
    final args = [
      startDate.toIso8601String(),
      endDate.toIso8601String(),
    ];

    if (accountId != null && accountId.isNotEmpty) {
      whereAccount = 'AND (t.source_account_id = ? OR t.destination_account_id = ?)';
      args.addAll([accountId, accountId]);
    } else if (userId != null) {
      if (userId == 'usr_demo_primary') {
        whereAccount = 'AND (sa.user_id = ? OR sa.user_id IS NULL)';
        args.add(userId);
      } else {
        whereAccount = 'AND sa.user_id = ?';
        args.add(userId);
      }
    }

    final rows = await db.rawQuery(
      '''
      SELECT 
        COALESCE(c.id, 'uncategorized') AS category_id,
        COALESCE(c.name, 'Uncategorized') AS category_name,
        COALESCE(c.icon, 'category') AS category_icon,
        COALESCE(c.color, '#10B981') AS category_color,
        SUM(t.amount) AS total_amount
      FROM ${DatabaseTables.transactions} t
      INNER JOIN ${DatabaseTables.accounts} sa ON t.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
      LEFT JOIN ${DatabaseTables.categories} c ON t.category_id = c.id
      WHERE t.is_deleted = 0 
        AND t.type = 'income'
        AND t.date >= ? 
        AND t.date <= ?
        $whereAccount
      GROUP BY category_id, category_name, category_icon, category_color
      ORDER BY total_amount DESC
      ''',
      args,
    );

    return rows.map((r) => {
      'categoryId': r['category_id'] as String,
      'categoryName': r['category_name'] as String,
      'categoryIcon': r['category_icon'] as String,
      'categoryColor': r['category_color'] as String,
      'amount': (r['total_amount'] as num).toDouble(),
    }).toList();
  }

  /// Aggregates inflows, outflows, direct expenses, transfers, and balances across accounts
  Future<List<Map<String, dynamic>>> getAccountFlowSummary(
    DateTime startDate,
    DateTime endDate, {
    String? accountId,
  }) async {
    final db = await _dbManager.database;

    final whereClause = (accountId != null && accountId.isNotEmpty)
        ? "WHERE a.is_deleted = 0 AND a.account_token IS NOT NULL AND a.account_token != '' AND a.id = ?"
        : "WHERE a.is_deleted = 0 AND a.account_token IS NOT NULL AND a.account_token != ''";
    final args = <dynamic>[
      startDate.toIso8601String(),
      endDate.toIso8601String(),
      if (accountId != null && accountId.isNotEmpty) accountId,
    ];

    final rows = await db.rawQuery(
      '''
      SELECT 
        a.id AS account_id,
        a.name AS account_name,
        a.type AS account_type,
        a.current_balance AS current_balance,
        COALESCE(SUM(CASE WHEN t.type = 'income' AND t.source_account_id = a.id THEN t.amount ELSE 0 END), 0) AS direct_income,
        COALESCE(SUM(CASE WHEN t.type = 'expense' AND t.source_account_id = a.id THEN t.amount ELSE 0 END), 0) AS direct_expense,
        COALESCE(SUM(CASE WHEN t.type = 'transfer' AND t.destination_account_id = a.id THEN t.amount ELSE 0 END), 0) AS transfers_in,
        COALESCE(SUM(CASE WHEN t.type = 'transfer' AND t.source_account_id = a.id THEN t.amount ELSE 0 END), 0) AS transfers_out,
        COUNT(t.id) AS tx_count
      FROM ${DatabaseTables.accounts} a
      LEFT JOIN ${DatabaseTables.transactions} t 
        ON (t.source_account_id = a.id OR t.destination_account_id = a.id)
        AND t.is_deleted = 0
        AND t.date >= ?
        AND t.date <= ?
      $whereClause
      GROUP BY a.id, a.name, a.type, a.current_balance
      ORDER BY (direct_income + transfers_in + direct_expense + transfers_out) DESC, a.name ASC
      ''',
      args,
    );

    return rows.map((r) {
      final directIncome = (r['direct_income'] as num?)?.toDouble() ?? 0.0;
      final directExpense = (r['direct_expense'] as num?)?.toDouble() ?? 0.0;
      final transfersIn = (r['transfers_in'] as num?)?.toDouble() ?? 0.0;
      final transfersOut = (r['transfers_out'] as num?)?.toDouble() ?? 0.0;
      final totalInflow = directIncome + transfersIn;
      final totalOutflow = directExpense + transfersOut;
      final netFlow = totalInflow - totalOutflow;

      return {
        'accountId': r['account_id'] as String,
        'accountName': r['account_name'] as String,
        'accountType': r['account_type'] as String,
        'currentBalance': (r['current_balance'] as num?)?.toDouble() ?? 0.0,
        'income': directIncome,
        'expense': directExpense,
        'transfersIn': transfersIn,
        'transfersOut': transfersOut,
        'totalInflow': totalInflow,
        'totalOutflow': totalOutflow,
        'netFlow': netFlow,
        'txCount': (r['tx_count'] as num?)?.toInt() ?? 0,
      };
    }).toList();
  }

  /// Income grouped by payer / source
  Future<List<Map<String, dynamic>>> getIncomeBySourceSummary(DateTime startDate, DateTime endDate) async {
    final db = await _dbManager.database;

    final rows = await db.rawQuery(
      '''
      SELECT 
        COALESCE(NULLIF(t.payee_payer, ''), 'Direct Income') AS source_name,
        SUM(t.amount) AS total_amount,
        COUNT(t.id) AS tx_count
      FROM ${DatabaseTables.transactions} t
      INNER JOIN ${DatabaseTables.accounts} sa ON t.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
      WHERE t.is_deleted = 0 
        AND t.type = 'income'
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY source_name
      ORDER BY total_amount DESC
      LIMIT 10
      ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    return rows.map((r) => {
      'sourceName': r['source_name'] as String,
      'amount': (r['total_amount'] as num).toDouble(),
      'count': (r['tx_count'] as num).toInt(),
    }).toList();
  }

  /// Monthly comparison data for multi-month trends
  Future<List<Map<String, dynamic>>> getMonthlyTrends({
    int monthsCount = 6,
    String? accountId,
    String? userId,
  }) async {
    final db = await _dbManager.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - monthsCount + 1, 1);

    String whereAccount = '';
    final args = <dynamic>[
      start.toIso8601String(),
    ];

    if (accountId != null && accountId.isNotEmpty) {
      whereAccount = 'AND (t.source_account_id = ? OR t.destination_account_id = ?)';
      args.addAll([accountId, accountId]);
    } else if (userId != null) {
      if (userId == 'usr_demo_primary') {
        whereAccount = 'AND (sa.user_id = ? OR sa.user_id IS NULL)';
        args.add(userId);
      } else {
        whereAccount = 'AND sa.user_id = ?';
        args.add(userId);
      }
    }

    final rows = await db.rawQuery(
      '''
      SELECT 
        strftime('%Y-%m', t.date) AS month_str,
        SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END) AS total_income,
        SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END) AS total_expense,
        SUM(CASE WHEN t.type = 'transfer' THEN t.amount ELSE 0 END) AS total_transfers
      FROM ${DatabaseTables.transactions} t
      INNER JOIN ${DatabaseTables.accounts} sa ON t.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
      WHERE t.is_deleted = 0 AND t.date >= ?
        $whereAccount
      GROUP BY month_str
      ORDER BY month_str ASC
      ''',
      args,
    );

    final resultMap = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final monthStr = r['month_str'] as String;
      resultMap[monthStr] = {
        'income': (r['total_income'] as num?)?.toDouble() ?? 0.0,
        'expense': (r['total_expense'] as num?)?.toDouble() ?? 0.0,
        'transfers': (r['total_transfers'] as num?)?.toDouble() ?? 0.0,
      };
    }

    const monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final List<Map<String, dynamic>> trends = [];
    double? prevSavings;

    for (int i = monthsCount - 1; i >= 0; i--) {
      final dt = DateTime(now.year, now.month - i, 1);
      final monthStr = "${dt.year}-${dt.month.toString().padLeft(2, '0')}";
      final label = "${monthNames[dt.month]} '${dt.year.toString().substring(2)}";
      final data = resultMap[monthStr];
      final income = data?['income'] ?? 0.0;
      final expense = data?['expense'] ?? 0.0;
      final transfers = data?['transfers'] ?? 0.0;
      final savings = income - expense;
      final savingsRate = income > 0 ? (savings / income * 100).clamp(-100.0, 100.0) : 0.0;

      double momGrowth = 0.0;
      if (prevSavings != null) {
        if (prevSavings == 0) {
          momGrowth = savings > 0 ? 100.0 : (savings < 0 ? -100.0 : 0.0);
        } else {
          momGrowth = ((savings - prevSavings) / prevSavings.abs() * 100).clamp(-999.0, 999.0);
        }
      }
      prevSavings = savings;

      trends.add({
        'month': monthStr,
        'monthLabel': label,
        'year': dt.year,
        'monthNum': dt.month,
        'income': income,
        'expense': expense,
        'transfers': transfers,
        'savings': savings,
        'savingsRate': savingsRate,
        'momGrowth': momGrowth,
      });
    }

    return trends;
  }

  /// Multi-month category trends for income and expense
  Future<List<Map<String, dynamic>>> getMultiMonthCategoryTrends({
    int monthsCount = 6,
    String? accountId,
  }) async {
    final db = await _dbManager.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - monthsCount + 1, 1);

    final whereAccount = (accountId != null && accountId.isNotEmpty)
        ? 'AND (t.source_account_id = ? OR t.destination_account_id = ?)'
        : '';
    final args = <dynamic>[
      start.toIso8601String(),
      if (accountId != null && accountId.isNotEmpty) ...[accountId, accountId],
    ];

    final rows = await db.rawQuery(
      '''
      SELECT 
        strftime('%Y-%m', t.date) AS month_str,
        t.type AS tx_type,
        COALESCE(c.id, 'uncategorized') AS category_id,
        COALESCE(c.name, 'Uncategorized') AS category_name,
        COALESCE(c.color, '#3B82F6') AS category_color,
        COALESCE(c.icon, 'category') AS category_icon,
        SUM(t.amount) AS total_amount
      FROM ${DatabaseTables.transactions} t
      INNER JOIN ${DatabaseTables.accounts} sa ON t.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
      LEFT JOIN ${DatabaseTables.categories} c ON t.category_id = c.id
      WHERE t.is_deleted = 0 
        AND (t.type = 'income' OR t.type = 'expense')
        AND t.date >= ?
        $whereAccount
      GROUP BY month_str, t.type, category_id, category_name, category_color, category_icon
      ORDER BY month_str ASC, total_amount DESC
      ''',
      args,
    );

    return rows.map((r) => {
      'month': r['month_str'] as String,
      'type': r['tx_type'] as String,
      'categoryId': r['category_id'] as String,
      'categoryName': r['category_name'] as String,
      'categoryColor': r['category_color'] as String,
      'categoryIcon': r['category_icon'] as String,
      'amount': (r['total_amount'] as num?)?.toDouble() ?? 0.0,
    }).toList();
  }
}
