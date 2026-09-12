import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/transaction.dart';
import '../data/repositories/transaction_repository.dart';
import 'account_provider.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

class TransactionFilterState {
  final String type; // 'all', 'income', 'expense', 'transfer'
  final String? categoryId;
  final String? accountId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String searchQuery;

  const TransactionFilterState({
    this.type = 'all',
    this.categoryId,
    this.accountId,
    this.startDate,
    this.endDate,
    this.searchQuery = '',
  });

  TransactionFilterState copyWith({
    String? type,
    String? categoryId,
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) {
    return TransactionFilterState(
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class TransactionState {
  final List<TransactionModel> transactions;
  final TransactionFilterState filter;
  final Map<String, double> cashFlowSummary;
  final List<Map<String, dynamic>> categorySpending;
  final bool isLoading;
  final String? error;

  const TransactionState({
    this.transactions = const [],
    this.filter = const TransactionFilterState(),
    this.cashFlowSummary = const {'income': 0.0, 'expense': 0.0, 'savings': 0.0},
    this.categorySpending = const [],
    this.isLoading = false,
    this.error,
  });

  TransactionState copyWith({
    List<TransactionModel>? transactions,
    TransactionFilterState? filter,
    Map<String, double>? cashFlowSummary,
    List<Map<String, dynamic>>? categorySpending,
    bool? isLoading,
    String? error,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      filter: filter ?? this.filter,
      cashFlowSummary: cashFlowSummary ?? this.cashFlowSummary,
      categorySpending: categorySpending ?? this.categorySpending,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TransactionNotifier extends Notifier<TransactionState> {
  TransactionRepository get _repository => ref.read(transactionRepositoryProvider);

  @override
  TransactionState build() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    Future.microtask(loadTransactions);
    return TransactionState(
      filter: TransactionFilterState(startDate: start, endDate: end),
    );
  }

  void reset() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    state = TransactionState(
      filter: TransactionFilterState(startDate: start, endDate: end),
    );
  }

  Future<void> loadTransactions({String? userId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final activeUserId = userId ?? ref.read(authProvider).user?.id;
      final f = state.filter;
      final txList = await _repository.getTransactions(
        accountId: f.accountId,
        userId: activeUserId,
        type: f.type,
        categoryId: f.categoryId,
        startDate: f.startDate,
        endDate: f.endDate,
        searchQuery: f.searchQuery,
      );

      final now = DateTime.now();
      final summaryStart = f.startDate ?? DateTime(now.year, now.month, 1);
      final summaryEnd = f.endDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final cashFlow = await _repository.getCashFlowSummary(
        summaryStart,
        summaryEnd,
        accountId: f.accountId,
        userId: activeUserId,
      );
      final catSpending = await _repository.getCategorySpendingSummary(
        summaryStart,
        summaryEnd,
        accountId: f.accountId,
        userId: activeUserId,
      );
      if (!ref.mounted) return;

      state = state.copyWith(
        transactions: txList,
        cashFlowSummary: cashFlow,
        categorySpending: catSpending,
        isLoading: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilterType(String type) {
    state = state.copyWith(filter: state.filter.copyWith(type: type));
    loadTransactions();
  }

  void setCategoryFilter(String? categoryId) {
    state = state.copyWith(filter: state.filter.copyWith(categoryId: categoryId));
    loadTransactions();
  }

  void setAccountFilter(String? accountId) {
    state = state.copyWith(filter: state.filter.copyWith(accountId: accountId));
    loadTransactions();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(filter: state.filter.copyWith(startDate: start, endDate: end));
    loadTransactions();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(filter: state.filter.copyWith(searchQuery: query));
    loadTransactions();
  }

  void resetFilters() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    state = state.copyWith(
      filter: TransactionFilterState(startDate: start, endDate: end),
    );
    loadTransactions();
  }

  Future<void> createTransaction(TransactionModel tx) async {
    await _repository.createTransaction(tx);
    await loadTransactions();
    // Refresh accounts so balances reflect immediately
    await ref.read(accountProvider.notifier).loadAccounts();
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    await _repository.updateTransaction(tx);
    await loadTransactions();
    await ref.read(accountProvider.notifier).loadAccounts();
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _repository.deleteTransaction(transactionId);
    await loadTransactions();
    await ref.read(accountProvider.notifier).loadAccounts();
  }
}

final transactionProvider = NotifierProvider<TransactionNotifier, TransactionState>(TransactionNotifier.new);

/// Full historical transactions across all months for multi-month trends and analytics charts
final allTransactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  ref.watch(transactionProvider);
  final activeUserId = ref.watch(authProvider).user?.id;
  final repo = ref.read(transactionRepositoryProvider);
  return repo.getTransactions(userId: activeUserId);
});
