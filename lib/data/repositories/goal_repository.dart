import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../models/financial_goal.dart';
import '../models/transaction.dart';
import 'transaction_repository.dart';

class GoalRepository {
  final AppDatabase _dbManager;
  final TransactionRepository _txRepo;
  final _uuid = const Uuid();

  GoalRepository([AppDatabase? dbManager, TransactionRepository? txRepo])
      : _dbManager = dbManager ?? AppDatabase.instance,
        _txRepo = txRepo ?? TransactionRepository(dbManager);

  Future<List<FinancialGoal>> getAllGoals({String? userId}) async {
    final db = await _dbManager.database;
    String whereClause = '';
    List<dynamic>? whereArgs;

    if (userId != null) {
      whereClause = 'WHERE (a.user_id = ? OR a.user_id IS NULL OR g.linked_account_id IS NULL)';
      whereArgs = [userId];
    }

    final query = '''
      SELECT 
        g.*,
        a.name AS linked_account_name
      FROM ${DatabaseTables.financialGoals} g
      LEFT JOIN ${DatabaseTables.accounts} a ON g.linked_account_id = a.id
      $whereClause
      ORDER BY g.target_date ASC
    ''';

    final rows = await db.rawQuery(query, whereArgs);
    return rows.map((r) => FinancialGoal.fromMap(r)).toList();
  }

  Future<void> createGoal(FinancialGoal goal) async {
    final db = await _dbManager.database;
    await db.insert(
      DatabaseTables.financialGoals,
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateGoal(FinancialGoal goal) async {
    final db = await _dbManager.database;
    await db.update(
      DatabaseTables.financialGoals,
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<void> contributeToGoal(
    String goalId,
    double addAmount, {
    String? fundingAccountId,
    String? goalAccountId,
  }) async {
    final db = await _dbManager.database;
    final maps = await db.query(
      DatabaseTables.financialGoals,
      where: 'id = ?',
      whereArgs: [goalId],
      limit: 1,
    );
    if (maps.isEmpty) return;

    final goal = FinancialGoal.fromMap(maps.first);
    final newCurrent = goal.currentAmount + addAmount;
    final isDone = newCurrent >= goal.targetAmount;

    await db.update(
      DatabaseTables.financialGoals,
      {
        'current_amount': newCurrent,
        'is_completed': isDone ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [goalId],
    );

    // If funding account is provided, record accounting transaction and debit account
    if (fundingAccountId != null && fundingAccountId.isNotEmpty && addAmount > 0) {
      final now = DateTime.now();
      final targetGoalAccount = goalAccountId ?? goal.linkedAccountId;

      if (targetGoalAccount != null &&
          targetGoalAccount.isNotEmpty &&
          targetGoalAccount != fundingAccountId) {
        // Inter-account transfer from funding account to goal's dedicated account
        await _txRepo.createTransaction(TransactionModel(
          id: _uuid.v4(),
          sourceAccountId: fundingAccountId,
          destinationAccountId: targetGoalAccount,
          type: 'transfer',
          amount: addAmount,
          date: now,
          description: 'Goal Transfer: ${goal.name}',
          payeePayer: goal.name,
          paymentMethod: 'Account Transfer',
          notes: 'Goal savings contribution to ${goal.name}',
          createdAt: now,
          updatedAt: now,
        ));
      } else {
        // Expense from funding account toward goal
        await _txRepo.createTransaction(TransactionModel(
          id: _uuid.v4(),
          sourceAccountId: fundingAccountId,
          type: 'expense',
          amount: addAmount,
          date: now,
          description: 'Goal Contribution: ${goal.name}',
          payeePayer: goal.name,
          paymentMethod: 'Bank / Wallet',
          notes: 'Contribution towards goal ${goal.name}',
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
  }

  Future<void> withdrawFromGoal(
    String goalId,
    double withdrawAmount, {
    String? receivingAccountId,
  }) async {
    final db = await _dbManager.database;
    final maps = await db.query(
      DatabaseTables.financialGoals,
      where: 'id = ?',
      whereArgs: [goalId],
      limit: 1,
    );
    if (maps.isEmpty) return;

    final goal = FinancialGoal.fromMap(maps.first);
    final newCurrent = (goal.currentAmount - withdrawAmount).clamp(0.0, double.infinity);
    final isDone = newCurrent >= goal.targetAmount;

    await db.update(
      DatabaseTables.financialGoals,
      {
        'current_amount': newCurrent,
        'is_completed': isDone ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [goalId],
    );

    // If receiving account is provided, record income transaction into account
    if (receivingAccountId != null && receivingAccountId.isNotEmpty && withdrawAmount > 0) {
      final now = DateTime.now();
      final targetGoalAccount = goal.linkedAccountId;

      if (targetGoalAccount != null &&
          targetGoalAccount.isNotEmpty &&
          targetGoalAccount != receivingAccountId) {
        // Inter-account transfer from goal's account back to receiving account
        await _txRepo.createTransaction(TransactionModel(
          id: _uuid.v4(),
          sourceAccountId: targetGoalAccount,
          destinationAccountId: receivingAccountId,
          type: 'transfer',
          amount: withdrawAmount,
          date: now,
          description: 'Goal Withdrawal: ${goal.name}',
          payeePayer: goal.name,
          paymentMethod: 'Account Transfer',
          notes: 'Withdrawal from goal ${goal.name}',
          createdAt: now,
          updatedAt: now,
        ));
      } else {
        // Income to receiving account from goal withdrawal
        await _txRepo.createTransaction(TransactionModel(
          id: _uuid.v4(),
          sourceAccountId: receivingAccountId,
          type: 'income',
          amount: withdrawAmount,
          date: now,
          description: 'Goal Withdrawal: ${goal.name}',
          payeePayer: goal.name,
          paymentMethod: 'Bank / Wallet',
          notes: 'Withdrawal from goal ${goal.name}',
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
  }

  Future<void> deleteGoal(String id) async {
    final db = await _dbManager.database;
    await db.delete(
      DatabaseTables.financialGoals,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
