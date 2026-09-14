import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../data/models/report.dart';
import '../../providers/account_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/investment_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../reports/reports_screen.dart';
import 'widgets/budget_progress_card.dart';
import 'widgets/financial_runway_card.dart';
import 'widgets/income_vs_expense_donut_card.dart';
import 'widgets/investment_portfolio_card.dart';
import 'widgets/kpi_summary_metric_card.dart';
import 'widgets/net_worth_growth_card.dart';
import 'widgets/savings_goal_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _selectedPeriod = 'Last 6 Months';
  final List<String> _periodOptions = [
    'Last 6 Months',
    'This Month',
    'Last 30 Days',
    'This Year',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(recurringProvider.notifier).processDue();
    });
  }

  (DateTime, DateTime) _resolveDateRange(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'This Month':
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59)
        );
      case 'Last 30 Days':
        return (now.subtract(const Duration(days: 30)), now);
      case 'This Year':
        return (
          DateTime(now.year, 1, 1),
          DateTime(now.year, 12, 31, 23, 59, 59)
        );
      case 'Last 6 Months':
      default:
        return (
          DateTime(now.year, now.month - 5, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59)
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountProvider);
    final txState = ref.watch(transactionProvider);
    final settings = ref.watch(settingsProvider);
    final budgetState = ref.watch(budgetProvider);
    final investmentState = ref.watch(investmentProvider);
    final goalsAsync = ref.watch(goalProvider);
    final goals = goalsAsync.value ?? [];

    final allTxsAsync = ref.watch(allTransactionsProvider);
    final allTransactions = allTxsAsync.value ?? txState.transactions;
    final curr = settings.currency;

    // Financial Metrics
    final netWorth = accountState.netWorthSummary['netWorth'] ?? 0.0;
    final totalAssets = accountState.netWorthSummary['totalAssets'] ?? 0.0;
    final totalLiabilities = accountState.netWorthSummary['totalLiabilities'] ?? 0.0;
    final totalInvestments = accountState.netWorthSummary['totalInvestments'] ?? 0.0;
    final totalBank = accountState.netWorthSummary['totalBank'] ?? 0.0;
    final totalCash = accountState.netWorthSummary['totalCash'] ?? 0.0;
    final liquidAssets = totalBank + totalCash;

    // Period Cash Flow
    final (start, end) = _resolveDateRange(_selectedPeriod);
    final periodTxs = allTransactions.where((t) {
      return t.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          t.date.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    final income = periodTxs.where((t) => t.isIncome).fold<double>(0.0, (s, t) => s + t.amount);
    final expense = periodTxs.where((t) => t.isExpense).fold<double>(0.0, (s, t) => s + t.amount);

    // Financial Runway
    final daysInPeriod = max(1, end.difference(start).inDays + 1);
    final runway = RunwayMetrics.compute(
      liquidAssets: liquidAssets,
      totalInflow: income,
      totalOutflow: expense,
      daysInPeriod: daysInPeriod,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Center(
            child: AppLogo(
              size: 32,
              borderRadius: 8,
              showShadow: true,
            ),
          ),
        ),
        leadingWidth: 52,
        title: const Text(
          'Personal Finance',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Financial Reports',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
              ref.read(settingsProvider.notifier).setThemeMode(newMode);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Synchronize Data',
            onPressed: () {
              ref.invalidate(allTransactionsProvider);
              ref.read(accountProvider.notifier).loadAccounts();
              ref.read(transactionProvider.notifier).loadTransactions();
              ref.read(recurringProvider.notifier).loadRecurring();
              ref.read(investmentProvider.notifier).loadInvestments();
              ref.read(loanProvider.notifier).loadLoans();
              ref.read(goalProvider.notifier).loadGoals();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allTransactionsProvider);
          await ref.read(accountProvider.notifier).loadAccounts();
          await ref.read(transactionProvider.notifier).loadTransactions();
          await ref.read(recurringProvider.notifier).loadRecurring();
          await ref.read(investmentProvider.notifier).loadInvestments();
          await ref.read(loanProvider.notifier).loadLoans();
          await ref.read(goalProvider.notifier).loadGoals();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isDesktop = width >= 1100;
              final isTablet = width >= 680 && width < 1100;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Dashboard Header Section
                  _buildHeaderSection(isDark),
                  const SizedBox(height: 18),

                  // 2. Top 3 KPI Summary Cards
                  _buildKpiSummaryRow(
                    totalAssets: totalAssets,
                    totalLiabilities: totalLiabilities,
                    netWorth: netWorth,
                    currency: curr,
                    isWide: width >= 700,
                  ),
                  const SizedBox(height: 20),

                  // 3. 6 Visual Overview Cards in Grid
                  _buildVisualCardsGrid(
                    width: width,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    netWorth: netWorth,
                    allTransactions: allTransactions,
                    curr: curr,
                    income: income,
                    expense: expense,
                    totalBudgeted: budgetState.totalBudgeted,
                    totalSpent: budgetState.totalSpent,
                    investments: investmentState.investments,
                    totalInvestments: totalInvestments,
                    runway: runway,
                    liquidAssets: liquidAssets,
                    goals: goals,
                    startDate: start,
                    endDate: end,
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // HEADER SECTION (Title, Subtitle & Period Dropdown)
  // =========================================================================
  Widget _buildHeaderSection(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 540;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Overview',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Your complete financial picture at a glance',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
            ),
          ],
        );

        final dropdownBlock = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPeriod,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isDark ? Colors.grey[300] : const Color(0xFF475569),
              ),
              borderRadius: BorderRadius.circular(12),
              dropdownColor: isDark ? AppColors.darkCard : Colors.white,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              items: _periodOptions.map((period) {
                return DropdownMenuItem<String>(
                  value: period,
                  child: Text(period),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedPeriod = val;
                  });
                }
              },
            ),
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 12),
              dropdownBlock,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 12),
            dropdownBlock,
          ],
        );
      },
    );
  }

  // =========================================================================
  // TOP 3 KPI SUMMARY ROW
  // =========================================================================
  Widget _buildKpiSummaryRow({
    required double totalAssets,
    required double totalLiabilities,
    required double netWorth,
    required String currency,
    required bool isWide,
  }) {
    final assetCard = KpiSummaryMetricCard(
      title: 'Total Assets',
      amount: totalAssets,
      currency: currency,
      icon: Icons.account_balance_wallet_outlined,
      accentColor: const Color(0xFF16A34A),
    );

    final liabilityCard = KpiSummaryMetricCard(
      title: 'Total Liabilities',
      amount: totalLiabilities,
      currency: currency,
      icon: Icons.receipt_long_outlined,
      accentColor: const Color(0xFF2563EB),
    );

    final netWorthCard = KpiSummaryMetricCard(
      title: 'Net Worth',
      amount: netWorth,
      currency: currency,
      icon: Icons.shield_outlined,
      accentColor: const Color(0xFF059669),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: assetCard),
          const SizedBox(width: 14),
          Expanded(child: liabilityCard),
          const SizedBox(width: 14),
          Expanded(child: netWorthCard),
        ],
      );
    }

    return Column(
      children: [
        assetCard,
        const SizedBox(height: 10),
        liabilityCard,
        const SizedBox(height: 10),
        netWorthCard,
      ],
    );
  }

  // =========================================================================
  // 6 VISUAL OVERVIEW CARDS IN GRID
  // =========================================================================
  Widget _buildVisualCardsGrid({
    required double width,
    required bool isDesktop,
    required bool isTablet,
    required double netWorth,
    required List<dynamic> allTransactions,
    required String curr,
    required double income,
    required double expense,
    required double totalBudgeted,
    required double totalSpent,
    required List<dynamic> investments,
    required double totalInvestments,
    required RunwayMetrics runway,
    required double liquidAssets,
    required List<dynamic> goals,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    const double cardHeight = 290.0;

    final cards = [
      NetWorthGrowthCard(
        currentNetWorth: netWorth,
        transactions: allTransactions.cast(),
        currency: curr,
        height: cardHeight,
        startDate: startDate,
        endDate: endDate,
      ),
      IncomeVsExpenseDonutCard(
        income: income,
        expense: expense,
        currency: curr,
        height: cardHeight,
      ),
      BudgetProgressCard(
        totalBudgeted: totalBudgeted,
        totalSpent: totalSpent,
        currency: curr,
        height: cardHeight,
      ),
      InvestmentPortfolioCard(
        investments: investments.cast(),
        totalInvestmentsValuation: totalInvestments,
        currency: curr,
        height: cardHeight,
        startDate: startDate,
        endDate: endDate,
      ),
      FinancialRunwayCard(
        runwayDays: runway.runwayDays,
        isInfiniteRunway: runway.isInfiniteRunway,
        avgMonthlyOutflow: runway.avgMonthlyOutflow,
        liquidAssets: liquidAssets,
        currency: curr,
        height: cardHeight,
      ),
      SavingsGoalCard(
        goals: goals.cast(),
        currency: curr,
        height: cardHeight,
      ),
    ];

    final int crossAxisCount;
    if (isDesktop) {
      crossAxisCount = 3;
    } else if (isTablet) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 1;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: cardHeight,
        crossAxisSpacing: 14.0,
        mainAxisSpacing: 14.0,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) => cards[index],
    );
  }
}
