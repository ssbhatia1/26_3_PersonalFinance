import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/budget.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import 'budget_detail_screen.dart';
import 'budget_form_dialog.dart';
import 'widgets/budget_card.dart';
import 'widgets/budget_history_tab.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddBudget(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const BudgetFormDialog(),
    );
  }

  void _openBudgetDetails(BuildContext context, Budget budget) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BudgetDetailScreen(budget: budget),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgetState = ref.watch(budgetProvider);
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentMonth = budgetState.selectedMonth;
    final now = DateTime.now();
    final isCurrentMonth = currentMonth.year == now.year && currentMonth.month == now.month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets & Spending'),
        actions: [
          if (!isCurrentMonth)
            TextButton.icon(
              onPressed: () {
                ref.read(budgetProvider.notifier).changeMonth(DateTime(now.year, now.month));
              },
              icon: const Icon(Icons.today_rounded, size: 16),
              label: const Text('Today'),
            ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Budget',
            onPressed: () => _openAddBudget(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pie_chart_rounded, size: 18),
                  const SizedBox(width: 8),
                  const Text('Active Budgets'),
                  if (budgetState.budgets.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${budgetState.budgets.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Budget History'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Active Budgets
          _buildActiveBudgetsView(context, budgetState, curr, isDark, currentMonth, isCurrentMonth),

          // Tab 2: Budget History
          const BudgetHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddBudget(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Budget', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildActiveBudgetsView(
    BuildContext context,
    BudgetState state,
    String curr,
    bool isDark,
    DateTime currentMonth,
    bool isCurrentMonth,
  ) {
    final filteredBudgets = state.filteredBudgets;

    return Column(
      children: [
        // Month Selector Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous Month',
                onPressed: () {
                  final prev = DateTime(currentMonth.year, currentMonth.month - 1);
                  ref.read(budgetProvider.notifier).changeMonth(prev);
                },
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    DateFormatter.formatMonthYear(currentMonth),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next Month',
                onPressed: () {
                  final next = DateTime(currentMonth.year, currentMonth.month + 1);
                  ref.read(budgetProvider.notifier).changeMonth(next);
                },
              ),
            ],
          ),
        ),

        // Period & Scope Filter Chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all', 'All (${state.budgets.length})', state.selectedPeriodFilter),
                const SizedBox(width: 8),
                _filterChip('categorized', 'Categorized (${state.categorizedBudgets.length})', state.selectedPeriodFilter),
                const SizedBox(width: 8),
                _filterChip('monthly', 'Monthly', state.selectedPeriodFilter),
                const SizedBox(width: 8),
                _filterChip('longterm', 'Long-Term (${state.longTermBudgets.length})', state.selectedPeriodFilter),
                const SizedBox(width: 8),
                _filterChip('weekly', 'Weekly', state.selectedPeriodFilter),
                const SizedBox(width: 8),
                _filterChip('custom', 'Custom Range', state.selectedPeriodFilter),
              ],
            ),
          ),
        ),

        // Main Scrollable Content
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(budgetProvider.notifier).loadBudgets(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Alert Summary Banner (Feature 7)
                if (state.totalAlertsCount > 0) ...[
                  _buildAlertSummaryBanner(state, isDark),
                  const SizedBox(height: 16),
                ],

                // Overall Monthly Summary Card (Feature 1)
                _buildOverallCard(state, curr, isDark),
                const SizedBox(height: 20),

                // Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Category Budgets (${filteredBudgets.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: () => _openAddBudget(context),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: const Text('Add Budget'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Budgets List or Empty State
                if (filteredBudgets.isEmpty)
                  _buildEmptyState(context, state.selectedPeriodFilter)
                else
                  ...filteredBudgets.map(
                    (b) => BudgetCard(
                      budget: b,
                      currency: curr,
                      onTap: () => _openBudgetDetails(context, b),
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String filterKey, String label, String activeFilter) {
    final isSelected = filterKey.toLowerCase() == activeFilter.toLowerCase();
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withAlpha(35),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : null,
      ),
      onSelected: (_) {
        ref.read(budgetProvider.notifier).setPeriodFilter(filterKey);
      },
    );
  }

  Widget _buildAlertSummaryBanner(BudgetState state, bool isDark) {
    Color bannerColor;
    IconData icon;
    if (state.overBudgetCount > 0) {
      bannerColor = AppColors.error;
      icon = Icons.error_outline_rounded;
    } else if (state.criticalCount > 0) {
      bannerColor = AppColors.warning;
      icon = Icons.warning_amber_rounded;
    } else {
      bannerColor = AppColors.warning;
      icon = Icons.info_outline_rounded;
    }

    final alerts = <String>[];
    if (state.overBudgetCount > 0) alerts.add('${state.overBudgetCount} Over Budget');
    if (state.criticalCount > 0) alerts.add('${state.criticalCount} Critical (≥90%)');
    if (state.nearLimitCount > 0) alerts.add('${state.nearLimitCount} Near Limit (≥75%)');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bannerColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerColor.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, color: bannerColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Budget Alerts: ${alerts.join(" • ")}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: bannerColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallCard(BudgetState state, String curr, bool isDark) {
    final pct = state.overallProgress;
    final isOver = state.totalSpent > state.totalBudgeted && state.totalBudgeted > 0;
    Color statusColor = isOver
        ? AppColors.error
        : (pct >= 0.90
            ? AppColors.liability
            : (pct >= 0.75 ? AppColors.warning : AppColors.primary));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dashboard_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Total Budget Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Text(
                    '${(pct * 100).toStringAsFixed(0)}% Used',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct > 1.0 ? 1.0 : pct,
                minHeight: 10,
                backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryColumn('Total Budget', state.totalBudgeted, curr),
                _summaryColumn('Total Spent', state.totalSpent, curr, color: isOver ? AppColors.error : null),
                _summaryColumn(
                  isOver ? 'Overspent' : 'Remaining',
                  state.totalRemaining >= 0 ? state.totalRemaining : -state.totalRemaining,
                  curr,
                  color: state.totalRemaining >= 0 ? AppColors.income : AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: 14),
            // How many days the budget will stay
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hourglass_bottom_rounded, size: 15, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        state.currentMonthDaysRemaining > 0
                            ? '${state.currentMonthDaysRemaining} days remaining in ${DateFormatter.formatMonthYear(state.selectedMonth)}'
                            : 'Budget period completed',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (state.totalRemaining > 0 && state.currentMonthDaysRemaining > 0)
                    Text(
                      'Safe pace: $curr ${(state.totalRemaining / state.currentMonthDaysRemaining).toStringAsFixed(0)}/day',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.income,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryColumn(String label, double amount, String curr, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.format(amount, symbol: curr),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String filter) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.pie_chart_outline_rounded, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              filter == 'all'
                  ? 'No budgets set for this month'
                  : 'No ${filter.toLowerCase()} budgets set',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Set spending caps on expense categories to stay proactive and maintain financial discipline.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _openAddBudget(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Category Budget'),
            ),
          ],
        ),
      ),
    );
  }
}

