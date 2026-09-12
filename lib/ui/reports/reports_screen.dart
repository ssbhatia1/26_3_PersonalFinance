import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/models/report.dart';
import '../../data/models/transaction.dart';
import '../../providers/account_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../dashboard/widgets/cash_flow_line_chart.dart';
import '../dashboard/widgets/category_comparison_bar_chart.dart';
import '../dashboard/widgets/category_donut_chart.dart';
import '../dashboard/widgets/financial_funnel_chart.dart';
import '../dashboard/widgets/financial_runway_card.dart';
import '../dashboard/widgets/income_vs_expense_donut_card.dart';
import '../dashboard/widgets/investment_portfolio_card.dart';
import '../dashboard/widgets/monthly_stacked_bar_chart.dart';
import '../dashboard/widgets/net_worth_growth_card.dart';
import '../dashboard/widgets/transaction_records_table.dart';
import '../settings/export_data_dialog.dart';
import '../transactions/transaction_form_screen.dart';
import '../../providers/investment_provider.dart';
import 'widgets/runway_estimation_chart.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _selectedPeriod = 'this_month';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  String _selectedType = 'all'; // 'all', 'expense', 'income', 'transfer', 'adjustment'

  bool _isLoading = false;

  String _breakdownView = 'expenses'; // 'expenses', 'income', 'compare', 'accounts'
  Map<String, double> _cashFlow = {'income': 0.0, 'expense': 0.0, 'savings': 0.0};
  List<Map<String, dynamic>> _categoryExpenses = [];
  List<Map<String, dynamic>> _categoryIncome = [];
  List<Map<String, dynamic>> _accountFlows = [];
  List<Map<String, dynamic>> _monthlyTrends = [];
  List<Map<String, dynamic>> _multiMonthCategoryTrends = [];
  List<TransactionModel> _filteredTransactions = [];
  List<TransactionModel> _allTransactions = [];
  DateTime? _firstTransactionDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  (DateTime, DateTime) _resolveDateRange() {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedPeriod) {
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
      case 'this_year':
        start = DateTime(now.year, 1, 1);
        break;
      case 'all_time':
        start = _firstTransactionDate != null
            ? DateTime(_firstTransactionDate!.year, _firstTransactionDate!.month, 1)
            : DateTime(now.year - 1, 1, 1);
        break;
      case 'custom':
        start = _customStartDate ?? DateTime(now.year, now.month, 1);
        end = _customEndDate ?? DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'this_month':
      default:
        start = DateTime(now.year, now.month, 1);
        break;
    }
    return (start, end);
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    final txRepo = ref.read(transactionRepositoryProvider);
    final (start, end) = _resolveDateRange();

    try {
      final cashFlow = await txRepo.getCashFlowSummary(
        start,
        end,
        accountId: _selectedAccountId,
      );
      final catExp = await txRepo.getCategorySpendingSummary(
        start,
        end,
        accountId: _selectedAccountId,
      );
      final catInc = await txRepo.getCategoryIncomeSummary(
        start,
        end,
        accountId: _selectedAccountId,
      );
      final accFlows = await txRepo.getAccountFlowSummary(
        start,
        end,
        accountId: _selectedAccountId,
      );
      final monthlyTrends = await txRepo.getMonthlyTrends(
        monthsCount: 6,
        accountId: _selectedAccountId,
      );
      final multiMonthCategoryTrends = await txRepo.getMultiMonthCategoryTrends(
        monthsCount: 6,
        accountId: _selectedAccountId,
      );

      final allTxs = await txRepo.getTransactions(
        accountId: _selectedAccountId,
        categoryId: _selectedCategoryId,
        type: _selectedType == 'all' ? null : _selectedType,
      );

      final txs = await txRepo.getTransactions(
        accountId: _selectedAccountId,
        categoryId: _selectedCategoryId,
        type: _selectedType == 'all' ? null : _selectedType,
        startDate: start,
        endDate: end,
      );

      DateTime? earliest;
      if (allTxs.isNotEmpty) {
        earliest = allTxs.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b);
      }

      if (!mounted) return;

      setState(() {
        _cashFlow = cashFlow;
        _categoryExpenses = catExp;
        _categoryIncome = catInc;
        _accountFlows = accFlows;
        _monthlyTrends = monthlyTrends;
        _multiMonthCategoryTrends = multiMonthCategoryTrends;
        _allTransactions = allTxs;
        _filteredTransactions = txs;
        _firstTransactionDate = earliest;
      });
    } catch (e) {
      debugPrint('Error loading report data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickCustomDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
    );

    if (range != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _customStartDate = range.start;
        _customEndDate = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      });
      _loadReportData();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to transactionProvider changes so reports automatically update
    ref.listen(transactionProvider, (_, __) => _loadReportData());

    final settings = ref.watch(settingsProvider);
    final accountState = ref.watch(accountProvider);
    final categoryState = ref.watch(categoryManagementProvider);
    final budgetState = ref.watch(budgetProvider);
    final investmentState = ref.watch(investmentProvider);
    final curr = settings.currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final income = _cashFlow['income'] ?? 0.0;
    final expense = _cashFlow['expense'] ?? 0.0;
    final transfers = _cashFlow['transfers'] ?? 0.0;
    final transfersIn = _cashFlow['transfersIn'] ?? 0.0;
    final transfersOut = _cashFlow['transfersOut'] ?? 0.0;
    final savings = income - expense;
    final savingsRate = income > 0 ? (savings / income * 100).clamp(-100.0, 100.0) : 0.0;
    final budgetLimit = budgetState.totalBudgeted;

    final netWorth = accountState.netWorthSummary['netWorth'] ?? 0.0;
    final totalBank = accountState.netWorthSummary['totalBank'] ?? 0.0;
    final totalCash = accountState.netWorthSummary['totalCash'] ?? 0.0;
    final totalInvestments = accountState.netWorthSummary['totalInvestments'] ?? 0.0;
    final liquidAssets = totalBank + totalCash;

    // Financial Runway Math via RunwayMetrics model
    final (start, end) = _resolveDateRange();
    final daysInPeriod = max(1, end.difference(start).inDays + 1);
    final runway = RunwayMetrics.compute(
      liquidAssets: liquidAssets,
      totalInflow: income,
      totalOutflow: expense,
      daysInPeriod: daysInPeriod,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Financial Report',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const ExportDataDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Analytics',
            onPressed: _loadReportData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.grid_view_rounded), text: 'Visual Graphs (Grid)'),
            Tab(icon: Icon(Icons.speed_rounded), text: 'Runway & Cash Flow'),
            Tab(icon: Icon(Icons.pie_chart_rounded), text: 'Category Breakdowns'),
            Tab(icon: Icon(Icons.trending_up_rounded), text: 'Historical Trends'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Filtered Records'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),

          // Multi-dimensional Filters Section
          _buildFilterControls(accountState.accounts, categoryState.allCategories, isDark, start, end),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 0. Visual Graphs Overview Cockpit (Grid Format)
                _buildVisualGraphsGridTab(
                  netWorth: netWorth,
                  totalInvestments: totalInvestments,
                  investments: investmentState.investments,
                  income: income,
                  expense: expense,
                  savings: savings,
                  savingsRate: savingsRate,
                  budgetLimit: budgetLimit,
                  runwayDays: runway.runwayDays,
                  isInfiniteRunway: runway.isInfiniteRunway,
                  liquidAssets: runway.liquidAssets,
                  avgDailyOutflow: runway.avgDailyOutflow,
                  avgMonthlyOutflow: runway.avgMonthlyOutflow,
                  curr: curr,
                  isDark: isDark,
                ),

                // 1. Runway & Cash Flow Analysis
                _buildRunwayAndCashFlowTab(
                  runwayDays: runway.runwayDays,
                  isInfiniteRunway: runway.isInfiniteRunway,
                  liquidAssets: runway.liquidAssets,
                  avgDailyOutflow: runway.avgDailyOutflow,
                  avgWeeklyOutflow: runway.avgWeeklyOutflow,
                  avgMonthlyOutflow: runway.avgMonthlyOutflow,
                  avgDailyInflow: runway.avgDailyInflow,
                  avgWeeklyInflow: runway.avgWeeklyInflow,
                  avgMonthlyInflow: runway.avgMonthlyInflow,
                  income: income,
                  expense: expense,
                  savings: savings,
                  savingsRate: savingsRate,
                  transfers: transfers,
                  transfersIn: transfersIn,
                  transfersOut: transfersOut,
                  isAccountFiltered: _selectedAccountId != null,
                  budgetLimit: budgetLimit,
                  curr: curr,
                  isDark: isDark,
                ),

                // 2. Breakdown & Account Flows
                _buildBreakdownsTab(curr, isDark, income, expense),

                // 3. Historical Trends & Net Worth
                _buildTrendsTab(
                  netWorth: netWorth,
                  totalInvestments: totalInvestments,
                  investments: investmentState.investments,
                  curr: curr,
                  isDark: isDark,
                ),

                // 4. Filtered Records
                _buildFilteredRecordsTab(curr, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MULTI-DIMENSIONAL FILTERS
  // =========================================================================
  Widget _buildFilterControls(
    List<Account> accounts,
    List<Category> categories,
    bool isDark,
    DateTime start,
    DateTime end,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _periodChip('this_month', 'This Month'),
                const SizedBox(width: 8),
                _periodChip('last_month', 'Last Month'),
                const SizedBox(width: 8),
                _periodChip('last_3_months', 'Last 3 Months'),
                const SizedBox(width: 8),
                _periodChip('last_6_months', 'Last 6 Months'),
                const SizedBox(width: 8),
                _periodChip('this_year', 'This Year'),
                const SizedBox(width: 8),
                _periodChip(
                  'all_time',
                  _firstTransactionDate != null
                      ? 'All Time (Since ${DateFormat('MMM yyyy').format(_firstTransactionDate!)})'
                      : 'All Time',
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 14),
                  label: Text(
                    _selectedPeriod == 'custom' && _customStartDate != null && _customEndDate != null
                        ? '${DateFormat('dd MMM').format(_customStartDate!)} - ${DateFormat('dd MMM').format(_customEndDate!)}'
                        : 'Custom Range',
                    style: TextStyle(
                      fontWeight: _selectedPeriod == 'custom' ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: _pickCustomDateRange,
                ),
              ],
            ),
          ),
          if (_firstTransactionDate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withOpacity(isDark ? 0.3 : 0.18),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'First Transaction: ${DateFormat('MMMM yyyy').format(_firstTransactionDate!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Window: ${DateFormat('MMM yyyy').format(start)} – ${DateFormat('MMM yyyy').format(end)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Multi-Filter Dropdowns (Account, Category, Type)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Account Filter
                DropdownButton<String?>(
                  value: _selectedAccountId,
                  hint: const Text('All Accounts', style: TextStyle(fontSize: 12)),
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Accounts', style: TextStyle(fontSize: 12)),
                    ),
                    ...accounts.map((a) => DropdownMenuItem<String?>(
                          value: a.id,
                          child: Text('${a.name} (${a.type})', style: const TextStyle(fontSize: 12)),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedAccountId = val);
                    _loadReportData();
                  },
                ),
                const SizedBox(width: 16),

                // Category Filter
                DropdownButton<String?>(
                  value: _selectedCategoryId,
                  hint: const Text('All Categories', style: TextStyle(fontSize: 12)),
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Categories', style: TextStyle(fontSize: 12)),
                    ),
                    ...categories.map((c) => DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text(c.name, style: const TextStyle(fontSize: 12)),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedCategoryId = val);
                    _loadReportData();
                  },
                ),
                const SizedBox(width: 16),

                // Transaction Type Filter
                DropdownButton<String>(
                  value: _selectedType,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Types', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'expense', child: Text('Expenses', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'income', child: Text('Income', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'transfer', child: Text('Transfers', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'adjustment', child: Text('Adjustments', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedType = val);
                      _loadReportData();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String key, String label) {
    final isSelected = _selectedPeriod == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedPeriod = key);
          _loadReportData();
        }
      },
    );
  }

  // =========================================================================
  // RESPONSIVE GRAPH & CARD HELPERS
  // =========================================================================
  Widget _buildResponsiveCardPair(Widget card1, Widget card2) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 700) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card1),
              const SizedBox(width: 16),
              Expanded(child: card2),
            ],
          );
        } else {
          return Column(
            children: [
              card1,
              const SizedBox(height: 16),
              card2,
            ],
          );
        }
      },
    );
  }

  Widget _buildResponsiveGraphGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 650 ? 2 : 1);
        if (crossAxisCount == 1) {
          return Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: c,
                    ))
                .toList(),
          );
        }
        final rows = <Widget>[];
        for (int i = 0; i < cards.length; i += crossAxisCount) {
          final rowCards = cards.sublist(i, min(i + crossAxisCount, cards.length));
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int j = 0; j < rowCards.length; j++) ...[
                    if (j > 0) const SizedBox(width: 16),
                    Expanded(child: rowCards[j]),
                  ],
                  for (int j = rowCards.length; j < crossAxisCount; j++) ...[
                    const SizedBox(width: 16),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  Widget _buildQuickAnalyticsKpis(
    double income,
    double expense,
    double savings,
    double netWorth,
    String curr,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;
        final cards = [
          _buildQuickKpiItem(
            'Total Inflow',
            '+${CurrencyFormatter.formatCompact(income, symbol: curr)}',
            AppColors.income,
            Icons.arrow_downward_rounded,
            isDark,
          ),
          _buildQuickKpiItem(
            'Total Outflow',
            '-${CurrencyFormatter.formatCompact(expense, symbol: curr)}',
            AppColors.expense,
            Icons.arrow_upward_rounded,
            isDark,
          ),
          _buildQuickKpiItem(
            'Net Savings',
            '${savings >= 0 ? "+" : ""}${CurrencyFormatter.formatCompact(savings, symbol: curr)}',
            savings >= 0 ? AppColors.income : AppColors.expense,
            Icons.savings_rounded,
            isDark,
          ),
          _buildQuickKpiItem(
            'Current Net Worth',
            CurrencyFormatter.formatCompact(netWorth, symbol: curr),
            const Color(0xFF10B981),
            Icons.account_balance_rounded,
            isDark,
          ),
        ];

        if (isCompact) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        } else {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
      },
    );
  }

  Widget _buildQuickKpiItem(String title, String value, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 0: VISUAL GRAPHS (GRID FORMAT)
  // =========================================================================
  Widget _buildVisualGraphsGridTab({
    required double netWorth,
    required double totalInvestments,
    required List<dynamic> investments,
    required double income,
    required double expense,
    required double savings,
    required double savingsRate,
    required double budgetLimit,
    required int runwayDays,
    required bool isInfiniteRunway,
    required double liquidAssets,
    required double avgDailyOutflow,
    required double avgMonthlyOutflow,
    required String curr,
    required bool isDark,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick KPI Header Bar
        _buildQuickAnalyticsKpis(income, expense, savings, netWorth, curr, isDark),
        const SizedBox(height: 16),

        // Responsive Multi-Device Graph Grid (Matching Tablet & Laptop Ecosystem Mockup)
        _buildResponsiveGraphGrid([
          NetWorthGrowthCard(
            currentNetWorth: netWorth,
            transactions: _allTransactions,
            currency: curr,
            height: 320,
          ),
          IncomeVsExpenseDonutCard(
            income: income,
            expense: expense,
            currency: curr,
            height: 320,
          ),
          CashFlowLineChart(
            transactions: _filteredTransactions,
            currency: curr,
            height: 320,
          ),
          InvestmentPortfolioCard(
            investments: investments.cast(),
            totalInvestmentsValuation: totalInvestments,
            currency: curr,
            height: 320,
          ),
          CategoryDonutChart(
            categorySpending: _categoryExpenses,
            currency: curr,
            height: 320,
            title: 'Expense Distribution',
            subtitle: 'Category volume breakdown for current period',
            emptyMessage: 'No expense records in current timeframe.',
          ),
          CategoryComparisonBarChart(
            categorySpending: _categoryExpenses,
            currency: curr,
            height: 320,
            title: 'Category Volume Comparison',
            subtitle: 'Ranked expenditure bar rods',
            emptyMessage: 'No category records for comparison.',
          ),
          FinancialRunwayCard(
            runwayDays: runwayDays,
            isInfiniteRunway: isInfiniteRunway,
            avgMonthlyOutflow: avgMonthlyOutflow,
            liquidAssets: liquidAssets,
            currency: curr,
            height: 320,
          ),
          RunwayEstimationChart(
            runwayDays: runwayDays,
            isInfiniteRunway: isInfiniteRunway,
            liquidAssets: liquidAssets,
            avgDailyOutflow: avgDailyOutflow,
            currency: curr,
            isDark: isDark,
            height: 320,
          ),
          MonthlyStackedBarChart(
            transactions: _allTransactions,
            currency: curr,
            height: 320,
          ),
          FinancialFunnelChart(
            grossInflow: income,
            budgetAllocated: budgetLimit,
            actualOutflow: expense,
            netSavings: savings,
            currency: curr,
            height: 320,
          ),
        ]),
        const SizedBox(height: 40),
      ],
    );
  }

  // =========================================================================
  // TAB 1: RUNWAY & CASH FLOW
  // =========================================================================
  Widget _buildRunwayAndCashFlowTab({
    required int runwayDays,
    required bool isInfiniteRunway,
    required double liquidAssets,
    required double avgDailyOutflow,
    required double avgWeeklyOutflow,
    required double avgMonthlyOutflow,
    required double avgDailyInflow,
    required double avgWeeklyInflow,
    required double avgMonthlyInflow,
    required double income,
    required double expense,
    required double savings,
    required double savingsRate,
    required double transfers,
    required double transfersIn,
    required double transfersOut,
    required bool isAccountFiltered,
    required double budgetLimit,
    required String curr,
    required bool isDark,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. PERIOD CASH FLOW SUMMARY CARD
        _buildSummaryCard(
          income,
          expense,
          savings,
          savingsRate,
          transfers,
          curr,
          isDark,
          transfersIn: transfersIn,
          transfersOut: transfersOut,
          isAccountFiltered: isAccountFiltered,
        ),
        const SizedBox(height: 16),

        // 2. FINANCIAL RUNWAY ESTIMATION PAIR (Responsive Grid Layout)
        _buildResponsiveCardPair(
          FinancialRunwayCard(
            runwayDays: runwayDays,
            isInfiniteRunway: isInfiniteRunway,
            avgMonthlyOutflow: avgMonthlyOutflow,
            liquidAssets: liquidAssets,
            currency: curr,
            height: 320,
          ),
          _buildRunwayCard(
            runwayDays: runwayDays,
            isInfiniteRunway: isInfiniteRunway,
            liquidAssets: liquidAssets,
            avgDailyOutflow: avgDailyOutflow,
            curr: curr,
            isDark: isDark,
            height: 320,
          ),
        ),
        const SizedBox(height: 16),

        // 3. CASH FLOW & CONVERSION FUNNEL PAIR (Responsive Grid Layout)
        if (_filteredTransactions.isEmpty && income == 0 && expense == 0) ...[
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'No transactions in this period',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try changing the period or add a new transaction.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => const TransactionFormScreen(),
                      );
                      _loadReportData();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Transaction'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          _buildResponsiveCardPair(
            CashFlowLineChart(
              transactions: _filteredTransactions,
              currency: curr,
              height: 320,
            ),
            FinancialFunnelChart(
              grossInflow: income,
              budgetAllocated: budgetLimit,
              actualOutflow: expense,
              netSavings: savings,
              currency: curr,
              height: 320,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 4. AVERAGE INFLOW & OUTFLOW COMPARISON
        _buildAveragesCard(
          avgDailyInflow: avgDailyInflow,
          avgDailyOutflow: avgDailyOutflow,
          avgWeeklyInflow: avgWeeklyInflow,
          avgWeeklyOutflow: avgWeeklyOutflow,
          avgMonthlyInflow: avgMonthlyInflow,
          avgMonthlyOutflow: avgMonthlyOutflow,
          curr: curr,
          isDark: isDark,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildRunwayCard({
    required int runwayDays,
    required bool isInfiniteRunway,
    required double liquidAssets,
    required double avgDailyOutflow,
    required String curr,
    required bool isDark,
    double height = 320.0,
  }) {
    return RunwayEstimationChart(
      runwayDays: runwayDays,
      isInfiniteRunway: isInfiniteRunway,
      liquidAssets: liquidAssets,
      avgDailyOutflow: avgDailyOutflow,
      currency: curr,
      isDark: isDark,
      height: height,
    );
  }

  Widget _buildAveragesCard({
    required double avgDailyInflow,
    required double avgDailyOutflow,
    required double avgWeeklyInflow,
    required double avgWeeklyOutflow,
    required double avgMonthlyInflow,
    required double avgMonthlyOutflow,
    required String curr,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Inflow vs. Outflow Averages',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(3),
              3: FlexColumnWidth(2.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                ),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Period', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Avg Inflow', style: TextStyle(fontSize: 11, color: AppColors.income, fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Avg Outflow', style: TextStyle(fontSize: 11, color: AppColors.expense, fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Net / Period', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))),
                ],
              ),
              _buildAverageRow('Daily', avgDailyInflow, avgDailyOutflow, curr),
              _buildAverageRow('Weekly', avgWeeklyInflow, avgWeeklyOutflow, curr),
              _buildAverageRow('Monthly', avgMonthlyInflow, avgMonthlyOutflow, curr),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildAverageRow(String label, double inflow, double outflow, String curr) {
    final net = inflow - outflow;
    final totalFlow = inflow + outflow;
    final inflowRatio = totalFlow > 0 ? (inflow / totalFlow).clamp(0.05, 0.95) : 0.5;

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  width: 48,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (inflowRatio * 100).round(),
                        child: Container(color: AppColors.income),
                      ),
                      Expanded(
                        flex: ((1 - inflowRatio) * 100).round(),
                        child: Container(color: AppColors.expense),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('+${CurrencyFormatter.format(inflow, symbol: curr)}', style: const TextStyle(fontSize: 12, color: AppColors.income)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('-${CurrencyFormatter.format(outflow, symbol: curr)}', style: const TextStyle(fontSize: 12, color: AppColors.expense)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${net >= 0 ? "+" : ""}${CurrencyFormatter.format(net, symbol: curr)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: net >= 0 ? AppColors.income : AppColors.expense),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    double income,
    double expense,
    double savings,
    double savingsRate,
    double transfers,
    String curr,
    bool isDark, {
    double transfersIn = 0.0,
    double transfersOut = 0.0,
    bool isAccountFiltered = false,
  }) {
    final coverageRatio = expense > 0 ? (income / expense) : (income > 0 ? 10.0 : 0.0);
    final coverageText = expense > 0 ? '${coverageRatio.toStringAsFixed(1)}x Inflow Coverage' : 'Coverage: N/A';

    Color statusColor;
    String statusLabel;
    if (savings > 0) {
      if (savingsRate >= 30) {
        statusColor = AppColors.income;
        statusLabel = 'Exceptional (${savingsRate.toStringAsFixed(1)}%)';
      } else {
        statusColor = const Color(0xFF10B981);
        statusLabel = 'Surplus (+${savingsRate.toStringAsFixed(1)}%)';
      }
    } else if (savings == 0) {
      statusColor = Colors.grey;
      statusLabel = 'Break-Even (0%)';
    } else {
      statusColor = AppColors.expense;
      statusLabel = 'Deficit (${savingsRate.toStringAsFixed(1)}%)';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Period Cash Flow Summary',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_firstTransactionDate != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        'First recorded activity: ${DateFormat('MMMM yyyy').format(_firstTransactionDate!)}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Income', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '+${CurrencyFormatter.format(income, symbol: curr)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.income),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Expense', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '-${CurrencyFormatter.format(expense, symbol: curr)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.expense),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Net Savings', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${savings >= 0 ? "+" : ""}${CurrencyFormatter.format(savings, symbol: curr)}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: savings >= 0 ? AppColors.income : AppColors.expense),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (income > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (savingsRate / 100).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: Colors.grey.withAlpha(30),
                valueColor: AlwaysStoppedAnimation<Color>(savings >= 0 ? AppColors.income : AppColors.expense),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync_alt_rounded, size: 16, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAccountFiltered
                        ? 'Transfers In: +${CurrencyFormatter.format(transfersIn, symbol: curr)} | Out: -${CurrencyFormatter.format(transfersOut, symbol: curr)}'
                        : 'Total Account Transfers: ${CurrencyFormatter.format(transfers, symbol: curr)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  coverageText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: BREAKDOWN & ACCOUNT FLOWS
  // =========================================================================
  Widget _buildBreakdownsTab(String curr, bool isDark, double income, double expense) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 3-way toggle between Expenses, Income, and Account Flows
        _buildBreakdownSegmentedControl(isDark),

        if (_breakdownView == 'expenses') ...[
          _buildResponsiveCardPair(
            CategoryDonutChart(
              categorySpending: _categoryExpenses,
              currency: curr,
              height: 320,
              title: 'Expense Share (Donut Chart)',
              subtitle: 'Percentage breakdown of capital outflow',
              emptyMessage: 'No expense distribution data for current timeframe.',
            ),
            CategoryComparisonBarChart(
              categorySpending: _categoryExpenses,
              currency: curr,
              height: 320,
              title: 'Category Expenditure (Bar Chart)',
              subtitle: 'Cross-category volume comparison',
              emptyMessage: 'No category expense records available for comparison.',
            ),
          ),
          const SizedBox(height: 16),
          _buildCategoryListSection(curr, isDark, expense, isExpense: true),
        ] else if (_breakdownView == 'income') ...[
          _buildResponsiveCardPair(
            CategoryDonutChart(
              categorySpending: _categoryIncome,
              currency: curr,
              height: 320,
              title: 'Income Share (Donut Chart)',
              subtitle: 'Percentage breakdown of income streams',
              emptyMessage: 'No income distribution data for current timeframe.',
            ),
            CategoryComparisonBarChart(
              categorySpending: _categoryIncome,
              currency: curr,
              height: 320,
              title: 'Category Income (Bar Chart)',
              subtitle: 'Cross-category income volume comparison',
              emptyMessage: 'No category income records available for comparison.',
            ),
          ),
          const SizedBox(height: 16),
          _buildCategoryListSection(curr, isDark, income, isExpense: false),
        ] else if (_breakdownView == 'compare') ...[
          _buildIncomeVsExpenseBreakdown(curr, isDark, income, expense),
        ] else ...[
          _buildAccountFlowsSection(curr, isDark),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildBreakdownSegmentedControl(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _buildBreakdownTabButton('expenses', 'Expenses', Icons.trending_down_rounded, AppColors.expense, isDark),
          _buildBreakdownTabButton('income', 'Income', Icons.trending_up_rounded, AppColors.income, isDark),
          _buildBreakdownTabButton('compare', 'Income vs Exp', Icons.compare_arrows_rounded, const Color(0xFF8B5CF6), isDark),
          _buildBreakdownTabButton('accounts', 'Flows', Icons.account_balance_rounded, AppColors.primary, isDark),
        ],
      ),
    );
  }

  Widget _buildBreakdownTabButton(
    String view,
    String label,
    IconData icon,
    Color activeColor,
    bool isDark,
  ) {
    final isSelected = _breakdownView == view;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _breakdownView = view),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.darkCard : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? activeColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryListSection(
    String curr,
    bool isDark,
    double totalAmount, {
    required bool isExpense,
  }) {
    final list = isExpense ? _categoryExpenses : _categoryIncome;
    final title = isExpense ? 'Ranked Category Expenditure' : 'Ranked Income Sources & Categories';
    final emptyText = isExpense
        ? 'No category spending recorded for this period.'
        : 'No category income recorded for this period.';
    final progressColor = isExpense ? AppColors.primary : AppColors.income;

    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text(
            emptyText,
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text(
                'Total: ${CurrencyFormatter.format(totalAmount, symbol: curr)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isExpense ? AppColors.expense : AppColors.income,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...list.map((cat) {
            final amt = (cat['amount'] as num).toDouble();
            final pct = totalAmount > 0 ? (amt / totalAmount) * 100 : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(cat['categoryName'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        '${isExpense ? "-" : "+"}${CurrencyFormatter.format(amt, symbol: curr)} (${pct.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isExpense ? null : AppColors.income,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.grey.withAlpha(30),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildIncomeVsExpenseBreakdown(String curr, bool isDark, double totalIncome, double totalExpense) {
    final net = totalIncome - totalExpense;

    final combined = <Map<String, dynamic>>[];
    for (final inc in _categoryIncome) {
      combined.add({
        'name': inc['categoryName'],
        'type': 'income',
        'amount': inc['amount'],
        'color': inc['categoryColor'],
        'icon': inc['categoryIcon'],
      });
    }
    for (final exp in _categoryExpenses) {
      combined.add({
        'name': exp['categoryName'],
        'type': 'expense',
        'amount': exp['amount'],
        'color': exp['categoryColor'],
        'icon': exp['categoryIcon'],
      });
    }
    combined.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2-Tone Donut Chart Overview paired with Category Inflow vs Outflow Overview
        _buildResponsiveCardPair(
          IncomeVsExpenseDonutCard(
            income: totalIncome,
            expense: totalExpense,
            currency: curr,
            height: 320,
          ),
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Category Inflow vs Outflow', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (net >= 0 ? AppColors.income : AppColors.expense).withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Net: ${net >= 0 ? "+" : ""}${CurrencyFormatter.formatCompact(net, symbol: curr)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: net >= 0 ? AppColors.income : AppColors.expense,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildFlowStatBox(
                        'Income Sources (${_categoryIncome.length})',
                        '+${CurrencyFormatter.format(totalIncome, symbol: curr)}',
                        AppColors.income,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFlowStatBox(
                        'Expense Sectors (${_categoryExpenses.length})',
                        '-${CurrencyFormatter.format(totalExpense, symbol: curr)}',
                        AppColors.expense,
                        isDark,
                      ),
                    ),
                  ],
                ),
                if (totalIncome > 0 || totalExpense > 0) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Flow Comparison Ratio', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600)),
                      Text(
                        '${((totalIncome / (totalIncome + totalExpense)) * 100).toStringAsFixed(0)}% In / ${((totalExpense / (totalIncome + totalExpense)) * 100).toStringAsFixed(0)}% Out',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: [
                          Expanded(
                            flex: max(1, ((totalIncome / (totalIncome + totalExpense)) * 100).round()),
                            child: Container(color: AppColors.income),
                          ),
                          Expanded(
                            flex: max(1, ((totalExpense / (totalIncome + totalExpense)) * 100).round()),
                            child: Container(color: AppColors.expense),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Side-by-side Top Lists
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Income Categories
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_circle_up_rounded, size: 16, color: AppColors.income),
                        const SizedBox(width: 4),
                        const Expanded(child: Text('Top Income Sources', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_categoryIncome.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('No income categories', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      )
                    else
                      ..._categoryIncome.take(4).map((c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(c['categoryName'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                            Text('+${CurrencyFormatter.formatCompact((c['amount'] as num).toDouble(), symbol: curr)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.income)),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Top Expense Categories
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_circle_down_rounded, size: 16, color: AppColors.expense),
                        const SizedBox(width: 4),
                        const Expanded(child: Text('Top Expense Sectors', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_categoryExpenses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('No expense categories', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      )
                    else
                      ..._categoryExpenses.take(4).map((c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(c['categoryName'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                            Text('-${CurrencyFormatter.formatCompact((c['amount'] as num).toDouble(), symbol: curr)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.expense)),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Unified Category Contribution Table
        if (combined.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: const Center(child: Text('No category income or expense recorded for this period.')),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('All Active Categories by Volume', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...combined.map((cat) {
                  final isInc = cat['type'] == 'income';
                  final amt = (cat['amount'] as num).toDouble();
                  final totalBase = isInc ? totalIncome : totalExpense;
                  final pct = totalBase > 0 ? (amt / totalBase * 100) : 0.0;
                  final color = isInc ? AppColors.income : AppColors.expense;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(20),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isInc ? 'INCOME' : 'EXPENSE',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(cat['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Text(
                              '${isInc ? "+" : "-"}${CurrencyFormatter.format(amt, symbol: curr)} (${pct.toStringAsFixed(1)}%)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isInc ? AppColors.income : null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (pct / 100).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: Colors.grey.withAlpha(25),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAccountFlowsSection(String curr, bool isDark) {
    final list = _accountFlows;
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('No accounts or transaction activity found for this period.'),
        ),
      );
    }

    final totalSystemInflow = list.fold(0.0, (sum, a) => sum + (a['totalInflow'] as double));
    final totalSystemOutflow = list.fold(0.0, (sum, a) => sum + (a['totalOutflow'] as double));
    final totalNetFlow = totalSystemInflow - totalSystemOutflow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // System Summary Banner
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_tree_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Account Cash Movements', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${list.length} Accounts',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildFlowStatBox(
                      'Total Inflow',
                      '+${CurrencyFormatter.format(totalSystemInflow, symbol: curr)}',
                      AppColors.income,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFlowStatBox(
                      'Total Outflow',
                      '-${CurrencyFormatter.format(totalSystemOutflow, symbol: curr)}',
                      AppColors.expense,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFlowStatBox(
                      'Net Flow',
                      '${totalNetFlow >= 0 ? "+" : ""}${CurrencyFormatter.format(totalNetFlow, symbol: curr)}',
                      totalNetFlow >= 0 ? AppColors.income : AppColors.expense,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Includes direct income, direct expenses, and internal inter-account transfers.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Per Account Cards (Responsive 2-column or 1-column grid)
        _buildResponsiveGraphGrid(list.map((acc) => _buildAccountFlowCard(acc, curr, isDark)).toList()),
      ],
    );
  }

  Widget _buildFlowStatBox(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountFlowCard(Map<String, dynamic> acc, String curr, bool isDark) {
    final name = acc['accountName'] as String;
    final type = acc['accountType'] as String;
    final currentBal = acc['currentBalance'] as double;
    final inflow = acc['totalInflow'] as double;
    final outflow = acc['totalOutflow'] as double;
    final directIncome = acc['income'] as double;
    final directExpense = acc['expense'] as double;
    final transfersIn = acc['transfersIn'] as double;
    final transfersOut = acc['transfersOut'] as double;
    final netFlow = acc['netFlow'] as double;
    final txCount = acc['txCount'] as int;

    final flowTotal = inflow + outflow;
    final inflowRatio = flowTotal > 0 ? (inflow / flowTotal).clamp(0.0, 1.0) : 0.5;

    IconData getAccountIcon(String typeStr) {
      final t = typeStr.toLowerCase();
      if (t.contains('bank') || t.contains('savings') || t.contains('checking')) return Icons.account_balance_rounded;
      if (t.contains('card') || t.contains('credit')) return Icons.credit_card_rounded;
      if (t.contains('cash') || t.contains('wallet')) return Icons.payments_rounded;
      if (t.contains('invest') || t.contains('demat') || t.contains('mutual')) return Icons.trending_up_rounded;
      return Icons.account_balance_wallet_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Account Info & Current Balance
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(getAccountIcon(type), size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          type,
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        if (txCount > 0) ...[
                          Text(' • ', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          Text(
                            '$txCount ${txCount == 1 ? "tx" : "txs"}',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Current Balance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(currentBal, symbol: curr),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Flow Grid: Inflow, Outflow, Direct Expense, Net Flow
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Inflow', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '+${CurrencyFormatter.format(inflow, symbol: curr)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.income),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Inc: ${CurrencyFormatter.formatCompact(directIncome, symbol: curr)} | In: ${CurrencyFormatter.formatCompact(transfersIn, symbol: curr)}',
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Outflow', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '-${CurrencyFormatter.format(outflow, symbol: curr)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.expense),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Exp: ${CurrencyFormatter.formatCompact(directExpense, symbol: curr)} | Out: ${CurrencyFormatter.formatCompact(transfersOut, symbol: curr)}',
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 14, color: AppColors.expense),
                          const SizedBox(width: 4),
                          Text(
                            'Account Expense: ',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                          ),
                          Text(
                            '-${CurrencyFormatter.format(directExpense, symbol: curr)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.expense),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Net: ',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                        ),
                        Text(
                          '${netFlow >= 0 ? "+" : ""}${CurrencyFormatter.format(netFlow, symbol: curr)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: netFlow >= 0 ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Flow ratio indicator (only if flowTotal > 0)
          if (flowTotal > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Flow Split: ', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 5,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (inflowRatio * 100).round(),
                            child: Container(color: AppColors.income),
                          ),
                          Expanded(
                            flex: ((1 - inflowRatio) * 100).round(),
                            child: Container(color: AppColors.expense),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(inflowRatio * 100).toStringAsFixed(0)}% In / ${((1 - inflowRatio) * 100).toStringAsFixed(0)}% Out',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: HISTORICAL TRENDS & NET WORTH
  // =========================================================================
  Widget _buildTrendsTab({
    required double netWorth,
    required double totalInvestments,
    required List<dynamic> investments,
    required String curr,
    required bool isDark,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Net Worth Growth Area Chart & Investment Portfolio (Responsive Pair)
        _buildResponsiveCardPair(
          NetWorthGrowthCard(
            currentNetWorth: netWorth,
            transactions: _allTransactions,
            currency: curr,
            height: 320,
          ),
          InvestmentPortfolioCard(
            investments: investments.cast(),
            totalInvestmentsValuation: totalInvestments,
            currency: curr,
            height: 320,
          ),
        ),
        const SizedBox(height: 16),

        // 2. Monthly Capital Allocation Stacks (Uniform 320 height)
        MonthlyStackedBarChart(
          transactions: _allTransactions,
          currency: curr,
          height: 320,
        ),
        const SizedBox(height: 16),

        // 3. Multi-Month Trend KPIs & Analysis Table
        _buildMultiMonthTrendSection(curr, isDark),
        const SizedBox(height: 16),

        // 3. Multi-Month Category Breakdown for Income and Expense
        _buildMultiMonthCategoryBreakdownSection(curr, isDark),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildMultiMonthTrendSection(String curr, bool isDark) {
    if (_monthlyTrends.isEmpty) {
      return const SizedBox.shrink();
    }

    final total6mIncome = _monthlyTrends.fold<double>(0.0, (sum, m) => sum + (m['income'] as double));
    final total6mExpense = _monthlyTrends.fold<double>(0.0, (sum, m) => sum + (m['expense'] as double));
    final total6mSavings = total6mIncome - total6mExpense;
    final avgMonthlySavings = _monthlyTrends.isNotEmpty ? total6mSavings / _monthlyTrends.length : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Multi-Month Financial Comparison',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Past 6 Months',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Month-over-month income, expense, and net liquidity trend analysis',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // KPI Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildTrendStatCard(
                  '6-Mo Total Inflow',
                  '+${CurrencyFormatter.formatCompact(total6mIncome, symbol: curr)}',
                  AppColors.income,
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTrendStatCard(
                  '6-Mo Total Outflow',
                  '-${CurrencyFormatter.formatCompact(total6mExpense, symbol: curr)}',
                  AppColors.expense,
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTrendStatCard(
                  'Avg Monthly Net',
                  '${avgMonthlySavings >= 0 ? "+" : ""}${CurrencyFormatter.formatCompact(avgMonthlySavings, symbol: curr)}',
                  avgMonthlySavings >= 0 ? AppColors.income : AppColors.expense,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Multi-Month Comparison Table
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(2.6),
              2: FlexColumnWidth(2.6),
              3: FlexColumnWidth(2.6),
              4: FlexColumnWidth(2.4),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                ),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Month', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Income', style: TextStyle(fontSize: 11, color: AppColors.income, fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Expense', style: TextStyle(fontSize: 11, color: AppColors.expense, fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Net Flow', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('MoM %', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))),
                ],
              ),
              ..._monthlyTrends.asMap().entries.map((entry) {
                final idx = entry.key;
                final m = entry.value;
                final label = m['monthLabel'] as String;
                final inc = (m['income'] as num).toDouble();
                final exp = (m['expense'] as num).toDouble();
                final sav = (m['savings'] as num).toDouble();
                final mom = (m['momGrowth'] as num).toDouble();

                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          inc > 0 ? '+${CurrencyFormatter.format(inc, symbol: curr)}' : '$curr 0',
                          style: TextStyle(
                            fontSize: 12,
                            color: inc > 0 ? AppColors.income : (isDark ? Colors.grey[500] : Colors.grey[400]),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          exp > 0 ? '-${CurrencyFormatter.format(exp, symbol: curr)}' : '$curr 0',
                          style: TextStyle(
                            fontSize: 12,
                            color: exp > 0 ? AppColors.expense : (isDark ? Colors.grey[500] : Colors.grey[400]),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${sav >= 0 ? "+" : ""}${CurrencyFormatter.format(sav, symbol: curr)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: sav > 0 ? AppColors.income : (sav < 0 ? AppColors.expense : Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: idx == 0
                          ? Text('Base', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[400]))
                          : Row(
                              children: [
                                Icon(
                                  mom >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  size: 12,
                                  color: mom >= 0 ? AppColors.income : AppColors.expense,
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    '${mom >= 0 ? "+" : ""}${mom.abs().toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: mom >= 0 ? AppColors.income : AppColors.expense,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiMonthCategoryBreakdownSection(String curr, bool isDark) {
    final incomeMap = <String, Map<String, dynamic>>{};
    final expenseMap = <String, Map<String, dynamic>>{};
    double multiMonthIncomeTotal = 0.0;
    double multiMonthExpenseTotal = 0.0;

    for (final row in _multiMonthCategoryTrends) {
      final type = row['type'] as String;
      final name = row['categoryName'] as String;
      final amount = (row['amount'] as num).toDouble();
      final color = row['categoryColor'] as String;
      final icon = row['categoryIcon'] as String;

      if (type == 'income') {
        multiMonthIncomeTotal += amount;
        if (incomeMap.containsKey(name)) {
          incomeMap[name]!['amount'] = (incomeMap[name]!['amount'] as double) + amount;
        } else {
          incomeMap[name] = {'name': name, 'amount': amount, 'color': color, 'icon': icon};
        }
      } else if (type == 'expense') {
        multiMonthExpenseTotal += amount;
        if (expenseMap.containsKey(name)) {
          expenseMap[name]!['amount'] = (expenseMap[name]!['amount'] as double) + amount;
        } else {
          expenseMap[name] = {'name': name, 'amount': amount, 'color': color, 'icon': icon};
        }
      }
    }

    final topIncomeList = incomeMap.values.toList()
      ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    final topExpenseList = expenseMap.values.toList()
      ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.pie_chart_outline_rounded, size: 18, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  const Text(
                    'Multi-Month Category Trends',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Income & Expense',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Aggregated category performance across the past 6 months',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          if (topIncomeList.isEmpty && topExpenseList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No multi-month category data recorded yet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Income Column
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_circle_up_rounded, size: 16, color: AppColors.income),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Text(
                                'Top Inflows (6-Mo)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (topIncomeList.isEmpty)
                          Text('No income streams', style: TextStyle(fontSize: 11, color: Colors.grey[500]))
                        else
                          ...topIncomeList.take(5).map((cat) {
                            final amt = cat['amount'] as double;
                            final pct = multiMonthIncomeTotal > 0 ? (amt / multiMonthIncomeTotal * 100) : 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          cat['name'] as String,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '+${CurrencyFormatter.formatCompact(amt, symbol: curr)}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.income),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                            value: (pct / 100).clamp(0.0, 1.0),
                                            minHeight: 4,
                                            backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFE2E8F0),
                                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.income),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${pct.toStringAsFixed(0)}%',
                                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Top Expense Column
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_circle_down_rounded, size: 16, color: AppColors.expense),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Text(
                                'Top Outflows (6-Mo)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (topExpenseList.isEmpty)
                          Text('No expense categories', style: TextStyle(fontSize: 11, color: Colors.grey[500]))
                        else
                          ...topExpenseList.take(5).map((cat) {
                            final amt = cat['amount'] as double;
                            final pct = multiMonthExpenseTotal > 0 ? (amt / multiMonthExpenseTotal * 100) : 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          cat['name'] as String,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '-${CurrencyFormatter.formatCompact(amt, symbol: curr)}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.expense),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                            value: (pct / 100).clamp(0.0, 1.0),
                                            minHeight: 4,
                                            backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFE2E8F0),
                                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.expense),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${pct.toStringAsFixed(0)}%',
                                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTrendStatCard(String title, String val, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              val,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 4: FILTERED RECORDS TABLE
  // =========================================================================
  Widget _buildFilteredRecordsTab(String curr, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Filtered Transactions (${_filteredTransactions.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Export Filtered CSV'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const ExportDataDialog(),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        TransactionRecordsTable(
          transactions: _filteredTransactions,
          currency: curr,
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
