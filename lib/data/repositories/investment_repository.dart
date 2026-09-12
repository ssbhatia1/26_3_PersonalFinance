import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../models/investment.dart';

class InvestmentRepository {
  final AppDatabase _dbManager;
  final _uuid = const Uuid();

  InvestmentRepository([AppDatabase? dbManager]) : _dbManager = dbManager ?? AppDatabase.instance;

  Future<List<Investment>> getAllInvestments({bool includeDeleted = false, String? userId}) async {
    final db = await _dbManager.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (!includeDeleted) {
      whereClauses.add('i.is_deleted = 0');
    }

    // Never show investments linked to untokenized accounts
    whereClauses.add("(i.account_id IS NULL OR i.account_id IN (SELECT id FROM accounts WHERE account_token IS NOT NULL AND account_token != ''))");

    if (userId != null) {
      if (userId == 'usr_demo_primary') {
        whereClauses.add('(a.user_id = ? OR a.user_id IS NULL OR i.account_id IS NULL)');
        whereArgs.add(userId);
      } else {
        whereClauses.add('a.user_id = ?');
        whereArgs.add(userId);
      }
    }

    final where = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    final query = '''
      SELECT 
        i.*,
        a.name AS account_name
      FROM ${DatabaseTables.investments} i
      LEFT JOIN ${DatabaseTables.accounts} a ON i.account_id = a.id
      $where
      ORDER BY i.created_at DESC
    ''';
    final maps = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);
    return maps.map((m) => Investment.fromMap(m)).toList();
  }

  Future<Investment?> getInvestmentById(String id) async {
    final db = await _dbManager.database;
    final query = '''
      SELECT 
        i.*,
        a.name AS account_name
      FROM ${DatabaseTables.investments} i
      LEFT JOIN ${DatabaseTables.accounts} a ON i.account_id = a.id
      WHERE i.id = ?
      LIMIT 1
    ''';
    final maps = await db.rawQuery(query, [id]);
    if (maps.isEmpty) return null;
    return Investment.fromMap(maps.first);
  }

  Future<List<Investment>> getInvestmentsByAccount(String accountId) async {
    final db = await _dbManager.database;
    final query = '''
      SELECT 
        i.*,
        a.name AS account_name
      FROM ${DatabaseTables.investments} i
      INNER JOIN ${DatabaseTables.accounts} a ON i.account_id = a.id AND a.account_token IS NOT NULL AND a.account_token != ''
      WHERE i.account_id = ? AND i.is_deleted = 0
      ORDER BY i.created_at DESC
    ''';
    final maps = await db.rawQuery(query, [accountId]);
    return maps.map((m) => Investment.fromMap(m)).toList();
  }

  Future<void> createInvestment(Investment investment) async {
    final db = await _dbManager.database;
    final id = investment.id.isEmpty ? _uuid.v4() : investment.id;
    final item = investment.copyWith(id: id);
    await db.insert(
      DatabaseTables.investments,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateInvestment(Investment investment) async {
    final db = await _dbManager.database;
    final updated = investment.copyWith(updatedAt: DateTime.now());
    await db.update(
      DatabaseTables.investments,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [investment.id],
    );
  }

  Future<void> deleteInvestment(String id) async {
    final db = await _dbManager.database;
    await db.update(
      DatabaseTables.investments,
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>> getInvestmentSummary() async {
    final list = await getAllInvestments();
    double totalInvested = 0.0;
    double totalCurrentValue = 0.0;
    double totalExpectedReturns = 0.0;

    for (final inv in list) {
      if (inv.status == 'active') {
        totalInvested += inv.investedAmount;
        totalCurrentValue += inv.currentValue;
        totalExpectedReturns += inv.expectedReturns;
      }
    }

    final totalProfitLoss = totalCurrentValue - totalInvested;
    final totalProfitLossPercent = totalInvested > 0 ? (totalProfitLoss / totalInvested) * 100 : 0.0;

    return {
      'totalInvested': totalInvested,
      'totalCurrentValue': totalCurrentValue,
      'totalExpectedReturns': totalExpectedReturns,
      'totalProfitLoss': totalProfitLoss,
      'totalProfitLossPercent': totalProfitLossPercent,
      'isProfitable': totalProfitLoss >= 0,
      'activeCount': list.where((e) => e.status == 'active').length,
      'allCount': list.length,
    };
  }
}
