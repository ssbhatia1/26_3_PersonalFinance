import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../models/payment_record.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import 'transaction_repository.dart';

class RecurringRepository {
  final AppDatabase _dbManager;
  final TransactionRepository _transactionRepository;
  final _uuid = const Uuid();

  RecurringRepository([AppDatabase? dbManager, TransactionRepository? txRepo])
      : _dbManager = dbManager ?? AppDatabase.instance,
        _transactionRepository = txRepo ?? TransactionRepository(dbManager);

  Future<List<RecurringTransaction>> getAllRecurring({String? userId}) async {
    final db = await _dbManager.database;
    String whereClause = '';
    List<dynamic>? whereArgs;

    if (userId != null) {
      if (userId == 'usr_demo_primary') {
        whereClause = 'WHERE (sa.user_id = ? OR sa.user_id IS NULL)';
        whereArgs = [userId];
      } else {
        whereClause = 'WHERE sa.user_id = ?';
        whereArgs = [userId];
      }
    }

    final query = '''
      SELECT 
        rt.*,
        sa.name AS source_account_name,
        da.name AS destination_account_name,
        c.name AS category_name
      FROM ${DatabaseTables.recurringTransactions} rt
      INNER JOIN ${DatabaseTables.accounts} sa ON rt.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
      LEFT JOIN ${DatabaseTables.accounts} da ON rt.destination_account_id = da.id
      LEFT JOIN ${DatabaseTables.categories} c ON rt.category_id = c.id
      $whereClause
      ORDER BY rt.next_execution_date ASC
    ''';

    final rows = await db.rawQuery(query, whereArgs);
    return rows.map((r) => RecurringTransaction.fromMap(r)).toList();
  }

  Future<RecurringTransaction?> getRecurringById(String id) async {
    final db = await _dbManager.database;
    final query = '''
      SELECT 
        rt.*,
        sa.name AS source_account_name,
        da.name AS destination_account_name,
        c.name AS category_name
      FROM ${DatabaseTables.recurringTransactions} rt
      LEFT JOIN ${DatabaseTables.accounts} sa ON rt.source_account_id = sa.id
      LEFT JOIN ${DatabaseTables.accounts} da ON rt.destination_account_id = da.id
      LEFT JOIN ${DatabaseTables.categories} c ON rt.category_id = c.id
      WHERE rt.id = ?
      LIMIT 1
    ''';

    final rows = await db.rawQuery(query, [id]);
    if (rows.isEmpty) return null;
    return RecurringTransaction.fromMap(rows.first);
  }

  Future<void> createRecurring(RecurringTransaction item, {bool createInitialPaymentRecord = true}) async {
    final db = await _dbManager.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      await txn.insert(
        DatabaseTables.recurringTransactions,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (createInitialPaymentRecord) {
        final initialRecord = PaymentRecordModel(
          id: _uuid.v4(),
          scheduleId: item.id,
          title: item.title,
          sourceAccountId: item.sourceAccountId,
          destinationAccountId: item.destinationAccountId,
          type: item.type,
          categoryId: item.categoryId,
          amount: item.amount,
          isFlexible: item.isFlexibleAmount,
          dueDate: item.nextExecutionDate,
          status: 'scheduled',
          createdAt: now,
          updatedAt: now,
        );

        await txn.insert(
          DatabaseTables.paymentRecords,
          initialRecord.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> updateRecurring(RecurringTransaction item) async {
    final db = await _dbManager.database;
    await db.update(
      DatabaseTables.recurringTransactions,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> toggleActive(String id, bool isActive) async {
    final db = await _dbManager.database;
    await db.update(
      DatabaseTables.recurringTransactions,
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRecurring(String id) async {
    final db = await _dbManager.database;
    await db.transaction((txn) async {
      // Remove scheduled/pending payment records that have not completed
      await txn.delete(
        DatabaseTables.paymentRecords,
        where: "schedule_id = ? AND status IN ('scheduled', 'pending')",
        whereArgs: [id],
      );
      await txn.delete(
        DatabaseTables.recurringTransactions,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Query payment records with joined accounts and category details
  Future<List<PaymentRecordModel>> getPaymentRecords({
    String? scheduleId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final db = await _dbManager.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (scheduleId != null) {
      whereClauses.add('pr.schedule_id = ?');
      whereArgs.add(scheduleId);
    }
    if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
      whereClauses.add('pr.status = ?');
      whereArgs.add(status.toLowerCase());
    }
    if (startDate != null) {
      whereClauses.add('pr.due_date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('pr.due_date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    final limitSql = limit != null ? 'LIMIT $limit' : '';

    final query = '''
      SELECT 
        pr.*,
        sa.name AS source_account_name,
        da.name AS destination_account_name,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color
      FROM ${DatabaseTables.paymentRecords} pr
      INNER JOIN ${DatabaseTables.accounts} sa ON pr.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
      LEFT JOIN ${DatabaseTables.accounts} da ON pr.destination_account_id = da.id
      LEFT JOIN ${DatabaseTables.categories} c ON pr.category_id = c.id
      $whereSql
      ORDER BY pr.due_date DESC, pr.created_at DESC
      $limitSql
    ''';

    final rows = await db.rawQuery(query, whereArgs);
    return rows.map((r) => PaymentRecordModel.fromMap(r)).toList();
  }

  /// Get a single payment record by ID with joined accounts and category details
  Future<PaymentRecordModel?> getPaymentRecordById(String id) async {
    final db = await _dbManager.database;
    final query = '''
      SELECT 
        pr.*,
        sa.name AS source_account_name,
        da.name AS destination_account_name,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color
      FROM ${DatabaseTables.paymentRecords} pr
      INNER JOIN ${DatabaseTables.accounts} sa ON pr.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
      LEFT JOIN ${DatabaseTables.accounts} da ON pr.destination_account_id = da.id
      LEFT JOIN ${DatabaseTables.categories} c ON pr.category_id = c.id
      WHERE pr.id = ?
      LIMIT 1
    ''';

    final rows = await db.rawQuery(query, [id]);
    if (rows.isEmpty) return null;
    return PaymentRecordModel.fromMap(rows.first);
  }

  /// Get pending or upcoming scheduled payments
  Future<List<PaymentRecordModel>> getUpcomingAndPendingPayments({int daysAhead = 30}) async {
    final db = await _dbManager.database;
    final now = DateTime.now();
    final futureLimit = now.add(Duration(days: daysAhead));

    final query = '''
      SELECT 
        pr.*,
        sa.name AS source_account_name,
        da.name AS destination_account_name,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color
      FROM ${DatabaseTables.paymentRecords} pr
      INNER JOIN ${DatabaseTables.accounts} sa ON pr.source_account_id = sa.id AND sa.account_token IS NOT NULL AND sa.account_token != ''
      LEFT JOIN ${DatabaseTables.accounts} da ON pr.destination_account_id = da.id
      LEFT JOIN ${DatabaseTables.categories} c ON pr.category_id = c.id
      WHERE pr.status IN ('scheduled', 'pending')
        AND pr.due_date <= ?
      ORDER BY pr.due_date ASC
    ''';

    final rows = await db.rawQuery(query, [futureLimit.toIso8601String()]);
    return rows.map((r) => PaymentRecordModel.fromMap(r)).toList();
  }

  /// Execute/Complete a payment record (creates a real transaction in ledger)
  Future<TransactionModel> executePayment(
    String paymentRecordId, {
    double? overrideAmount,
    DateTime? executionDate,
  }) async {
    final db = await _dbManager.database;
    final now = executionDate ?? DateTime.now();

    final prRows = await db.query(
      DatabaseTables.paymentRecords,
      where: 'id = ?',
      whereArgs: [paymentRecordId],
      limit: 1,
    );

    if (prRows.isEmpty) {
      throw StateError('Payment record not found: $paymentRecordId');
    }

    final payment = PaymentRecordModel.fromMap(prRows.first);
    final finalAmount = overrideAmount != null && overrideAmount > 0
        ? overrideAmount
        : payment.amount;

    if (finalAmount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final newTxId = _uuid.v4();
    final newTx = TransactionModel(
      id: newTxId,
      sourceAccountId: payment.sourceAccountId,
      destinationAccountId: payment.destinationAccountId,
      type: payment.type,
      categoryId: payment.categoryId,
      amount: finalAmount,
      date: now,
      description: '${payment.title} (Scheduled Payment)',
      payeePayer: 'Scheduled',
      status: 'completed',
      isRecurringInstanceOf: payment.scheduleId,
      createdAt: now,
      updatedAt: now,
    );

    await _transactionRepository.createTransaction(newTx);

    // Update payment record to completed
    await db.update(
      DatabaseTables.paymentRecords,
      {
        'status': 'completed',
        'amount': finalAmount,
        'transaction_id': newTxId,
        'execution_date': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [paymentRecordId],
    );

    // If associated with a recurring schedule, advance it
    if (payment.scheduleId != null) {
      final schedule = await getRecurringById(payment.scheduleId!);
      if (schedule != null) {
        if (schedule.isOneTime) {
          // One-time payment finishes
          await updateRecurring(schedule.copyWith(
            isActive: false,
            lastExecutedAt: now,
          ));
        } else {
          final nextDate = schedule.calculateNextDate(schedule.nextExecutionDate);
          final shouldStayActive = schedule.endDate == null || nextDate.isBefore(schedule.endDate!);

          await updateRecurring(schedule.copyWith(
            lastExecutedAt: now,
            nextExecutionDate: nextDate,
            isActive: shouldStayActive,
          ));

          if (shouldStayActive) {
            // Queue up the next scheduled payment record
            final nextRecord = PaymentRecordModel(
              id: _uuid.v4(),
              scheduleId: schedule.id,
              title: schedule.title,
              sourceAccountId: schedule.sourceAccountId,
              destinationAccountId: schedule.destinationAccountId,
              type: schedule.type,
              categoryId: schedule.categoryId,
              amount: schedule.amount,
              isFlexible: schedule.isFlexibleAmount,
              dueDate: nextDate,
              status: 'scheduled',
              createdAt: now,
              updatedAt: now,
            );

            await db.insert(
              DatabaseTables.paymentRecords,
              nextRecord.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    }

    return newTx;
  }

  /// Undo/Reverse an executed payment record
  Future<void> undoPayment(String paymentRecordId) async {
    final db = await _dbManager.database;
    final payment = await getPaymentRecordById(paymentRecordId);
    if (payment == null) return;

    await db.transaction((txn) async {
      // 1. If a transaction was created, delete and reverse its balance effects
      if (payment.transactionId != null) {
        await _transactionRepository.deleteTransaction(payment.transactionId!);
      }

      // 2. Revert the payment record to scheduled or pending
      final revertedStatus = payment.isFlexible ? 'pending' : 'scheduled';
      await txn.update(
        DatabaseTables.paymentRecords,
        {
          'status': revertedStatus,
          'transaction_id': null,
          'execution_date': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [paymentRecordId],
      );

      // 3. If tied to a recurring schedule, revert the schedule's state
      if (payment.scheduleId != null) {
        final schedRows = await txn.query(
          DatabaseTables.recurringTransactions,
          where: 'id = ?',
          whereArgs: [payment.scheduleId],
          limit: 1,
        );

        if (schedRows.isNotEmpty) {
          final schedule = RecurringTransaction.fromMap(schedRows.first);
          if (schedule.isOneTime) {
            await txn.update(
              DatabaseTables.recurringTransactions,
              {
                'is_active': 1,
                'last_executed_at': null,
                'next_execution_date': payment.dueDate.toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [schedule.id],
            );
          } else {
            // Delete forward-queued record generated for the next cycle
            await txn.delete(
              DatabaseTables.paymentRecords,
              where: "schedule_id = ? AND status IN ('scheduled', 'pending') AND due_date > ?",
              whereArgs: [schedule.id, payment.dueDate.toIso8601String()],
            );

            // Revert schedule next execution date back to this payment's due date
            await txn.update(
              DatabaseTables.recurringTransactions,
              {
                'next_execution_date': payment.dueDate.toIso8601String(),
                'last_executed_at': null,
                'is_active': 1,
              },
              where: 'id = ?',
              whereArgs: [schedule.id],
            );
          }
        }
      }
    });
  }

  /// Update an existing payment record (e.g. from history or upcoming)
  Future<void> updatePaymentRecord(PaymentRecordModel updatedRecord) async {
    final db = await _dbManager.database;
    final now = DateTime.now();

    final existing = await getPaymentRecordById(updatedRecord.id);
    if (existing == null) {
      throw StateError('Payment record not found: ${updatedRecord.id}');
    }

    String? currentTxId = updatedRecord.transactionId ?? existing.transactionId;

    // Handle ledger transaction sync
    if (updatedRecord.isCompleted) {
      if (currentTxId != null) {
        // Update existing transaction
        final existingTx = await _transactionRepository.getTransactionById(currentTxId);
        if (existingTx != null) {
          final updatedTx = existingTx.copyWith(
            amount: updatedRecord.amount,
            sourceAccountId: updatedRecord.sourceAccountId,
            destinationAccountId: updatedRecord.destinationAccountId,
            type: updatedRecord.type,
            categoryId: updatedRecord.categoryId,
            description: '${updatedRecord.title} (Scheduled Payment)',
            date: updatedRecord.executionDate ?? updatedRecord.dueDate,
            status: 'completed',
            updatedAt: now,
          );
          await _transactionRepository.updateTransaction(updatedTx);
        }
      } else {
        // Create new ledger transaction if it was marked completed without one
        final newTxId = _uuid.v4();
        final newTx = TransactionModel(
          id: newTxId,
          sourceAccountId: updatedRecord.sourceAccountId,
          destinationAccountId: updatedRecord.destinationAccountId,
          type: updatedRecord.type,
          categoryId: updatedRecord.categoryId,
          amount: updatedRecord.amount,
          date: updatedRecord.executionDate ?? now,
          description: '${updatedRecord.title} (Scheduled Payment)',
          payeePayer: 'Scheduled',
          status: 'completed',
          isRecurringInstanceOf: updatedRecord.scheduleId,
          createdAt: now,
          updatedAt: now,
        );
        await _transactionRepository.createTransaction(newTx);
        currentTxId = newTxId;
      }
    } else {
      // If status is NOT completed, but a ledger transaction previously existed, delete/reverse it
      if (currentTxId != null) {
        await _transactionRepository.deleteTransaction(currentTxId);
        currentTxId = null;
      }
    }

    await db.update(
      DatabaseTables.paymentRecords,
      {
        'title': updatedRecord.title,
        'amount': updatedRecord.amount,
        'source_account_id': updatedRecord.sourceAccountId,
        'destination_account_id': updatedRecord.destinationAccountId,
        'type': updatedRecord.type,
        'category_id': updatedRecord.categoryId,
        'is_flexible': updatedRecord.isFlexible ? 1 : 0,
        'due_date': updatedRecord.dueDate.toIso8601String(),
        'status': updatedRecord.status,
        'transaction_id': currentTxId,
        'execution_date': updatedRecord.isCompleted
            ? (updatedRecord.executionDate ?? now).toIso8601String()
            : null,
        'notes': updatedRecord.notes,
        'failure_reason': updatedRecord.failureReason,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [updatedRecord.id],
    );
  }

  /// Skip this cycle of a scheduled payment
  Future<void> skipPayment(String paymentRecordId, {String? reason}) async {
    final db = await _dbManager.database;
    final now = DateTime.now();

    final prRows = await db.query(
      DatabaseTables.paymentRecords,
      where: 'id = ?',
      whereArgs: [paymentRecordId],
      limit: 1,
    );

    if (prRows.isEmpty) return;
    final payment = PaymentRecordModel.fromMap(prRows.first);

    await db.update(
      DatabaseTables.paymentRecords,
      {
        'status': 'skipped',
        'notes': reason ?? 'Skipped by user',
        'execution_date': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [paymentRecordId],
    );

    // If recurring, advance the schedule
    if (payment.scheduleId != null) {
      final schedule = await getRecurringById(payment.scheduleId!);
      if (schedule != null) {
        if (schedule.isOneTime) {
          await updateRecurring(schedule.copyWith(isActive: false, lastExecutedAt: now));
        } else {
          final nextDate = schedule.calculateNextDate(schedule.nextExecutionDate);
          final shouldStayActive = schedule.endDate == null || nextDate.isBefore(schedule.endDate!);

          await updateRecurring(schedule.copyWith(
            lastExecutedAt: now,
            nextExecutionDate: nextDate,
            isActive: shouldStayActive,
          ));

          if (shouldStayActive) {
            final nextRecord = PaymentRecordModel(
              id: _uuid.v4(),
              scheduleId: schedule.id,
              title: schedule.title,
              sourceAccountId: schedule.sourceAccountId,
              destinationAccountId: schedule.destinationAccountId,
              type: schedule.type,
              categoryId: schedule.categoryId,
              amount: schedule.amount,
              isFlexible: schedule.isFlexibleAmount,
              dueDate: nextDate,
              status: 'scheduled',
              createdAt: now,
              updatedAt: now,
            );
            await db.insert(
              DatabaseTables.paymentRecords,
              nextRecord.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    }
  }

  /// Mark a payment record as failed (e.g. insufficient funds or manual mark)
  Future<void> failPayment(String paymentRecordId, {required String failureReason}) async {
    final db = await _dbManager.database;
    final now = DateTime.now();

    await db.update(
      DatabaseTables.paymentRecords,
      {
        'status': 'failed',
        'failure_reason': failureReason,
        'execution_date': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [paymentRecordId],
    );
  }

  /// Process due recurring transactions and scheduled payments
  Future<int> processDueRecurringTransactions() async {
    final db = await _dbManager.database;
    final now = DateTime.now();

    // 1. Find all scheduled payment records that are due (due_date <= now)
    final duePaymentRows = await db.query(
      DatabaseTables.paymentRecords,
      where: 'status = ? AND due_date <= ?',
      whereArgs: ['scheduled', now.toIso8601String()],
    );

    int processedCount = 0;

    for (final row in duePaymentRows) {
      final payment = PaymentRecordModel.fromMap(row);
      if (payment.isFlexible) {
        // Flexible payments become 'pending' so user can review and input exact amount
        await db.update(
          DatabaseTables.paymentRecords,
          {
            'status': 'pending',
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [payment.id],
        );
        processedCount++;
      } else {
        // Fixed payments can execute automatically
        try {
          await executePayment(payment.id);
          processedCount++;
        } catch (e) {
          await failPayment(payment.id, failureReason: 'Auto-processing error: $e');
        }
      }
    }

    // 2. Catch up any active recurring schedule that doesn't have an active payment record
    final activeSchedules = await db.query(
      DatabaseTables.recurringTransactions,
      where: 'is_active = 1',
    );

    for (final sRow in activeSchedules) {
      final schedule = RecurringTransaction.fromMap(sRow);
      final existingRecords = await db.query(
        DatabaseTables.paymentRecords,
        where: "schedule_id = ? AND status IN ('scheduled', 'pending')",
        whereArgs: [schedule.id],
        limit: 1,
      );

      if (existingRecords.isEmpty) {
        // Create scheduled record for next execution date
        final isDue = schedule.nextExecutionDate.isBefore(now);
        final status = isDue
            ? (schedule.isFlexibleAmount ? 'pending' : 'scheduled')
            : 'scheduled';

        final record = PaymentRecordModel(
          id: _uuid.v4(),
          scheduleId: schedule.id,
          title: schedule.title,
          sourceAccountId: schedule.sourceAccountId,
          destinationAccountId: schedule.destinationAccountId,
          type: schedule.type,
          categoryId: schedule.categoryId,
          amount: schedule.amount,
          isFlexible: schedule.isFlexibleAmount,
          dueDate: schedule.nextExecutionDate,
          status: status,
          createdAt: now,
          updatedAt: now,
        );

        await db.insert(
          DatabaseTables.paymentRecords,
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (isDue && !schedule.isFlexibleAmount) {
          try {
            await executePayment(record.id);
            processedCount++;
          } catch (_) {}
        }
      }
    }

    return processedCount;
  }

  /// Aggregated analytics for Reports section
  Future<Map<String, dynamic>> getPaymentAnalytics({DateTime? startDate, DateTime? endDate}) async {
    final now = DateTime.now();

    final effectiveStart = startDate ?? DateTime(now.year, now.month, 1);
    final effectiveEnd = endDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final allRecords = await getPaymentRecords(
      startDate: effectiveStart,
      endDate: effectiveEnd,
    );

    double completedTotal = 0.0;
    int completedCount = 0;
    double pendingTotal = 0.0;
    int pendingCount = 0;
    double scheduledTotal = 0.0;
    int scheduledCount = 0;
    double skippedTotal = 0.0;
    int skippedCount = 0;
    double failedTotal = 0.0;
    int failedCount = 0;

    for (final p in allRecords) {
      switch (p.status.toLowerCase()) {
        case 'completed':
          completedTotal += p.amount;
          completedCount++;
          break;
        case 'pending':
          pendingTotal += p.amount;
          pendingCount++;
          break;
        case 'scheduled':
          scheduledTotal += p.amount;
          scheduledCount++;
          break;
        case 'skipped':
          skippedTotal += p.amount;
          skippedCount++;
          break;
        case 'failed':
          failedTotal += p.amount;
          failedCount++;
          break;
      }
    }

    // Active recurring commitments breakdown by category
    final activeSchedules = await getAllRecurring();
    double totalMonthlyRecurringCommitment = 0.0;
    final Map<String, double> categoryRecurringCommitment = {};

    for (final s in activeSchedules.where((s) => s.isActive)) {
      double monthlyEquivalent = s.amount;
      switch (s.frequency.toLowerCase()) {
        case 'daily':
          monthlyEquivalent = s.amount * 30;
          break;
        case 'weekly':
          monthlyEquivalent = s.amount * 4.33;
          break;
        case 'quarterly':
          monthlyEquivalent = s.amount / 3;
          break;
        case 'yearly':
          monthlyEquivalent = s.amount / 12;
          break;
        case 'once':
          monthlyEquivalent = 0.0;
          break;
        case 'custom':
          if (s.intervalUnit == 'days') {
            monthlyEquivalent = s.amount * (30 / (s.intervalCount > 0 ? s.intervalCount : 1));
          } else if (s.intervalUnit == 'weeks') {
            monthlyEquivalent = s.amount * (4.33 / (s.intervalCount > 0 ? s.intervalCount : 1));
          } else if (s.intervalUnit == 'years') {
            monthlyEquivalent = s.amount / (12 * (s.intervalCount > 0 ? s.intervalCount : 1));
          } else {
            monthlyEquivalent = s.amount / (s.intervalCount > 0 ? s.intervalCount : 1);
          }
          break;
        case 'monthly':
        default:
          monthlyEquivalent = s.amount;
          break;
      }

      totalMonthlyRecurringCommitment += monthlyEquivalent;
      final cat = s.categoryName ?? 'Other';
      categoryRecurringCommitment[cat] = (categoryRecurringCommitment[cat] ?? 0.0) + monthlyEquivalent;
    }

    final categoryCommitmentsList = categoryRecurringCommitment.entries.map((e) {
      final pct = totalMonthlyRecurringCommitment > 0
          ? (e.value / totalMonthlyRecurringCommitment * 100)
          : 0.0;
      return {
        'categoryName': e.key,
        'amount': e.value,
        'percentage': pct,
      };
    }).toList()
      ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    final upcomingForecast = await getUpcomingAndPendingPayments(daysAhead: 30);

    return {
      'completedTotal': completedTotal,
      'completedCount': completedCount,
      'pendingTotal': pendingTotal,
      'pendingCount': pendingCount,
      'scheduledTotal': scheduledTotal,
      'scheduledCount': scheduledCount,
      'skippedTotal': skippedTotal,
      'skippedCount': skippedCount,
      'failedTotal': failedTotal,
      'failedCount': failedCount,
      'totalCommittedAmount': completedTotal + pendingTotal + scheduledTotal,
      'totalMonthlyRecurringCommitment': totalMonthlyRecurringCommitment,
      'categoryCommitments': categoryCommitmentsList,
      'upcomingForecast': upcomingForecast,
      'recentRecords': allRecords.take(15).toList(),
      'statusBreakdown': {
        'completed': completedCount,
        'pending': pendingCount,
        'scheduled': scheduledCount,
        'skipped': skippedCount,
        'failed': failedCount,
      },
    };
  }
}
