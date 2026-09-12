import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/investment.dart';
import '../../providers/investment_provider.dart';
import '../../providers/settings_provider.dart';
import 'investment_form_dialog.dart';

class InvestmentsScreen extends ConsumerStatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  ConsumerState<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends ConsumerState<InvestmentsScreen> {
  String _filterType = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddInvestment() {
    showDialog(
      context: context,
      builder: (_) => const InvestmentFormDialog(),
    );
  }

  void _openEditInvestment(Investment inv) {
    showDialog(
      context: context,
      builder: (_) => InvestmentFormDialog(investmentToEdit: inv),
    );
  }

  void _confirmDelete(Investment inv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Investment?'),
          ],
        ),
        content: Text('Are you sure you want to remove "${inv.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(investmentProvider.notifier).deleteInvestment(inv.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openQuickValueUpdate(Investment inv, String curr) {
    final controller = TextEditingController(text: inv.currentValue.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Value: ${inv.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter updated valuation from your broker or bank statement:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Current Market Value',
                prefixText: '$curr ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                Navigator.pop(ctx);
                ref.read(investmentProvider.notifier).updateInvestment(
                      inv.copyWith(currentValue: val),
                    );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(InvestmentType type) {
    switch (type) {
      case InvestmentType.fd:
        return Icons.lock_clock_rounded;
      case InvestmentType.rd:
        return Icons.update_rounded;
      case InvestmentType.mutualFund:
        return Icons.pie_chart_rounded;
      case InvestmentType.stock:
        return Icons.show_chart_rounded;
      case InvestmentType.bond:
        return Icons.receipt_rounded;
      case InvestmentType.other:
        return Icons.savings_rounded;
    }
  }

  Color _getColorForType(InvestmentType type) {
    switch (type) {
      case InvestmentType.fd:
        return const Color(0xFF3B82F6);
      case InvestmentType.rd:
        return const Color(0xFF06B6D4);
      case InvestmentType.mutualFund:
        return const Color(0xFF8B5CF6);
      case InvestmentType.stock:
        return const Color(0xFF10B981);
      case InvestmentType.bond:
        return const Color(0xFFF59E0B);
      case InvestmentType.other:
        return const Color(0xFFEC4899);
    }
  }

  @override
  Widget build(BuildContext context) {
    final investmentState = ref.watch(investmentProvider);
    final summary = ref.watch(investmentSummaryProvider);
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var investments = investmentState.investments;

    // Filter by type
    if (_filterType != 'all') {
      investments = investments.where((i) => i.type.code == _filterType).toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      investments = investments.where((i) {
        final nameMatches = i.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final notesMatches = i.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
        return nameMatches || notesMatches;
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investments & Portfolios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Investment',
            onPressed: _openAddInvestment,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.read(investmentProvider.notifier).loadInvestments(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddInvestment,
        backgroundColor: AppColors.investment,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Investment', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(investmentProvider.notifier).loadInvestments(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Executive Portfolio Performance Card
            _buildPortfolioSummaryCard(summary, curr, isDark),
            const SizedBox(height: 16),

            // 2. Search & Filter Bar
            _buildSearchAndFilters(isDark),
            const SizedBox(height: 16),

            // 3. Investments List
            if (investmentState.isLoading && investments.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (investments.isEmpty)
              _buildEmptyState(isDark)
            else
              ...investments.map((inv) => _buildInvestmentCard(inv, curr, isDark)),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioSummaryCard(Map<String, dynamic> summary, String curr, bool isDark) {
    final totalInvested = summary['totalInvested'] as double? ?? 0.0;
    final totalCurrentValue = summary['totalCurrentValue'] as double? ?? 0.0;
    final totalProfitLoss = summary['totalProfitLoss'] as double? ?? 0.0;
    final totalProfitLossPercent = summary['totalProfitLossPercent'] as double? ?? 0.0;
    final totalExpectedReturns = summary['totalExpectedReturns'] as double? ?? 0.0;
    final isProfitable = summary['isProfitable'] as bool? ?? true;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Portfolio Performance',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isProfitable ? AppColors.income : AppColors.expense).withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isProfitable ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                      color: isProfitable ? AppColors.income : AppColors.expense,
                      size: 20,
                    ),
                    Text(
                      '${isProfitable ? "+" : ""}${totalProfitLossPercent.toStringAsFixed(1)}% ROI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isProfitable ? AppColors.income : AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Invested', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(totalInvested, symbol: curr),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Value', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(totalCurrentValue, symbol: curr),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Profit / Loss', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${totalProfitLoss >= 0 ? "+" : ""}${CurrencyFormatter.format(totalProfitLoss, symbol: curr)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isProfitable ? AppColors.income : AppColors.expense,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Expected Gains', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(totalExpectedReturns, symbol: curr),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.investment),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search investment name, notes, folio...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            isDense: true,
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('all', 'All Investments'),
              const SizedBox(width: 8),
              _filterChip('fd', 'Fixed Deposits (FD)'),
              const SizedBox(width: 8),
              _filterChip('rd', 'Recurring Deposits (RD)'),
              const SizedBox(width: 8),
              _filterChip('mutual_fund', 'Mutual Funds'),
              const SizedBox(width: 8),
              _filterChip('stock', 'Stocks & Equity'),
              const SizedBox(width: 8),
              _filterChip('bond', 'Bonds & Debentures'),
              const SizedBox(width: 8),
              _filterChip('other', 'Other Assets'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String code, String label) {
    final isSelected = _filterType == code;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _filterType = code);
      },
    );
  }

  Widget _buildInvestmentCard(Investment inv, String curr, bool isDark) {
    final color = _getColorForType(inv.type);
    final icon = _getIconForType(inv.type);
    final isProfitable = inv.isProfitable;
    final pnl = inv.profitLoss;
    final pnlPct = inv.profitLossPercentage;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inv.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(20),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    inv.type.displayName,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                                  ),
                                ),
                                if (inv.frequency != null && inv.frequency != 'One-time') ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      '• ${inv.frequency}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (val) {
                    if (val == 'update_val') {
                      _openQuickValueUpdate(inv, curr);
                    } else if (val == 'edit') {
                      _openEditInvestment(inv);
                    } else if (val == 'delete') {
                      _confirmDelete(inv);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'update_val',
                      child: Row(
                        children: [
                          Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Update Current Value'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Details'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Financial Values Grid
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Invested', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(inv.investedAmount, symbol: curr),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                      const Text('Current Value', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(inv.currentValue, symbol: curr),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                      const Text('Profit / Loss', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${pnl >= 0 ? "+" : ""}${CurrencyFormatter.format(pnl, symbol: curr)} (${pnlPct.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isProfitable ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Dates & Maturity Details
            if (inv.expectedReturnRate > 0 || inv.maturityDate != null || inv.maturityAmount != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (inv.expectedReturnRate > 0)
                    _detailBadge('Rate', '${inv.expectedReturnRate}% p.a.', color: color),
                  if (inv.maturityAmount != null)
                    _detailBadge('Maturity Value', CurrencyFormatter.format(inv.maturityAmount!, symbol: curr)),
                  if (inv.maturityDate != null)
                    _detailBadge('Matures', DateFormat('dd MMM yyyy').format(inv.maturityDate!)),
                  _detailBadge('Started', DateFormat('dd MMM yyyy').format(inv.startDate)),
                ],
              ),
            ],

            if (inv.notes != null && inv.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                inv.notes!,
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailBadge(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, color: color ?? Colors.grey[700], fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.investment.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.trending_up_rounded, size: 48, color: AppColors.investment),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Investments Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Track Fixed Deposits, Recurring Deposits, Mutual Funds, Stocks, and Bonds with automatic returns calculation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Your First Investment'),
              onPressed: _openAddInvestment,
            ),
          ],
        ),
      ),
    );
  }
}
