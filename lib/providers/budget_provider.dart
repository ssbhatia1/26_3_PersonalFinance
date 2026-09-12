import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/budget.dart';
import '../data/models/budget_strategy.dart';
import '../data/models/transaction.dart';
import '../data/repositories/budget_repository.dart';
import 'category_provider.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';

class BudgetState {
  final List<Budget> budgets;
  final DateTime selectedMonth;
  final BudgetStrategyType activeStrategy;
  final Map<BudgetBucket, double>? customStrategyPercentages;
  final String selectedPeriodFilter; // 'all', 'monthly', 'weekly', 'yearly', 'custom'
  final bool isLoading;
  final String? error;

  const BudgetState({
    this.budgets = const [],
    required this.selectedMonth,
    this.activeStrategy = BudgetStrategyType.fiftyThirtyTwenty,
    this.customStrategyPercentages,
    this.selectedPeriodFilter = 'all',
    this.isLoading = false,
    this.error,
  });

  List<Budget> get filteredBudgets {
    final filter = selectedPeriodFilter.toLowerCase();
    if (filter == 'all') return budgets;
    if (filter == 'categorized') {
      return budgets.where((b) => b.scope == 'category').toList();
    }
    if (filter == 'longterm') {
      return budgets.where((b) => b.isLongTerm).toList();
    }
    return budgets.where((b) => b.periodType.toLowerCase() == filter).toList();
  }

  /// All category-scoped budgets
  List<Budget> get categorizedBudgets => budgets.where((b) => b.scope == 'category').toList();

  /// All long-term budgets (Yearly or >60 days duration)
  List<Budget> get longTermBudgets => budgets.where((b) => b.isLongTerm).toList();

  /// Days remaining in the currently selected month
  int get currentMonthDaysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    if (selectedMonth.year == now.year && selectedMonth.month == now.month) {
      final days = lastDay.day - today.day;
      return days >= 0 ? days : 0;
    } else if (DateTime(selectedMonth.year, selectedMonth.month).isBefore(DateTime(now.year, now.month))) {
      return 0; // Past month completed
    } else {
      return lastDay.day; // Future month full length
    }
  }

  double get totalBudgeted => budgets.fold(0.0, (sum, b) => sum + b.amountLimit);
  double get totalSpent => budgets.fold(0.0, (sum, b) => sum + b.spentAmount);
  double get totalRemaining => totalBudgeted - totalSpent;
  double get overallProgress => totalBudgeted > 0 ? (totalSpent / totalBudgeted).clamp(0.0, 5.0) : 0.0;

  int get overBudgetCount => budgets.where((b) => b.alertLevel == BudgetAlertLevel.overBudget100).length;
  int get criticalCount => budgets.where((b) => b.alertLevel == BudgetAlertLevel.critical90).length;
  int get nearLimitCount => budgets.where((b) => b.alertLevel == BudgetAlertLevel.nearLimit75).length;
  int get totalAlertsCount => overBudgetCount + criticalCount + nearLimitCount;

  /// Returns total spent categorized by Needs, Wants, and Savings/Debt
  Map<BudgetBucket, double> get bucketSpent {
    double needs = 0.0;
    double wants = 0.0;
    double savings = 0.0;

    for (final b in budgets) {
      final bucket = BudgetStrategyHelper.classifyCategory(b.categoryId, b.categoryName);
      switch (bucket) {
        case BudgetBucket.needs:
          needs += b.spentAmount;
          break;
        case BudgetBucket.wants:
          wants += b.spentAmount;
          break;
        case BudgetBucket.savingsDebt:
          savings += b.spentAmount;
          break;
      }
    }
    return {
      BudgetBucket.needs: needs,
      BudgetBucket.wants: wants,
      BudgetBucket.savingsDebt: savings,
    };
  }

  /// Returns total budgeted amount categorized by Needs, Wants, and Savings/Debt
  Map<BudgetBucket, double> get bucketBudgeted {
    double needs = 0.0;
    double wants = 0.0;
    double savings = 0.0;

    for (final b in budgets) {
      final bucket = BudgetStrategyHelper.classifyCategory(b.categoryId, b.categoryName);
      switch (bucket) {
        case BudgetBucket.needs:
          needs += b.amountLimit;
          break;
        case BudgetBucket.wants:
          wants += b.amountLimit;
          break;
        case BudgetBucket.savingsDebt:
          savings += b.amountLimit;
          break;
      }
    }
    return {
      BudgetBucket.needs: needs,
      BudgetBucket.wants: wants,
      BudgetBucket.savingsDebt: savings,
    };
  }

  /// Computes strategy compliance health score (0 - 100%)
  double computeStrategyCompliance({double? referenceMonthlyIncome}) {
    final refTotal = (referenceMonthlyIncome != null && referenceMonthlyIncome > 0)
        ? referenceMonthlyIncome
        : (totalBudgeted > 0 ? totalBudgeted : 1000.0);

    final targetPcts = BudgetStrategyHelper.getStrategyTargetPercentages(
      activeStrategy,
      customPercentages: customStrategyPercentages,
    );

    final targetNeeds = refTotal * ((targetPcts[BudgetBucket.needs] ?? 50.0) / 100);
    final targetWants = refTotal * ((targetPcts[BudgetBucket.wants] ?? 30.0) / 100);
    final targetSavings = refTotal * ((targetPcts[BudgetBucket.savingsDebt] ?? 20.0) / 100);

    final spent = bucketSpent;
    return BudgetStrategyHelper.computeComplianceScore(
      targetNeeds: targetNeeds,
      actualNeeds: spent[BudgetBucket.needs] ?? 0.0,
      targetWants: targetWants,
      actualWants: spent[BudgetBucket.wants] ?? 0.0,
      targetSavings: targetSavings,
      actualSavings: spent[BudgetBucket.savingsDebt] ?? 0.0,
    );
  }

  BudgetState copyWith({
    List<Budget>? budgets,
    DateTime? selectedMonth,
    BudgetStrategyType? activeStrategy,
    Map<BudgetBucket, double>? customStrategyPercentages,
    String? selectedPeriodFilter,
    bool? isLoading,
    String? error,
  }) {
    return BudgetState(
      budgets: budgets ?? this.budgets,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      activeStrategy: activeStrategy ?? this.activeStrategy,
      customStrategyPercentages: customStrategyPercentages ?? this.customStrategyPercentages,
      selectedPeriodFilter: selectedPeriodFilter ?? this.selectedPeriodFilter,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class BudgetNotifier extends Notifier<BudgetState> {
  BudgetRepository get _repository => ref.read(budgetRepositoryProvider);
  final _uuid = const Uuid();

  @override
  BudgetState build() {
    // Automatically re-sync budget spending whenever transactions change
    ref.listen(transactionProvider, (previous, next) {
      if (previous?.transactions != next.transactions) {
        loadBudgets();
      }
    });

    Future.microtask(loadBudgets);
    return BudgetState(selectedMonth: DateTime.now());
  }

  void reset() {
    state = BudgetState(selectedMonth: DateTime.now());
  }

  Future<void> loadBudgets() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Auto-renew recurring budgets if any exist for this period
      await _repository.checkAndRenewRecurringBudgets(state.selectedMonth);
      final list = await _repository.getBudgetsForMonth(state.selectedMonth);
      if (!ref.mounted) return;
      state = state.copyWith(budgets: list, isLoading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void changeMonth(DateTime month) {
    state = state.copyWith(selectedMonth: month);
    loadBudgets();
  }

  void setPeriodFilter(String filter) {
    state = state.copyWith(selectedPeriodFilter: filter);
  }

  void setStrategy(BudgetStrategyType strategy) {
    state = state.copyWith(activeStrategy: strategy);
  }

  void setCustomStrategyPercentages(Map<BudgetBucket, double> pcts) {
    state = state.copyWith(customStrategyPercentages: pcts);
  }

  Future<void> createBudget(Budget budget) async {
    await _repository.createBudget(budget);
    await loadBudgets();
  }

  Future<void> updateBudget(Budget budget) async {
    await _repository.updateBudget(budget);
    await loadBudgets();
  }

  Future<void> deleteBudget(String budgetId) async {
    await _repository.deleteBudget(budgetId);
    await loadBudgets();
  }

  /// Fetches individual related transactions for a given budget
  Future<List<TransactionModel>> getTransactionsForBudget(Budget budget) async {
    return await _repository.getTransactionsForBudget(budget);
  }

  /// Fetches historical records of this budget across previous periods
  Future<List<Budget>> getBudgetHistory(Budget budget) async {
    return await _repository.getBudgetHistory(budget);
  }

  /// Fetches all historical budget records across periods
  Future<List<Budget>> getAllBudgetHistory() async {
    return await _repository.getAllBudgetHistory();
  }

  /// Automatically generates category budgets based on active strategy and monthly income/budget pool
  Future<int> autoGenerateBudgetsFromStrategy({required double monthlyPoolAmount}) async {
    if (monthlyPoolAmount <= 0) return 0;

    final categoriesAsync = ref.read(categoriesProvider('expense'));
    final categories = categoriesAsync.value ?? [];
    if (categories.isEmpty) return 0;

    final targetPcts = BudgetStrategyHelper.getStrategyTargetPercentages(
      state.activeStrategy,
      customPercentages: state.customStrategyPercentages,
    );

    final needsPool = monthlyPoolAmount * ((targetPcts[BudgetBucket.needs] ?? 50.0) / 100);
    final wantsPool = monthlyPoolAmount * ((targetPcts[BudgetBucket.wants] ?? 30.0) / 100);
    final savingsPool = monthlyPoolAmount * ((targetPcts[BudgetBucket.savingsDebt] ?? 20.0) / 100);

    final needsCats = <dynamic>[];
    final wantsCats = <dynamic>[];
    final savingsCats = <dynamic>[];

    for (final c in categories) {
      final bucket = BudgetStrategyHelper.classifyCategory(c.id, c.name);
      switch (bucket) {
        case BudgetBucket.needs:
          needsCats.add(c);
          break;
        case BudgetBucket.wants:
          wantsCats.add(c);
          break;
        case BudgetBucket.savingsDebt:
          savingsCats.add(c);
          break;
      }
    }

    final startOfMonth = DateTime(state.selectedMonth.year, state.selectedMonth.month, 1);
    final endOfMonth = DateTime(state.selectedMonth.year, state.selectedMonth.month + 1, 0, 23, 59, 59);

    final newBudgets = <Budget>[];

    void allocate(List<dynamic> cats, double pool) {
      if (cats.isEmpty || pool <= 0) return;
      final perCat = (pool / cats.length).roundToDouble();
      for (final c in cats) {
        newBudgets.add(Budget(
          id: _uuid.v4(),
          name: c.name,
          categoryId: c.id,
          scope: 'category',
          periodType: 'monthly',
          amountLimit: perCat,
          startDate: startOfMonth,
          endDate: endOfMonth,
        ));
      }
    }

    allocate(needsCats, needsPool);
    allocate(wantsCats, wantsPool);
    allocate(savingsCats, savingsPool);

    if (newBudgets.isNotEmpty) {
      await _repository.batchSetBudgets(newBudgets);
      await loadBudgets();
    }

    return newBudgets.length;
  }
}

final budgetProvider = NotifierProvider<BudgetNotifier, BudgetState>(BudgetNotifier.new);

