import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../../core/security/crypto_utils.dart';
import '../models/account.dart';
import '../models/account_adjustment.dart';

class AccountRepository {
  final AppDatabase _dbManager;
  final _uuid = const Uuid();

  AccountRepository([AppDatabase? dbManager]) : _dbManager = dbManager ?? AppDatabase.instance;

  Future<List<Account>> getAllAccounts({
    bool includeDeleted = false,
    String? userId,
    String? sessionToken,
  }) async {
    final db = await _dbManager.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (!includeDeleted) {
      whereClauses.add('is_deleted = 0');
    }

    // Strictly enforce tokenization: never return accounts without an authentic security token
    whereClauses.add("account_token IS NOT NULL AND account_token != ''");

    // Resolve userId from sessionToken if provided
    String? effectiveUserId = userId;
    if (effectiveUserId == null && sessionToken != null && sessionToken.isNotEmpty) {
      final sessionMaps = await db.query(
        DatabaseTables.userSessions,
        columns: ['user_id'],
        where: 'token = ?',
        whereArgs: [sessionToken],
        limit: 1,
      );
      if (sessionMaps.isNotEmpty) {
        effectiveUserId = sessionMaps.first['user_id'] as String?;
      }
    }

    if (effectiveUserId != null) {
      if (effectiveUserId == 'usr_demo_primary') {
        whereClauses.add('(user_id = ? OR user_id IS NULL)');
        whereArgs.add(effectiveUserId);
      } else {
        whereClauses.add('user_id = ?');
        whereArgs.add(effectiveUserId);
      }
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final maps = await db.query(
      DatabaseTables.accounts,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );
    return maps.map((m) => Account.fromMap(m)).toList();
  }

  Future<Account?> getAccountById(String id) async {
    final db = await _dbManager.database;
    final maps = await db.query(
      DatabaseTables.accounts,
      where: "id = ? AND account_token IS NOT NULL AND account_token != ''",
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Account.fromMap(maps.first);
  }

  /// Finds an account by its unique cryptographic security token or ID
  Future<Account?> getAccountByToken(String token) async {
    final db = await _dbManager.database;
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return null;
    final maps = await db.query(
      DatabaseTables.accounts,
      where: "(account_token = ? OR id = ?) AND account_token IS NOT NULL AND account_token != ''",
      whereArgs: [cleanToken, cleanToken],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Account.fromMap(maps.first);
  }

  /// Cleans all untokenized data and sample accounts across the database
  Future<void> cleanUntokenizedAccounts() async {
    await _dbManager.cleanUntokenizedData();
  }

  Future<void> createAccount(Account account) async {
    final db = await _dbManager.database;
    final token = (account.accountToken != null && account.accountToken!.isNotEmpty)
        ? account.accountToken!
        : (account.maskedReference != null && account.maskedReference!.isNotEmpty
            ? CryptoUtils.tokenizeSensitiveReference(account.maskedReference!)['surrogateToken']!
            : CryptoUtils.generateAccountToken());

    final accountWithToken = account.copyWith(accountToken: token);

    await db.insert(
      DatabaseTables.accounts,
      accountWithToken.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Record token into sensitive_tokens
    try {
      final tokenId = _uuid.v4();
      await db.insert(
        DatabaseTables.sensitiveTokens,
        {
          'token_id': tokenId,
          'user_id': account.userId ?? 'usr_demo_primary',
          'masked_value': account.maskedReference ?? '•••• ${account.id.substring(account.id.length >= 4 ? account.id.length - 4 : 0)}',
          'tokenized_surrogate': token,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (_) {}
  }

  Future<void> updateAccount(Account account) async {
    final db = await _dbManager.database;
    final token = (account.accountToken != null && account.accountToken!.isNotEmpty)
        ? account.accountToken!
        : account.token;

    final accountWithToken = account.copyWith(accountToken: token);

    await db.update(
      DatabaseTables.accounts,
      accountWithToken.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );

    // Keep sensitive_tokens synchronized
    try {
      await db.insert(
        DatabaseTables.sensitiveTokens,
        {
          'token_id': 'tok_id_${account.id}',
          'user_id': account.userId ?? 'usr_demo_primary',
          'masked_value': account.maskedReference ?? '•••• ${account.id.substring(account.id.length >= 4 ? account.id.length - 4 : 0)}',
          'tokenized_surrogate': token,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (_) {}
  }

  /// Rotates the cryptographic security token of an existing account
  Future<Account> rotateAccountToken(String accountId) async {
    final account = await getAccountById(accountId);
    if (account == null) throw Exception('Account not found');

    final newToken = CryptoUtils.generateAccountToken();
    final updated = account.copyWith(accountToken: newToken);
    await updateAccount(updated);
    return updated;
  }

  /// Get stats about an account prior to deletion (total transactions and balance)
  Future<Map<String, dynamic>> getAccountTransactionStats(String id) async {
    final db = await _dbManager.database;
    final res = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count 
      FROM ${DatabaseTables.transactions} 
      WHERE is_deleted = 0 AND (source_account_id = ? OR destination_account_id = ?)
      ''',
      [id, id],
    );
    final count = (res.first['count'] as num?)?.toInt() ?? 0;
    final account = await getAccountById(id);

    return {
      'transactionCount': count,
      'currentBalance': account?.currentBalance ?? 0.0,
      'accountName': account?.name ?? 'Account',
    };
  }

  /// Atomically soft-deletes an account and handles all associated transactions and references cleanly
  Future<void> deleteAccount(String id) async {
    final db = await _dbManager.database;

    await db.transaction((txn) async {
      final accountMaps = await txn.query(
        DatabaseTables.accounts,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (accountMaps.isEmpty) return;
      final acc = Account.fromMap(accountMaps.first);

      // 1. Fetch active transactions linked to this account
      final txRows = await txn.query(
        DatabaseTables.transactions,
        where: 'is_deleted = 0 AND (source_account_id = ? OR destination_account_id = ?)',
        whereArgs: [id, id],
      );

      // 2. Adjust paired transfer accounts to preserve ledger mathematical consistency
      for (final row in txRows) {
        final type = row['type'] as String?;
        final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
        final src = row['source_account_id'] as String?;
        final dest = row['destination_account_id'] as String?;

        if (type == 'transfer' && amount > 0) {
          if (src == id && dest != null && dest != id) {
            // Money was transferred to dest account; reverse the credit from dest
            await txn.rawUpdate(
              'UPDATE ${DatabaseTables.accounts} SET current_balance = current_balance - ? WHERE id = ?',
              [amount, dest],
            );
          } else if (dest == id && src != null && src != id) {
            // Money was transferred from src account; restore the debit to src
            await txn.rawUpdate(
              'UPDATE ${DatabaseTables.accounts} SET current_balance = current_balance + ? WHERE id = ?',
              [amount, src],
            );
          }
        }
      }

      // 3. Mark all associated transactions as deleted
      await txn.update(
        DatabaseTables.transactions,
        {
          'is_deleted': 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'source_account_id = ? OR destination_account_id = ?',
        whereArgs: [id, id],
      );

      // 4. Deactivate recurring transactions linked to this account
      await txn.update(
        DatabaseTables.recurringTransactions,
        {'is_active': 0},
        where: 'source_account_id = ? OR destination_account_id = ?',
        whereArgs: [id, id],
      );

      // 5. Unlink financial goals referencing this account
      await txn.update(
        DatabaseTables.financialGoals,
        {'linked_account_id': null},
        where: 'linked_account_id = ?',
        whereArgs: [id],
      );

      // 6. Close associated loans
      await txn.update(
        DatabaseTables.loans,
        {'status': 'closed'},
        where: 'account_id = ?',
        whereArgs: [id],
      );

      // 7. Mark the account itself as deleted
      await txn.update(
        DatabaseTables.accounts,
        {'is_deleted': 1, 'status': 'closed'},
        where: 'id = ?',
        whereArgs: [id],
      );

      // 9. Record in audit logs
      await txn.insert(
        DatabaseTables.auditLogs,
        {
          'id': _uuid.v4(),
          'entity_type': 'ACCOUNT',
          'entity_id': id,
          'action': 'DELETE',
          'previous_value_json': jsonEncode(acc.toMap()),
          'new_value_json': null,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    });
  }

  Future<void> softDeleteAccount(String id) async {
    await deleteAccount(id);
  }

  /// Calculates total net worth: Total Assets - Total Liabilities
  Future<Map<String, double>> getNetWorthSummary({String? userId}) async {
    final accounts = await getAllAccounts(userId: userId);
    double totalAssets = 0.0;
    double totalLiabilities = 0.0;
    double totalBank = 0.0;
    double totalCash = 0.0;
    double totalInvestments = 0.0;

    for (final acc in accounts) {
      final bal = acc.currentBalance;
      if (acc.isCreditCard) {
        // Any credit card balance represents liability
        totalLiabilities += bal.abs();
      } else if (acc.isLoan) {
        if (acc.type.toLowerCase().contains('lent')) {
          totalAssets += bal.abs();
        } else {
          totalLiabilities += bal.abs();
        }
      } else {
        // Standard bank/cash/investment accounts
        if (bal >= 0) {
          totalAssets += bal;
        } else {
          // Negative balance (overdraft) is liability
          totalLiabilities += bal.abs();
        }
        final t = acc.type.toLowerCase();
        if (t.contains('cash')) {
          totalCash += bal > 0 ? bal : 0;
        } else if (t.contains('bank') || t.contains('savings') || t.contains('current') || t.contains('salary') || t.contains('upi') || t.contains('wallet')) {
          totalBank += bal > 0 ? bal : 0;
        } else if (t.contains('fixed') || t.contains('deposit') || t.contains('investment')) {
          totalInvestments += bal > 0 ? bal : 0;
        }
      }
    }

    // Also include active investments from the investments table
    final db = await _dbManager.database;
    String invWhere = 'is_deleted = 0 AND status = ?';
    List<dynamic> invArgs = ['active'];

    if (userId != null) {
      if (userId == 'usr_demo_primary') {
        invWhere += ' AND (account_id IN (SELECT id FROM ${DatabaseTables.accounts} WHERE user_id = ? OR user_id IS NULL) OR account_id IS NULL)';
        invArgs.add(userId);
      } else {
        invWhere += ' AND (account_id IN (SELECT id FROM ${DatabaseTables.accounts} WHERE user_id = ?) OR account_id IS NULL)';
        invArgs.add(userId);
      }
    }

    final invMaps = await db.query(
      DatabaseTables.investments,
      where: invWhere,
      whereArgs: invArgs,
    );
    for (final inv in invMaps) {
      final curVal = (inv['current_value'] as num?)?.toDouble() ?? 0.0;
      totalAssets += curVal;
      totalInvestments += curVal;
    }

    // Also include active loans from the loans table
    String loanWhere = "l.status = 'active'";
    List<dynamic> loanArgs = [];

    if (userId != null) {
      if (userId == 'usr_demo_primary') {
        loanWhere += ' AND (a.user_id = ? OR a.user_id IS NULL OR l.account_id IS NULL)';
        loanArgs.add(userId);
      } else {
        loanWhere += ' AND (a.user_id = ? OR a.user_id IS NULL OR l.account_id IS NULL)';
        loanArgs.add(userId);
      }
    }

    final loanQuery = '''
      SELECT l.* FROM ${DatabaseTables.loans} l
      LEFT JOIN ${DatabaseTables.accounts} a ON l.account_id = a.id
      WHERE $loanWhere
    ''';

    final loanMaps = await db.rawQuery(loanQuery, loanArgs.isNotEmpty ? loanArgs : null);
    for (final lMap in loanMaps) {
      final loanType = (lMap['loan_type'] as String?)?.toLowerCase() ?? '';
      final outBal = (lMap['outstanding_balance'] as num?)?.toDouble() ?? 0.0;
      if (loanType == 'borrowed') {
        totalLiabilities += outBal;
      } else if (loanType == 'lent') {
        totalAssets += outBal;
      }
    }

    return {
      'netWorth': totalAssets - totalLiabilities,
      'totalAssets': totalAssets,
      'totalLiabilities': totalLiabilities,
      'totalBank': totalBank,
      'totalCash': totalCash,
      'totalInvestments': totalInvestments,
    };
  }

  /// Adjusts an account's balance to target newBalance without deleting/altering original transactions.
  /// Records an entry in account_adjustments and a transaction of type 'adjustment'
  /// so it appears in transaction history and reports.
  Future<AccountAdjustment> adjustAccountBalance({
    required String accountId,
    required double newBalance,
    required String reason,
    DateTime? timestamp,
  }) async {
    final db = await _dbManager.database;
    final now = timestamp ?? DateTime.now();
    final adjustmentId = _uuid.v4();
    final txId = _uuid.v4();

    return await db.transaction((txn) async {
      final accRows = await txn.query(
        DatabaseTables.accounts,
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );
      if (accRows.isEmpty) {
        throw Exception('Account with ID $accountId not found');
      }
      final acc = Account.fromMap(accRows.first);
      final prevBalance = acc.currentBalance;
      final diff = newBalance - prevBalance;
      final adjustmentType = diff >= 0 ? 'increase' : 'decrease';
      final absAmount = diff.abs();

      // 1. Update account current_balance
      await txn.update(
        DatabaseTables.accounts,
        {'current_balance': newBalance},
        where: 'id = ?',
        whereArgs: [accountId],
      );

      // If difference is effectively zero, return without creating redundant transaction/adjustment records
      if (absAmount < 0.001) {
        return AccountAdjustment(
          id: adjustmentId,
          accountId: accountId,
          previousBalance: prevBalance,
          newBalance: newBalance,
          adjustmentAmount: 0.0,
          adjustmentType: 'increase',
          reason: reason,
          createdAt: now,
          transactionId: null,
        );
      }

      // 2. Insert transaction FIRST so foreign key constraint in account_adjustments succeeds
      final formattedDiff = diff >= 0 ? '+${diff.toStringAsFixed(2)}' : '-${absAmount.toStringAsFixed(2)}';
      final txMap = {
        'id': txId,
        'source_account_id': accountId,
        'destination_account_id': null,
        'type': 'adjustment',
        'category_id': null,
        'amount': absAmount,
        'date': now.toIso8601String(),
        'description': 'Balance Adjustment ($formattedDiff)',
        'payee_payer': 'Account Adjustment',
        'payment_method': 'adjustment',
        'reference_number': null,
        'status': 'completed',
        'is_recurring_instance_of': null,
        'notes': 'Balance adjusted: $reason. Prior: $prevBalance, New: $newBalance',
        'is_reconciled': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'is_deleted': 0,
      };
      await txn.insert(
        DatabaseTables.transactions,
        txMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 3. Now insert into account_adjustments referencing the existing transaction
      final adjustment = AccountAdjustment(
        id: adjustmentId,
        accountId: accountId,
        previousBalance: prevBalance,
        newBalance: newBalance,
        adjustmentAmount: absAmount,
        adjustmentType: adjustmentType,
        reason: reason,
        createdAt: now,
        transactionId: txId,
      );
      await txn.insert(
        DatabaseTables.accountAdjustments,
        adjustment.toMap(),
      );

      return adjustment;
    });
  }

  Future<List<AccountAdjustment>> getAccountAdjustments(String accountId) async {
    final db = await _dbManager.database;
    final maps = await db.query(
      DatabaseTables.accountAdjustments,
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => AccountAdjustment.fromMap(m)).toList();
  }

  Future<List<AccountAdjustment>> getAllAdjustments() async {
    final db = await _dbManager.database;
    final maps = await db.query(
      DatabaseTables.accountAdjustments,
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => AccountAdjustment.fromMap(m)).toList();
  }
}

