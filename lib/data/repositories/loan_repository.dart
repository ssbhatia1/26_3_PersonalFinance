import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../models/loan.dart';
import '../models/loan_repayment.dart';
import '../models/transaction.dart';
import 'transaction_repository.dart';

class LoanRepository {
  final AppDatabase _dbManager;
  final TransactionRepository _txRepo;
  final _uuid = const Uuid();

  LoanRepository([AppDatabase? dbManager, TransactionRepository? txRepo])
      : _dbManager = dbManager ?? AppDatabase.instance,
        _txRepo = txRepo ?? TransactionRepository(dbManager);

  Future<List<Loan>> getAllLoans({String? status, String? userId}) async {
    final db = await _dbManager.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (status != null) {
      whereClauses.add('l.status = ?');
      whereArgs.add(status);
    }

    if (userId != null) {
      if (userId == 'usr_demo_primary') {
        whereClauses.add('(a.user_id = ? OR a.user_id IS NULL)');
        whereArgs.add(userId);
      } else {
        whereClauses.add('a.user_id = ?');
        whereArgs.add(userId);
      }
    }

    final where = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        l.*,
        a.name AS account_name
      FROM ${DatabaseTables.loans} l
      INNER JOIN ${DatabaseTables.accounts} a ON l.account_id = a.id AND a.account_token IS NOT NULL AND a.account_token != ''
      $where
      ORDER BY l.start_date DESC
    ''';

    final rows = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);
    return rows.map((r) => Loan.fromMap(r)).toList();
  }

  Future<void> createLoan(Loan loan, {bool disburseToAccount = false}) async {
    final db = await _dbManager.database;
    await db.insert(
      DatabaseTables.loans,
      loan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (disburseToAccount && loan.principal > 0) {
      final now = DateTime.now();
      if (loan.isBorrowed) {
        // Borrowed loan disbursement: income deposited into loan.accountId
        final incCatId = await _resolveCategoryId('cat_inc_other', 'income');
        await _txRepo.createTransaction(TransactionModel(
          id: _uuid.v4(),
          sourceAccountId: loan.accountId,
          type: 'income',
          categoryId: incCatId,
          amount: loan.principal,
          date: now,
          description: 'Loan Disbursement: ${loan.borrowerLenderName}',
          payeePayer: loan.borrowerLenderName,
          paymentMethod: 'Bank Transfer',
          notes: 'Loan disbursed to account',
          createdAt: now,
          updatedAt: now,
        ));
      } else {
        // Lent loan disbursement: expense paid out from loan.accountId
        final expCatId = await _resolveCategoryId('cat_exp_other', 'expense');
        await _txRepo.createTransaction(TransactionModel(
          id: _uuid.v4(),
          sourceAccountId: loan.accountId,
          type: 'expense',
          categoryId: expCatId,
          amount: loan.principal,
          date: now,
          description: 'Money Lent: ${loan.borrowerLenderName}',
          payeePayer: loan.borrowerLenderName,
          paymentMethod: 'Bank Transfer / Cash',
          notes: 'Loan principal given to borrower',
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
  }

  Future<void> updateLoan(Loan loan) async {
    final db = await _dbManager.database;
    await db.update(
      DatabaseTables.loans,
      loan.toMap(),
      where: 'id = ?',
      whereArgs: [loan.id],
    );
  }

  Future<void> recordLoanRepayment({
    required Loan loan,
    required double paymentAmount,
    required String paymentAccountId,
    double interestAmount = 0.0,
    String? note,
  }) async {
    final db = await _dbManager.database;

    final principalPortion = (paymentAmount - interestAmount).clamp(0.0, paymentAmount);
    final newOutstanding = (loan.outstandingBalance - principalPortion).clamp(0.0, double.infinity);
    final isClosed = newOutstanding <= 0.0;

    await db.transaction((txn) async {
      // 1. Update loan outstanding balance by principal portion
      await txn.update(
        DatabaseTables.loans,
        {
          'outstanding_balance': newOutstanding,
          'status': isClosed ? 'closed' : 'active',
        },
        where: 'id = ?',
        whereArgs: [loan.id],
      );
    });

    // 2. Record transaction in accounting engine
    final now = DateTime.now();
    final primaryTxId = _uuid.v4();
    if (loan.isBorrowed) {
      final emiCategoryId = await _resolveCategoryId('cat_exp_emi', 'expense');
      // Paying back a borrowed loan: Expense from payment account
      if (interestAmount > 0 && principalPortion > 0) {
        // Principal component
        await _txRepo.createTransaction(TransactionModel(
          id: primaryTxId,
          sourceAccountId: paymentAccountId,
          type: 'expense',
          categoryId: emiCategoryId,
          amount: principalPortion,
          date: now,
          description: 'Loan Principal Repayment: ${loan.borrowerLenderName}',
          payeePayer: loan.borrowerLenderName,
          paymentMethod: 'Bank Transfer',
          notes: note != null ? '$note (Principal: $principalPortion)' : 'Principal Repayment',
          createdAt: now,
          updatedAt: now,
        ));
        // Interest component
        await _txRepo.createTransaction(TransactionModel(
          id: _uuid.v4(),
          sourceAccountId: paymentAccountId,
          type: 'expense',
          categoryId: emiCategoryId,
          amount: interestAmount,
          date: now,
          description: 'Loan Interest Expense: ${loan.borrowerLenderName}',
          payeePayer: loan.borrowerLenderName,
          paymentMethod: 'Bank Transfer',
          notes: note != null ? '$note (Interest: $interestAmount)' : 'Interest Payment',
          createdAt: now,
          updatedAt: now,
        ));
      } else {
        final tx = TransactionModel(
          id: primaryTxId,
          sourceAccountId: paymentAccountId,
          type: 'expense',
          categoryId: emiCategoryId,
          amount: paymentAmount,
          date: now,
          description: 'Loan Repayment: ${loan.borrowerLenderName}',
          payeePayer: loan.borrowerLenderName,
          paymentMethod: 'Bank Transfer',
          notes: note ?? (interestAmount > 0 ? 'Loan Interest Payment' : 'EMI / Loan Payment'),
          createdAt: now,
          updatedAt: now,
        );
        await _txRepo.createTransaction(tx);
      }
    } else {
      final incCategoryId = await _resolveCategoryId('cat_inc_other', 'income');
      // Receiving back money we lent: Income to payment account
      if (interestAmount > 0 && principalPortion > 0) {
        // Principal recovered
        await _txRepo.createTransaction(TransactionModel(
          id: primaryTxId,
          sourceAccountId: paymentAccountId,
          type: 'income',
          categoryId: incCategoryId,
          amount: principalPortion,
          date: now,
          description: 'Loan Principal Recovered: ${loan.borrowerLenderName}',
          payeePayer: loan.borrowerLenderName,
          paymentMethod: 'Bank Transfer / UPI',
          notes: note != null ? '$note (Principal: $principalPortion)' : 'Principal Received',
          createdAt: now,
          updatedAt: now,
        ));
        // Interest income
        await _txRepo.createTransaction(TransactionModel(
          id: _uuid.v4(),
          sourceAccountId: paymentAccountId,
          type: 'income',
          categoryId: incCategoryId,
          amount: interestAmount,
          date: now,
          description: 'Loan Interest Received: ${loan.borrowerLenderName}',
          payeePayer: loan.borrowerLenderName,
          paymentMethod: 'Bank Transfer / UPI',
          notes: note != null ? '$note (Interest: $interestAmount)' : 'Interest Received',
          createdAt: now,
          updatedAt: now,
        ));
      } else {
        final tx = TransactionModel(
          id: primaryTxId,
          sourceAccountId: paymentAccountId,
          type: 'income',
          categoryId: incCategoryId,
          amount: paymentAmount,
          date: now,
          description: interestAmount > 0
              ? 'Loan Interest Received: ${loan.borrowerLenderName}'
              : 'Money Received Back: ${loan.borrowerLenderName}',
          payeePayer: loan.borrowerLenderName,
          paymentMethod: 'Bank Transfer / UPI',
          notes: note ?? (interestAmount > 0 ? 'Interest Received' : 'Debt recovered'),
          createdAt: now,
          updatedAt: now,
        );
        await _txRepo.createTransaction(tx);
      }
    }

    // 3. Log to loan_repayments history table
    await db.insert(
      DatabaseTables.loanRepayments,
      {
        'id': _uuid.v4(),
        'loan_id': loan.id,
        'payment_amount': paymentAmount,
        'principal_amount': principalPortion,
        'interest_amount': interestAmount,
        'payment_date': now.toIso8601String(),
        'account_id': paymentAccountId,
        'transaction_id': primaryTxId,
        'notes': note,
        'created_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LoanRepayment>> getLoanRepayments(String loanId) async {
    final db = await _dbManager.database;
    final query = '''
      SELECT 
        lr.*,
        a.name AS account_name
      FROM ${DatabaseTables.loanRepayments} lr
      LEFT JOIN ${DatabaseTables.accounts} a ON lr.account_id = a.id
      WHERE lr.loan_id = ?
      ORDER BY lr.payment_date DESC, lr.created_at DESC
    ''';
    final rows = await db.rawQuery(query, [loanId]);
    return rows.map((r) => LoanRepayment.fromMap(r)).toList();
  }

  Future<String?> _resolveCategoryId(String preferredId, String type) async {
    final db = await _dbManager.database;
    final rows = await db.query(
      DatabaseTables.categories,
      where: 'id = ?',
      whereArgs: [preferredId],
      limit: 1,
    );
    if (rows.isNotEmpty) return preferredId;
    final fallback = await db.query(
      DatabaseTables.categories,
      where: 'type = ?',
      whereArgs: [type],
      limit: 1,
    );
    if (fallback.isNotEmpty) return fallback.first['id'] as String;
    return null;
  }

  Future<void> deleteLoan(String id) async {
    final db = await _dbManager.database;
    await db.delete(
      DatabaseTables.loans,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
