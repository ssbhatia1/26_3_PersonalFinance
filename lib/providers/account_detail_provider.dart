import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/account.dart';
import '../data/models/category.dart';
import '../data/models/transaction.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/transaction_repository.dart';
import 'account_provider.dart';
import 'database_provider.dart';

class AccountDetailState {
  final Account? account;
  final List<TransactionModel> transactions;
  final List<Category> categories;

  // Transaction Filters & Sorting
  final String searchQuery;
  final String typeFilter; // 'all', 'expense', 'income', 'transfer'
  final String? categoryIdFilter;
  final DateTime? startDateFilter;
  final DateTime? endDateFilter;
  final String sortBy; // 'date_desc', 'date_asc', 'amount_desc', 'amount_asc'

  // Transaction Summary
  final double totalCredits;
  final double totalDebits;
  final double netImpact;

  // Spending Module
  final String spendingPeriodType; // 'daily', 'weekly', 'monthly', 'yearly'
  final DateTime spendingReferenceDate;
  final DateTime spendingStartDate;
  final DateTime spendingEndDate;
  final double totalSpending;
  final int spendingTxCount;
  final double averagePerTransaction;
  final List<Map<String, dynamic>> categoryBreakdown;
  final List<Map<String, dynamic>> spendingTrend;

  final bool isLoading;
  final String? error;

  const AccountDetailState({
    this.account,
    this.transactions = const [],
    this.categories = const [],
    this.searchQuery = '',
    this.typeFilter = 'all',
    this.categoryIdFilter,
    this.startDateFilter,
    this.endDateFilter,
    this.sortBy = 'date_desc',
    this.totalCredits = 0.0,
    this.totalDebits = 0.0,
    this.netImpact = 0.0,
    this.spendingPeriodType = 'monthly',
    required this.spendingReferenceDate,
    required this.spendingStartDate,
    required this.spendingEndDate,
    this.totalSpending = 0.0,
    this.spendingTxCount = 0,
    this.averagePerTransaction = 0.0,
    this.categoryBreakdown = const [],
    this.spendingTrend = const [],
    this.isLoading = false,
    this.error,
  });

  AccountDetailState copyWith({
    Account? account,
    List<TransactionModel>? transactions,
    List<Category>? categories,
    String? searchQuery,
    String? typeFilter,
    String? categoryIdFilter,
    bool clearCategoryIdFilter = false,
    DateTime? startDateFilter,
    bool clearStartDateFilter = false,
    DateTime? endDateFilter,
    bool clearEndDateFilter = false,
    String? sortBy,
    double? totalCredits,
    double? totalDebits,
    double? netImpact,
    String? spendingPeriodType,
    DateTime? spendingReferenceDate,
    DateTime? spendingStartDate,
    DateTime? spendingEndDate,
    double? totalSpending,
    int? spendingTxCount,
    double? averagePerTransaction,
    List<Map<String, dynamic>>? categoryBreakdown,
    List<Map<String, dynamic>>? spendingTrend,
    bool? isLoading,
    String? error,
  }) {
    return AccountDetailState(
      account: account ?? this.account,
      transactions: transactions ?? this.transactions,
      categories: categories ?? this.categories,
      searchQuery: searchQuery ?? this.searchQuery,
      typeFilter: typeFilter ?? this.typeFilter,
      categoryIdFilter: clearCategoryIdFilter ? null : (categoryIdFilter ?? this.categoryIdFilter),
      startDateFilter: clearStartDateFilter ? null : (startDateFilter ?? this.startDateFilter),
      endDateFilter: clearEndDateFilter ? null : (endDateFilter ?? this.endDateFilter),
      sortBy: sortBy ?? this.sortBy,
      totalCredits: totalCredits ?? this.totalCredits,
      totalDebits: totalDebits ?? this.totalDebits,
      netImpact: netImpact ?? this.netImpact,
      spendingPeriodType: spendingPeriodType ?? this.spendingPeriodType,
      spendingReferenceDate: spendingReferenceDate ?? this.spendingReferenceDate,
      spendingStartDate: spendingStartDate ?? this.spendingStartDate,
      spendingEndDate: spendingEndDate ?? this.spendingEndDate,
      totalSpending: totalSpending ?? this.totalSpending,
      spendingTxCount: spendingTxCount ?? this.spendingTxCount,
      averagePerTransaction: averagePerTransaction ?? this.averagePerTransaction,
      categoryBreakdown: categoryBreakdown ?? this.categoryBreakdown,
      spendingTrend: spendingTrend ?? this.spendingTrend,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AccountDetailNotifier extends Notifier<AccountDetailState> {
  final String accountId;
  AccountDetailNotifier(this.accountId);

  AccountRepository get _accountRepo => ref.read(accountRepositoryProvider);
  TransactionRepository get _txRepo => ref.read(transactionRepositoryProvider);
  CategoryRepository get _categoryRepo => ref.read(categoryRepositoryProvider);

  @override
  AccountDetailState build() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final initialState = AccountDetailState(
      spendingReferenceDate: now,
      spendingStartDate: start,
      spendingEndDate: end,
      isLoading: true,
    );

    Future.microtask(loadAll);
    return initialState;
  }

  /// Helper to calculate balance impact of a transaction specifically on this account
  static double getBalanceImpact(TransactionModel tx, String accountId) {
    if (tx.isIncome) {
      return tx.sourceAccountId == accountId ? tx.amount : 0.0;
    } else if (tx.isExpense) {
      return tx.sourceAccountId == accountId ? -tx.amount : 0.0;
    } else if (tx.isTransfer) {
      if (tx.sourceAccountId == accountId) {
        return -tx.amount;
      } else if (tx.destinationAccountId == accountId) {
        return tx.amount;
      }
    } else if (tx.isReversal || tx.isAdjustment) {
      return tx.sourceAccountId == accountId ? tx.amount : 0.0;
    }
    return 0.0;
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final account = await _accountRepo.getAccountById(accountId);
      final categories = await _categoryRepo.getAllCategories();

      // Load filtered & sorted transactions
      final txList = await _txRepo.getTransactions(
        accountId: accountId,
        type: state.typeFilter,
        categoryId: state.categoryIdFilter,
        startDate: state.startDateFilter,
        endDate: state.endDateFilter,
        searchQuery: state.searchQuery,
        sortBy: state.sortBy,
      );

      // Compute credit / debit summary for filtered transactions
      double credits = 0.0;
      double debits = 0.0;
      for (final tx in txList) {
        final impact = getBalanceImpact(tx, accountId);
        if (impact > 0) {
          credits += impact;
        } else {
          debits += impact.abs();
        }
      }

      // Load spending summary and trend
      final spendingSummary = await _txRepo.getAccountSpendingSummary(
        accountId,
        startDate: state.spendingStartDate,
        endDate: state.spendingEndDate,
      );

      final spendingTrend = await _txRepo.getAccountSpendingTrend(
        accountId,
        periodType: state.spendingPeriodType,
        referenceDate: state.spendingReferenceDate,
      );

      state = state.copyWith(
        account: account,
        categories: categories,
        transactions: txList,
        totalCredits: credits,
        totalDebits: debits,
        netImpact: credits - debits,
        totalSpending: (spendingSummary['totalSpending'] as num?)?.toDouble() ?? 0.0,
        spendingTxCount: (spendingSummary['transactionCount'] as num?)?.toInt() ?? 0,
        averagePerTransaction: (spendingSummary['averagePerTransaction'] as num?)?.toDouble() ?? 0.0,
        categoryBreakdown: (spendingSummary['categoryBreakdown'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
        spendingTrend: spendingTrend,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _reloadTransactions() async {
    try {
      final txList = await _txRepo.getTransactions(
        accountId: accountId,
        type: state.typeFilter,
        categoryId: state.categoryIdFilter,
        startDate: state.startDateFilter,
        endDate: state.endDateFilter,
        searchQuery: state.searchQuery,
        sortBy: state.sortBy,
      );

      double credits = 0.0;
      double debits = 0.0;
      for (final tx in txList) {
        final impact = getBalanceImpact(tx, accountId);
        if (impact > 0) {
          credits += impact;
        } else {
          debits += impact.abs();
        }
      }

      state = state.copyWith(
        transactions: txList,
        totalCredits: credits,
        totalDebits: debits,
        netImpact: credits - debits,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void setFilterType(String type) {
    state = state.copyWith(typeFilter: type);
    _reloadTransactions();
  }

  void setCategoryFilter(String? categoryId) {
    if (categoryId == null || categoryId == 'all') {
      state = state.copyWith(clearCategoryIdFilter: true);
    } else {
      state = state.copyWith(categoryIdFilter: categoryId);
    }
    _reloadTransactions();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) {
      state = state.copyWith(clearStartDateFilter: true, clearEndDateFilter: true);
    } else {
      state = state.copyWith(startDateFilter: start, endDateFilter: end);
    }
    _reloadTransactions();
  }

  void setSortBy(String sortBy) {
    state = state.copyWith(sortBy: sortBy);
    _reloadTransactions();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _reloadTransactions();
  }

  void resetTransactionFilters() {
    state = state.copyWith(
      searchQuery: '',
      typeFilter: 'all',
      clearCategoryIdFilter: true,
      clearStartDateFilter: true,
      clearEndDateFilter: true,
      sortBy: 'date_desc',
    );
    _reloadTransactions();
  }

  /// Changes spending period ('daily', 'weekly', 'monthly', 'yearly')
  void setSpendingPeriod(String periodType) {
    final refDate = state.spendingReferenceDate;
    final range = _calculateDateRange(periodType, refDate);
    state = state.copyWith(
      spendingPeriodType: periodType,
      spendingStartDate: range.$1,
      spendingEndDate: range.$2,
    );
    _reloadSpending();
  }

  /// Navigates spending reference date back (-1) or forward (+1)
  void navigateSpendingPeriod(int step) {
    final period = state.spendingPeriodType;
    var refDate = state.spendingReferenceDate;

    if (period == 'daily') {
      refDate = refDate.add(Duration(days: step));
    } else if (period == 'weekly') {
      refDate = refDate.add(Duration(days: 7 * step));
    } else if (period == 'monthly') {
      refDate = DateTime(refDate.year, refDate.month + step, 1);
    } else if (period == 'yearly') {
      refDate = DateTime(refDate.year + step, 1, 1);
    }

    final range = _calculateDateRange(period, refDate);
    state = state.copyWith(
      spendingReferenceDate: refDate,
      spendingStartDate: range.$1,
      spendingEndDate: range.$2,
    );
    _reloadSpending();
  }

  (DateTime, DateTime) _calculateDateRange(String periodType, DateTime refDate) {
    if (periodType == 'daily') {
      final start = DateTime(refDate.year, refDate.month, refDate.day, 0, 0, 0);
      final end = DateTime(refDate.year, refDate.month, refDate.day, 23, 59, 59);
      return (start, end);
    } else if (periodType == 'weekly') {
      final monday = refDate.subtract(Duration(days: refDate.weekday - 1));
      final start = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
      final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      return (start, end);
    } else if (periodType == 'yearly') {
      final start = DateTime(refDate.year, 1, 1, 0, 0, 0);
      final end = DateTime(refDate.year, 12, 31, 23, 59, 59);
      return (start, end);
    } else {
      // Monthly default
      final start = DateTime(refDate.year, refDate.month, 1, 0, 0, 0);
      final end = DateTime(refDate.year, refDate.month + 1, 0, 23, 59, 59);
      return (start, end);
    }
  }

  Future<void> _reloadSpending() async {
    try {
      final spendingSummary = await _txRepo.getAccountSpendingSummary(
        accountId,
        startDate: state.spendingStartDate,
        endDate: state.spendingEndDate,
      );

      final spendingTrend = await _txRepo.getAccountSpendingTrend(
        accountId,
        periodType: state.spendingPeriodType,
        referenceDate: state.spendingReferenceDate,
      );

      state = state.copyWith(
        totalSpending: (spendingSummary['totalSpending'] as num?)?.toDouble() ?? 0.0,
        spendingTxCount: (spendingSummary['transactionCount'] as num?)?.toInt() ?? 0,
        averagePerTransaction: (spendingSummary['averagePerTransaction'] as num?)?.toDouble() ?? 0.0,
        categoryBreakdown: (spendingSummary['categoryBreakdown'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
        spendingTrend: spendingTrend,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _txRepo.deleteTransaction(transactionId);
    await ref.read(accountProvider.notifier).loadAccounts();
    await loadAll();
  }
}

final accountDetailProvider =
    NotifierProvider.family<AccountDetailNotifier, AccountDetailState, String>(
  (accountId) => AccountDetailNotifier(accountId),
);
