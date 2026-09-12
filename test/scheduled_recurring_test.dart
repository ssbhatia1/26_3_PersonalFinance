import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/database/app_database.dart';
import 'package:personal_finance/data/models/account.dart';
import 'package:personal_finance/data/models/payment_record.dart';
import 'package:personal_finance/data/models/recurring_transaction.dart';
import 'package:personal_finance/data/repositories/account_repository.dart';
import 'package:personal_finance/data/repositories/recurring_repository.dart';
import 'package:personal_finance/data/repositories/transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecurringTransaction & PaymentRecord Models', () {
    test('RecurringTransaction format and custom intervals calculate correctly', () {
      final baseDate = DateTime(2026, 3, 10);

      final daily = RecurringTransaction(
        id: 'r_daily',
        title: 'Daily Allowance',
        sourceAccountId: 'acc_1',
        type: 'expense',
        amount: 100.0,
        frequency: 'daily',
        startDate: baseDate,
        nextExecutionDate: baseDate,
      );
      expect(daily.frequencyDisplayLabel, 'Daily');
      expect(daily.calculateNextDate(baseDate), DateTime(2026, 3, 11));

      final weekly = daily.copyWith(frequency: 'weekly');
      expect(weekly.frequencyDisplayLabel, 'Weekly');
      expect(weekly.calculateNextDate(baseDate), DateTime(2026, 3, 17));

      final monthly = daily.copyWith(frequency: 'monthly');
      expect(monthly.frequencyDisplayLabel, 'Monthly');
      expect(monthly.calculateNextDate(baseDate), DateTime(2026, 4, 10));

      final oneTime = daily.copyWith(frequency: 'once');
      expect(oneTime.isOneTime, isTrue);
      expect(oneTime.frequencyDisplayLabel, 'One-Time');
      expect(oneTime.calculateNextDate(baseDate), baseDate);

      final customWeeks = daily.copyWith(
        frequency: 'custom',
        intervalCount: 2,
        intervalUnit: 'weeks',
      );
      expect(customWeeks.isCustom, isTrue);
      expect(customWeeks.frequencyDisplayLabel, 'Every 2 weeks');
      expect(customWeeks.calculateNextDate(baseDate), DateTime(2026, 3, 24));

      final customDays = daily.copyWith(
        frequency: 'custom',
        intervalCount: 15,
        intervalUnit: 'days',
      );
      expect(customDays.frequencyDisplayLabel, 'Every 15 days');
      expect(customDays.calculateNextDate(baseDate), DateTime(2026, 3, 25));
    });

    test('RecurringTransaction flexible amount serialization works', () {
      final rec = RecurringTransaction(
        id: 'r_flex',
        title: 'Electricity Bill',
        sourceAccountId: 'acc_1',
        type: 'expense',
        amount: 2500.0,
        frequency: 'monthly',
        isFlexibleAmount: true,
        startDate: DateTime(2026, 3, 1),
        nextExecutionDate: DateTime(2026, 4, 1),
      );

      final map = rec.toMap();
      expect(map['is_flexible_amount'], 1);

      final reconstituted = RecurringTransaction.fromMap(map);
      expect(reconstituted.isFlexibleAmount, isTrue);
      expect(reconstituted.title, 'Electricity Bill');
      expect(reconstituted.amount, 2500.0);
    });

    test('PaymentRecordModel status helpers and serialization work', () {
      final now = DateTime.now();
      final record = PaymentRecordModel(
        id: 'pr_1',
        scheduleId: 's_1',
        title: 'Netflix Subscription',
        sourceAccountId: 'acc_1',
        type: 'expense',
        amount: 649.0,
        isFlexible: false,
        dueDate: now.add(const Duration(days: 5)),
        status: 'scheduled',
        createdAt: now,
        updatedAt: now,
      );

      expect(record.isScheduled, isTrue);
      expect(record.isCompleted, isFalse);
      expect(record.isPending, isFalse);

      final map = record.toMap();
      expect(map['status'], 'scheduled');
      expect(map['amount'], 649.0);

      final reconstituted = PaymentRecordModel.fromMap(map);
      expect(reconstituted.id, 'pr_1');
      expect(reconstituted.isScheduled, isTrue);
    });
  });

  group('RecurringRepository Lifecycle & Payment Tracking', () {
    late AppDatabase testDb;
    late AccountRepository accountRepo;
    late TransactionRepository txRepo;
    late RecurringRepository recurringRepo;

    setUp(() async {
      testDb = AppDatabase.inMemory();
      accountRepo = AccountRepository(testDb);
      txRepo = TransactionRepository(testDb);
      recurringRepo = RecurringRepository(testDb, txRepo);

      await accountRepo.createAccount(const Account(
        id: 'acc_main',
        name: 'Main Checking Account',
        type: 'Bank Account',
        openingBalance: 20000.0,
        currentBalance: 20000.0,
      ));
    });

    tearDown(() async {
      await testDb.close();
    });

    test('Schedule a one-time payment for a specific date and creates scheduled payment record', () async {
      final specificDate = DateTime(2026, 3, 25, 10, 0);

      final oneTime = RecurringTransaction(
        id: 'sched_onetime_1',
        title: 'Annual Property Tax',
        sourceAccountId: 'acc_main',
        type: 'expense',
        amount: 8000.0,
        frequency: 'once',
        startDate: DateTime.now(),
        nextExecutionDate: specificDate,
      );

      await recurringRepo.createRecurring(oneTime);

      final allSchedules = await recurringRepo.getAllRecurring();
      expect(allSchedules.any((s) => s.id == 'sched_onetime_1'), isTrue);

      final records = await recurringRepo.getPaymentRecords(scheduleId: 'sched_onetime_1');
      expect(records.length, 1);
      final initialRecord = records.first;
      expect(initialRecord.title, 'Annual Property Tax');
      expect(initialRecord.amount, 8000.0);
      expect(initialRecord.status, 'scheduled');
      expect(initialRecord.dueDate, specificDate);
    });

    test('Create recurring schedule with flexible amounts and custom intervals', () async {
      final schedule = RecurringTransaction(
        id: 'sched_water_flex',
        title: 'Water & Utility Bill',
        sourceAccountId: 'acc_main',
        type: 'expense',
        amount: 1500.0, // estimated
        frequency: 'custom',
        intervalCount: 2,
        intervalUnit: 'months',
        isFlexibleAmount: true,
        startDate: DateTime.now(),
        nextExecutionDate: DateTime.now().add(const Duration(days: 14)),
      );

      await recurringRepo.createRecurring(schedule);

      final fetched = await recurringRepo.getRecurringById('sched_water_flex');
      expect(fetched, isNotNull);
      expect(fetched!.isFlexibleAmount, isTrue);
      expect(fetched.intervalCount, 2);
      expect(fetched.intervalUnit, 'months');
      expect(fetched.frequencyDisplayLabel, 'Every 2 months');

      final records = await recurringRepo.getPaymentRecords(scheduleId: 'sched_water_flex');
      expect(records.length, 1);
      expect(records.first.isFlexible, isTrue);
      expect(records.first.status, 'scheduled');
    });

    test('Execute payment with flexible amount override deducts balance and logs completed payment', () async {
      final initialAcc = await accountRepo.getAccountById('acc_main');
      expect(initialAcc!.currentBalance, 20000.0);

      final schedule = RecurringTransaction(
        id: 'sched_elec',
        title: 'Electricity Bill',
        sourceAccountId: 'acc_main',
        type: 'expense',
        amount: 3000.0, // Estimated ₹3000
        frequency: 'monthly',
        isFlexibleAmount: true,
        startDate: DateTime(2026, 3, 1),
        nextExecutionDate: DateTime(2026, 3, 15),
      );

      await recurringRepo.createRecurring(schedule);

      final records = await recurringRepo.getPaymentRecords(scheduleId: 'sched_elec');
      final recordId = records.first.id;

      // Actual bill arrived at ₹3,420.50 (different from estimated ₹3,000)
      final executedTx = await recurringRepo.executePayment(recordId, overrideAmount: 3420.50);

      expect(executedTx.amount, 3420.50);

      // Verify Account Balance deducted by actual ₹3420.50
      final updatedAcc = await accountRepo.getAccountById('acc_main');
      expect(updatedAcc!.currentBalance, 20000.0 - 3420.50);

      // Verify Payment Record is marked completed with final amount and transaction ID
      final updatedRecords = await recurringRepo.getPaymentRecords(scheduleId: 'sched_elec');
      final completedRecord = updatedRecords.firstWhere((r) => r.id == recordId);
      expect(completedRecord.status, 'completed');
      expect(completedRecord.amount, 3420.50);
      expect(completedRecord.transactionId, executedTx.id);
      expect(completedRecord.executionDate, isNotNull);

      // Verify next cycle was scheduled
      final nextRecord = updatedRecords.firstWhere((r) => r.id != recordId);
      expect(nextRecord.status, 'scheduled');
      expect(nextRecord.dueDate, DateTime(2026, 4, 15));
    });

    test('Skip payment advances schedule without deducting account balance', () async {
      final initialAcc = await accountRepo.getAccountById('acc_main');
      final initialBalance = initialAcc!.currentBalance;

      final schedule = RecurringTransaction(
        id: 'sched_gym',
        title: 'Gym Membership',
        sourceAccountId: 'acc_main',
        type: 'expense',
        amount: 2000.0,
        frequency: 'monthly',
        startDate: DateTime(2026, 3, 1),
        nextExecutionDate: DateTime(2026, 3, 10),
      );

      await recurringRepo.createRecurring(schedule);
      final records = await recurringRepo.getPaymentRecords(scheduleId: 'sched_gym');
      final recordId = records.first.id;

      await recurringRepo.skipPayment(recordId, reason: 'Traveling this month');

      // Verify balance is unchanged
      final accAfter = await accountRepo.getAccountById('acc_main');
      expect(accAfter!.currentBalance, initialBalance);

      // Verify payment marked skipped
      final history = await recurringRepo.getPaymentRecords(scheduleId: 'sched_gym');
      final skipped = history.firstWhere((r) => r.id == recordId);
      expect(skipped.status, 'skipped');
      expect(skipped.notes, 'Traveling this month');

      // Verify next cycle scheduled
      final next = history.firstWhere((r) => r.id != recordId);
      expect(next.status, 'scheduled');
      expect(next.dueDate, DateTime(2026, 4, 10));
    });

    test('Fail payment marks payment record as failed with reason', () async {
      final schedule = RecurringTransaction(
        id: 'sched_emi',
        title: 'Car Loan EMI',
        sourceAccountId: 'acc_main',
        type: 'expense',
        amount: 15000.0,
        frequency: 'monthly',
        startDate: DateTime.now(),
        nextExecutionDate: DateTime.now(),
      );

      await recurringRepo.createRecurring(schedule);
      final records = await recurringRepo.getPaymentRecords(scheduleId: 'sched_emi');
      final recordId = records.first.id;

      await recurringRepo.failPayment(recordId, failureReason: 'Account auto-debit rejected: insufficient funds');

      final updated = await recurringRepo.getPaymentRecords(scheduleId: 'sched_emi');
      final failed = updated.firstWhere((r) => r.id == recordId);
      expect(failed.status, 'failed');
      expect(failed.failureReason, contains('insufficient funds'));
    });

    test('processDueRecurringTransactions flags due flexible payments as pending and executes fixed', () async {
      final now = DateTime.now();

      // Fixed schedule due now
      final fixedDue = RecurringTransaction(
        id: 'sched_fixed_due',
        title: 'Office Rent',
        sourceAccountId: 'acc_main',
        type: 'expense',
        amount: 5000.0,
        frequency: 'monthly',
        startDate: now.subtract(const Duration(days: 30)),
        nextExecutionDate: now.subtract(const Duration(hours: 1)),
      );

      // Flexible schedule due now
      final flexDue = RecurringTransaction(
        id: 'sched_flex_due',
        title: 'Broadband Fiber Bill',
        sourceAccountId: 'acc_main',
        type: 'expense',
        amount: 1200.0,
        frequency: 'monthly',
        isFlexibleAmount: true,
        startDate: now.subtract(const Duration(days: 30)),
        nextExecutionDate: now.subtract(const Duration(hours: 1)),
      );

      await recurringRepo.createRecurring(fixedDue);
      await recurringRepo.createRecurring(flexDue);

      final count = await recurringRepo.processDueRecurringTransactions();
      expect(count, greaterThanOrEqualTo(2));

      // Fixed due payment should be completed
      final fixedRecords = await recurringRepo.getPaymentRecords(scheduleId: 'sched_fixed_due');
      expect(fixedRecords.any((r) => r.status == 'completed'), isTrue);

      // Flexible due payment should be pending (ready for user to confirm actual amount)
      final flexRecords = await recurringRepo.getPaymentRecords(scheduleId: 'sched_flex_due');
      expect(flexRecords.any((r) => r.status == 'pending'), isTrue);
    });

    test('getPaymentAnalytics calculates accurate payment history, commitments, and status breakdown', () async {
      final analytics = await recurringRepo.getPaymentAnalytics();

      expect(analytics.containsKey('completedTotal'), isTrue);
      expect(analytics.containsKey('pendingTotal'), isTrue);
      expect(analytics.containsKey('scheduledTotal'), isTrue);
      expect(analytics.containsKey('skippedTotal'), isTrue);
      expect(analytics.containsKey('failedTotal'), isTrue);
      expect(analytics.containsKey('statusBreakdown'), isTrue);
      expect(analytics.containsKey('categoryCommitments'), isTrue);
      expect(analytics.containsKey('upcomingForecast'), isTrue);

      final breakdown = analytics['statusBreakdown'] as Map<String, dynamic>;
      expect(breakdown.containsKey('completed'), isTrue);
      expect(breakdown.containsKey('pending'), isTrue);
      expect(breakdown.containsKey('scheduled'), isTrue);
      expect(breakdown.containsKey('skipped'), isTrue);
      expect(breakdown.containsKey('failed'), isTrue);
    });
  });
}
