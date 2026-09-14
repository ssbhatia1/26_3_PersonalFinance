import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/payment_record.dart';
import '../data/models/recurring_transaction.dart';
import '../data/repositories/recurring_repository.dart';
import 'account_provider.dart';
import 'auth_provider.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';

class RecurringNotifier extends Notifier<AsyncValue<List<RecurringTransaction>>> {
  RecurringRepository get _repo => ref.read(recurringRepositoryProvider);

  @override
  AsyncValue<List<RecurringTransaction>> build() {
    Future.microtask(loadRecurring);
    return const AsyncValue.loading();
  }

  void reset() {
    state = const AsyncValue.data([]);
  }

  Future<void> loadRecurring({String? userId}) async {
    try {
      final activeUserId = userId ?? ref.read(authProvider).user?.id;
      final list = await _repo.getAllRecurring(userId: activeUserId);
      if (!ref.mounted) return;
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (!ref.mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createRecurring(RecurringTransaction item, {bool createInitialPaymentRecord = true}) async {
    await _repo.createRecurring(item, createInitialPaymentRecord: createInitialPaymentRecord);
    await loadRecurring();
    _refreshRelatedProviders();
  }

  Future<void> updateRecurring(RecurringTransaction item) async {
    await _repo.updateRecurring(item);
    await loadRecurring();
    _refreshRelatedProviders();
  }

  Future<void> toggleActive(String id, bool isActive) async {
    await _repo.toggleActive(id, isActive);
    await loadRecurring();
    _refreshRelatedProviders();
  }

  Future<void> deleteRecurring(String id) async {
    await _repo.deleteRecurring(id);
    await loadRecurring();
    _refreshRelatedProviders();
  }

  Future<void> executePayment(String paymentRecordId, {double? overrideAmount, DateTime? executionDate}) async {
    await _repo.executePayment(paymentRecordId, overrideAmount: overrideAmount, executionDate: executionDate);
    await loadRecurring();
    await ref.read(transactionProvider.notifier).loadTransactions();
    await ref.read(accountProvider.notifier).loadAccounts();
    _refreshRelatedProviders();
  }

  Future<void> undoPayment(String paymentRecordId) async {
    await _repo.undoPayment(paymentRecordId);
    await loadRecurring();
    await ref.read(transactionProvider.notifier).loadTransactions();
    await ref.read(accountProvider.notifier).loadAccounts();
    _refreshRelatedProviders();
  }

  Future<void> updatePaymentRecord(PaymentRecordModel record) async {
    await _repo.updatePaymentRecord(record);
    await loadRecurring();
    await ref.read(transactionProvider.notifier).loadTransactions();
    await ref.read(accountProvider.notifier).loadAccounts();
    _refreshRelatedProviders();
  }

  Future<void> skipPayment(String paymentRecordId, {String? reason}) async {
    await _repo.skipPayment(paymentRecordId, reason: reason);
    await loadRecurring();
    _refreshRelatedProviders();
  }

  Future<void> failPayment(String paymentRecordId, {required String failureReason}) async {
    await _repo.failPayment(paymentRecordId, failureReason: failureReason);
    await loadRecurring();
    _refreshRelatedProviders();
  }

  Future<int> processDue() async {
    final count = await _repo.processDueRecurringTransactions();
    await loadRecurring();
    if (count > 0) {
      await ref.read(transactionProvider.notifier).loadTransactions();
      await ref.read(accountProvider.notifier).loadAccounts();
    }
    _refreshRelatedProviders();
    return count;
  }

  void _refreshRelatedProviders() {
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(upcomingPaymentsProvider);
    ref.invalidate(paymentRecordsProvider);
    ref.invalidate(paymentAnalyticsProvider);
  }
}

final recurringProvider =
    NotifierProvider<RecurringNotifier, AsyncValue<List<RecurringTransaction>>>(RecurringNotifier.new);

/// Provider for upcoming and pending payment records
final upcomingPaymentsProvider = FutureProvider<List<PaymentRecordModel>>((ref) async {
  final repo = ref.watch(recurringRepositoryProvider);
  return repo.getUpcomingAndPendingPayments(daysAhead: 30);
});

/// Provider for payment records with status filter
final paymentRecordsProvider = FutureProvider.family<List<PaymentRecordModel>, String>((ref, statusFilter) async {
  final repo = ref.watch(recurringRepositoryProvider);
  return repo.getPaymentRecords(status: statusFilter == 'all' ? null : statusFilter);
});

/// Provider for Payment & Recurring Analytics in Reports
final paymentAnalyticsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, periodKey) async {
  final repo = ref.watch(recurringRepositoryProvider);
  final now = DateTime.now();

  DateTime start;
  DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

  switch (periodKey) {
    case 'last_month':
      start = DateTime(now.year, now.month - 1, 1);
      end = DateTime(now.year, now.month, 0, 23, 59, 59);
      break;
    case 'last_3_months':
      start = DateTime(now.year, now.month - 2, 1);
      break;
    case 'last_6_months':
      start = DateTime(now.year, now.month - 5, 1);
      break;
    case 'ytd':
      start = DateTime(now.year, 1, 1);
      break;
    case 'this_month':
    default:
      start = DateTime(now.year, now.month, 1);
      break;
  }

  return repo.getPaymentAnalytics(startDate: start, endDate: end);
});
