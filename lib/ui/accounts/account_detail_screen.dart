import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/account.dart';
import '../../data/models/account_adjustment.dart';
import '../../data/models/transaction.dart';
import '../../providers/account_detail_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../settings/export_data_dialog.dart';
import '../transactions/transaction_form_screen.dart';
import 'account_form_dialog.dart';
import 'delete_account_dialog.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  final String accountId;
  final int initialTabIndex;

  const AccountDetailScreen({
    super.key,
    required this.accountId,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openAccountAdjustment(BuildContext context, Account account) {
    _openEditAccount(context, account);
  }

  void _openAddTransaction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionFormScreen(preselectedAccountId: widget.accountId),
    ).then((_) {
      ref.read(accountDetailProvider(widget.accountId).notifier).loadAll();
    });
  }

  void _openEditAccount(BuildContext context, Account account) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AccountFormDialog(accountToEdit: account),
    ).then((saved) {
      if (saved == true || saved == null) {
        ref.read(accountDetailProvider(widget.accountId).notifier).loadAll();
        ref.read(accountProvider.notifier).loadAccounts();
        if (saved == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account settings updated successfully'),
              backgroundColor: AppColors.income,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  Future<void> _openDeleteAccount(BuildContext context, Account account) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (ctx) => DeleteAccountDialog(account: account),
    );

    if (deleted == true && mounted) {
      Navigator.of(context).pop(); // Exit account details screen
    }
  }

  void _openExportStatement(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ExportDataDialog(initialAccountId: widget.accountId),
    );
  }

  void _confirmDeleteTransaction(BuildContext context, String txId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('This will delete the transaction and mathematically reverse its balance effect.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(accountDetailProvider(widget.accountId).notifier).deleteTransaction(txId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final detailState = ref.read(accountDetailProvider(widget.accountId));
    final initialRange = DateTimeRange(
      start: detailState.startDateFilter ?? DateTime.now().subtract(const Duration(days: 30)),
      end: detailState.endDateFilter ?? DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      ref.read(accountDetailProvider(widget.accountId).notifier).setDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(accountDetailProvider(widget.accountId));
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final account = detailState.account;

    if (detailState.isLoading && account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Not Found')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Account could not be found or has been deleted.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Accounts'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Add Transaction',
            onPressed: () => _openAddTransaction(context),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Account',
            onPressed: () => _openEditAccount(context, account),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'adjust') {
                _openAccountAdjustment(context, account);
              } else if (val == 'edit') {
                _openEditAccount(context, account);
              } else if (val == 'export') {
                _openExportStatement(context);
              } else if (val == 'delete') {
                _openDeleteAccount(context, account);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'adjust',
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Adjust Account Balance'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Edit Account Details'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Export Statement (CSV)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Account', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Account Summary Card
          _buildAccountHeader(context, account, curr, isDark),

          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: [
              Tab(
                icon: const Icon(Icons.receipt_long_rounded),
                text: 'Transactions (${detailState.transactions.length})',
              ),
              const Tab(
                icon: Icon(Icons.pie_chart_rounded),
                text: 'Spending Details',
              ),
              const Tab(
                icon: Icon(Icons.history_rounded),
                text: 'Adjustments History',
              ),
              const Tab(
                icon: Icon(Icons.settings_rounded),
                text: 'Settings',
              ),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionsTab(context, detailState, account, curr, isDark),
                _buildSpendingTab(context, detailState, account, curr, isDark),
                _buildAdjustmentsTab(context, account, curr, isDark),
                _buildSettingsTab(context, account, curr, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HEADER CARD
  // ==========================================
  Widget _buildAccountHeader(BuildContext context, Account account, String curr, bool isDark) {
    final isNegative = account.currentBalance < 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        account.isCreditCard
                            ? Icons.credit_card_rounded
                            : (account.isLoan
                                ? Icons.handshake_rounded
                                : (account.type.toLowerCase().contains('cash')
                                    ? Icons.payments_rounded
                                    : Icons.account_balance_rounded)),
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            account.institution != null ? '${account.institution} • ${account.type}' : account.type,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Current Balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Current Balance', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      CurrencyFormatter.format(account.currentBalance, symbol: curr),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: isNegative ? AppColors.expense : AppColors.income,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Account Attribute Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _metricBadge('Opening Balance', CurrencyFormatter.format(account.openingBalance, symbol: curr)),
              if (account.isCreditCard) ...[
                _metricBadge('Credit Limit', CurrencyFormatter.format(account.creditLimit, symbol: curr)),
                _metricBadge('Available Credit', CurrencyFormatter.format(account.availableCredit, symbol: curr), color: AppColors.asset),
              ],
              if (account.interestRate > 0)
                _metricBadge('Interest Rate', '${account.interestRate}%', color: AppColors.liability),
              if (account.maskedReference != null)
                _metricBadge('Ref', account.maskedReference!),
              _metricBadge('Status', account.status.toUpperCase(), color: AppColors.success),
            ],
          ),
          const SizedBox(height: 12),
          // Quick Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
                label: const Text('Adjust Balance'),
                onPressed: () => _openAccountAdjustment(context, account),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New Entry'),
                onPressed: () => _openAddTransaction(context),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Statement'),
                onPressed: () => _openExportStatement(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBadge(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color ?? AppColors.primary),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: VIEW TRANSACTIONS
  // ==========================================
  Widget _buildTransactionsTab(
    BuildContext context,
    AccountDetailState state,
    Account account,
    String curr,
    bool isDark,
  ) {
    final notifier = ref.read(accountDetailProvider(widget.accountId).notifier);
    final transactions = state.transactions;

    return Column(
      children: [
        // Filter & Sort Controls
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              // Search input
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search description, payee, ref...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            notifier.setSearchQuery('');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) => notifier.setSearchQuery(val),
              ),
              const SizedBox(height: 10),

              // Filter Chips row & sorting
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _typeFilterChip('all', 'All', state.typeFilter, notifier),
                    const SizedBox(width: 6),
                    _typeFilterChip('expense', 'Expenses', state.typeFilter, notifier, color: AppColors.expense),
                    const SizedBox(width: 6),
                    _typeFilterChip('income', 'Income', state.typeFilter, notifier, color: AppColors.income),
                    const SizedBox(width: 6),
                    _typeFilterChip('transfer', 'Transfers', state.typeFilter, notifier, color: AppColors.transfer),
                    const SizedBox(width: 12),

                    // Category dropdown
                    _buildCategoryDropdown(state, notifier),
                    const SizedBox(width: 8),

                    // Date range picker button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        side: BorderSide(
                          color: (state.startDateFilter != null || state.endDateFilter != null)
                              ? AppColors.primary
                              : Colors.grey.withAlpha(80),
                        ),
                      ),
                      onPressed: () => _selectDateRange(context),
                      icon: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: Text(
                        state.startDateFilter != null
                            ? '${DateFormat('dd MMM').format(state.startDateFilter!)} - ${DateFormat('dd MMM').format(state.endDateFilter!)}'
                            : 'Date Range',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (state.startDateFilter != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        tooltip: 'Clear Date Filter',
                        onPressed: () => notifier.setDateRange(null, null),
                      ),
                    ],

                    const SizedBox(width: 8),
                    // Sorting dropdown
                    _buildSortDropdown(state, notifier),

                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.file_download_outlined, size: 20),
                      tooltip: 'Export Statement (CSV)',
                      onPressed: () => _openExportStatement(context),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                      tooltip: 'Reset Filters',
                      onPressed: () {
                        _searchController.clear();
                        notifier.resetTransactionFilters();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Summary Ribbon for filtered transactions
        Container(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${transactions.length} record${transactions.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    children: [
                      Text(
                        'In: +${CurrencyFormatter.formatCompact(state.totalCredits, symbol: curr)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.income),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Out: -${CurrencyFormatter.formatCompact(state.totalDebits, symbol: curr)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.expense),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Net: ${state.netImpact >= 0 ? '+' : ''}${CurrencyFormatter.formatCompact(state.netImpact, symbol: curr)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: state.netImpact >= 0 ? AppColors.income : AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Transactions List
        Expanded(
          child: transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'No transactions found for this account',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          notifier.resetTransactionFilters();
                        },
                        child: const Text('Reset All Filters'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final tx = transactions[idx];
                    return _buildTransactionTile(context, tx, account, curr, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _typeFilterChip(
    String typeKey,
    String label,
    String currentType,
    AccountDetailNotifier notifier, {
    Color? color,
  }) {
    final isSelected = currentType == typeKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => notifier.setFilterType(typeKey),
      selectedColor: (color ?? AppColors.primary).withAlpha(40),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? (color ?? AppColors.primary) : null,
      ),
    );
  }

  Widget _buildCategoryDropdown(AccountDetailState state, AccountDetailNotifier notifier) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: state.categoryIdFilter ?? 'all',
        isDense: true,
        style: const TextStyle(fontSize: 12),
        items: [
          const DropdownMenuItem(value: 'all', child: Text('All Categories')),
          ...state.categories.map((c) => DropdownMenuItem(
                value: c.id,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(int.tryParse(c.color) ?? 0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(c.name),
                  ],
                ),
              )),
        ],
        onChanged: (val) => notifier.setCategoryFilter(val),
      ),
    );
  }

  Widget _buildSortDropdown(AccountDetailState state, AccountDetailNotifier notifier) {
    return PopupMenuButton<String>(
      tooltip: 'Sort Transactions',
      icon: const Icon(Icons.sort_rounded, size: 20),
      initialValue: state.sortBy,
      onSelected: (val) => notifier.setSortBy(val),
      itemBuilder: (ctx) => const [
        PopupMenuItem(value: 'date_desc', child: Text('Date: Newest First')),
        PopupMenuItem(value: 'date_asc', child: Text('Date: Oldest First')),
        PopupMenuItem(value: 'amount_desc', child: Text('Amount: Highest First')),
        PopupMenuItem(value: 'amount_asc', child: Text('Amount: Lowest First')),
      ],
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    TransactionModel tx,
    Account account,
    String curr,
    bool isDark,
  ) {
    final impact = AccountDetailNotifier.getBalanceImpact(tx, widget.accountId);
    final isCredit = impact > 0;
    final isDebit = impact < 0;

    final impactColor = isCredit
        ? AppColors.income
        : (isDebit ? AppColors.expense : Colors.grey);

    final isTransfer = tx.isTransfer;
    final transferLabel = isTransfer
        ? (tx.sourceAccountId == widget.accountId
            ? 'Transfer Out → ${tx.destinationAccountName ?? "Account"}'
            : 'Transfer In ← ${tx.sourceAccountName ?? "Account"}')
        : null;

    return ListTile(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => TransactionFormScreen(transactionToEdit: tx),
        ).then((_) {
          ref.read(accountDetailProvider(widget.accountId).notifier).loadAll();
          ref.read(accountProvider.notifier).loadAccounts();
        });
      },
      leading: CircleAvatar(
        backgroundColor: impactColor.withAlpha(25),
        child: Icon(
          isCredit
              ? Icons.arrow_downward_rounded
              : (isTransfer ? Icons.swap_horiz_rounded : Icons.arrow_upward_rounded),
          color: impactColor,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              tx.description?.isNotEmpty == true
                  ? tx.description!
                  : (tx.categoryName ?? (isTransfer ? 'Transfer' : 'Transaction')),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Raw transaction amount
          Text(
            CurrencyFormatter.format(tx.amount, symbol: curr),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormatter.formatDisplay(tx.date),
                        style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                      ),
                      const SizedBox(width: 8),
                      if (tx.paymentMethod != null && tx.paymentMethod!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tx.paymentMethod!,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (tx.categoryName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tx.categoryName!,
                            style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      if (tx.attachmentCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.attach_file_rounded, size: 11, color: AppColors.primary),
                              const SizedBox(width: 2),
                              Text(
                                '${tx.attachmentCount}',
                                style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (transferLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(transferLabel, style: const TextStyle(fontSize: 11, color: AppColors.transfer)),
                  ],
                ],
              ),
            ),

            // Balance Impact Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: impactColor.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${isCredit ? '+' : (isDebit ? '-' : '')}${CurrencyFormatter.format(impact.abs(), symbol: curr)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: impactColor,
                ),
              ),
            ),
          ],
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
        onPressed: () => _confirmDeleteTransaction(context, tx.id),
      ),
    );
  }

  // ==========================================
  // TAB 2: ACCOUNT SPENDING DETAILS
  // ==========================================
  Widget _buildSpendingTab(
    BuildContext context,
    AccountDetailState state,
    Account account,
    String curr,
    bool isDark,
  ) {
    final notifier = ref.read(accountDetailProvider(widget.accountId).notifier);
    final period = state.spendingPeriodType;

    String periodTitle;
    if (period == 'daily') {
      periodTitle = DateFormat('EEE, dd MMM yyyy').format(state.spendingReferenceDate);
    } else if (period == 'weekly') {
      periodTitle = '${DateFormat('dd MMM').format(state.spendingStartDate)} - ${DateFormat('dd MMM yyyy').format(state.spendingEndDate)}';
    } else if (period == 'monthly') {
      periodTitle = DateFormat('MMMM yyyy').format(state.spendingReferenceDate);
    } else {
      periodTitle = 'Year ${DateFormat('yyyy').format(state.spendingReferenceDate)}';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Period Toggle Chips (Daily, Weekly, Monthly, Yearly)
        Center(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'daily', label: Text('Daily')),
              ButtonSegment(value: 'weekly', label: Text('Weekly')),
              ButtonSegment(value: 'monthly', label: Text('Monthly')),
              ButtonSegment(value: 'yearly', label: Text('Yearly')),
            ],
            selected: {period},
            onSelectionChanged: (set) {
              notifier.setSpendingPeriod(set.first);
            },
          ),
        ),
        const SizedBox(height: 12),

        // Period Navigation Header (< Period Title >)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous Period',
                onPressed: () => notifier.navigateSpendingPeriod(-1),
              ),
              Row(
                children: [
                  const Icon(Icons.date_range_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    periodTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next Period',
                onPressed: () => notifier.navigateSpendingPeriod(1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Total Spending KPI Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account Total Spending', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.format(state.totalSpending, symbol: curr),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    color: AppColors.expense,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _kpiMini('Expense Transactions', '${state.spendingTxCount}', Icons.receipt_rounded),
                    const SizedBox(width: 20),
                    _kpiMini('Average / Transaction', CurrencyFormatter.format(state.averagePerTransaction, symbol: curr), Icons.analytics_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (state.totalSpending == 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.savings_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      'No spending recorded for this account in $periodTitle',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          // Suitable Chart 1: Donut / Pie Chart for Category Breakdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      _touchedPieIndex = -1;
                                      return;
                                    }
                                    _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                  });
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: 46,
                              sections: _generatePieSections(state),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: state.categoryBreakdown.take(5).map((c) {
                                final color = Color(int.tryParse(c['categoryColor'] as String) ?? 0xFF10B981);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                                  child: Row(
                                    children: [
                                      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          c['categoryName'] as String,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text('${(c['percentage'] as double).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Suitable Chart 2: Spending Pattern Trend Bar Chart
          if (state.spendingTrend.any((item) => ((item['amount'] as num?)?.toDouble() ?? 0.0) > 0))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Spending Pattern Over Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(period.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _calculateMaxY(state.spendingTrend),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final item = state.spendingTrend[group.x.toInt()];
                                return BarTooltipItem(
                                  '${item['label']}\n${CurrencyFormatter.format(rod.toY, symbol: curr)}',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (val, meta) {
                                  if (val != val.roundToDouble()) return const SizedBox.shrink();
                                  final idx = val.round();
                                  if (idx < 0 || idx >= state.spendingTrend.length) return const SizedBox.shrink();
                                  final label = (state.spendingTrend[idx]['shortLabel'] ?? state.spendingTrend[idx]['label']) as String;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: false),
                          barGroups: state.spendingTrend.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final data = entry.value;
                            final amt = data['amount'] as double;
                            return BarChartGroupData(
                              x: idx,
                              barRods: [
                                BarChartRodData(
                                  toY: amt,
                                  color: AppColors.expense,
                                  width: period == 'daily' ? 14 : (period == 'monthly' ? 12 : 18),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Detailed Category Breakdown Progress List
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category Breakdown Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 14),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.categoryBreakdown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final c = state.categoryBreakdown[idx];
                      final amt = c['amount'] as double;
                      final pct = c['percentage'] as double;
                      final count = c['count'] as int;
                      final color = Color(int.tryParse(c['categoryColor'] as String) ?? 0xFF10B981);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    c['categoryName'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '($count txn${count == 1 ? '' : 's'})',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              Text(
                                '${CurrencyFormatter.format(amt, symbol: curr)} (${pct.toStringAsFixed(1)}%)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (pct / 100).clamp(0.0, 1.0),
                              color: color,
                              backgroundColor: color.withAlpha(40),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ],
    );
  }

  Widget _kpiMini(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  List<PieChartSectionData> _generatePieSections(AccountDetailState state) {
    return state.categoryBreakdown.asMap().entries.map((entry) {
      final idx = entry.key;
      final c = entry.value;
      final isTouched = idx == _touchedPieIndex;
      final radius = isTouched ? 48.0 : 40.0;
      final color = Color(int.tryParse(c['categoryColor'] as String) ?? 0xFF10B981);
      final pct = c['percentage'] as double;

      return PieChartSectionData(
        color: color,
        value: c['amount'] as double,
        title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
        radius: radius,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  double _calculateMaxY(List<Map<String, dynamic>> trend) {
    double maxVal = 0.0;
    for (final item in trend) {
      final amt = item['amount'] as double;
      if (amt > maxVal) maxVal = amt;
    }
    return maxVal == 0 ? 1000 : maxVal * 1.25;
  }

  // ==========================================
  // TAB 3: ACCOUNT SETTINGS & DELETE
  // ==========================================
  Widget _buildSettingsTab(BuildContext context, Account account, String curr, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Account Attributes Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Account Configuration',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _openEditAccount(context, account),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit Settings', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap any attribute or use Edit Settings to update details, balances, or configuration.',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                // Quick Status Toggle Chips
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account Operational Status',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: ['active', 'inactive', 'frozen', 'closed'].map((status) {
                          final isSelected = account.status.toLowerCase() == status;
                          return ChoiceChip(
                            label: Text(status.toUpperCase()),
                            selected: isSelected,
                            onSelected: (selected) async {
                              if (selected && !isSelected) {
                                try {
                                  final updated = account.copyWith(status: status);
                                  await ref.read(accountProvider.notifier).updateAccount(updated);
                                  await ref.read(accountDetailProvider(widget.accountId).notifier).loadAll();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Account status updated to ${status.toUpperCase()}'),
                                        backgroundColor: AppColors.income,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error updating status: $e'), backgroundColor: AppColors.error),
                                    );
                                  }
                                }
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _settingsRow('Account Name', account.name, onTap: () => _openEditAccount(context, account)),
                _settingsRow('Account Type', account.type, onTap: () => _openEditAccount(context, account)),
                _settingsRow('Institution', account.institution ?? 'None specified', onTap: () => _openEditAccount(context, account)),
                _settingsRow('Masked Reference', account.maskedReference ?? 'None', onTap: () => _openEditAccount(context, account)),
                _settingsRow('Opening Balance', CurrencyFormatter.format(account.openingBalance, symbol: curr), onTap: () => _openEditAccount(context, account)),
                _settingsRow('Current Balance', CurrencyFormatter.format(account.currentBalance, symbol: curr), onTap: () => _openEditAccount(context, account)),
                if (account.isCreditCard) ...[
                  _settingsRow('Credit Limit', CurrencyFormatter.format(account.creditLimit, symbol: curr), onTap: () => _openEditAccount(context, account)),
                  _settingsRow('Available Credit', CurrencyFormatter.format(account.availableCredit, symbol: curr), onTap: () => _openEditAccount(context, account)),
                ],
                _settingsRow('Interest Rate', '${account.interestRate}%', onTap: () => _openEditAccount(context, account)),
                _settingsRow('Status', account.status.toUpperCase(), onTap: () => _openEditAccount(context, account)),
                _settingsRow(
                  'Opening Date',
                  account.openedAt != null ? DateFormat('dd MMM yyyy').format(account.openedAt!) : 'Not recorded',
                  onTap: () => _openEditAccount(context, account),
                ),
                if (account.notes?.isNotEmpty == true)
                  _settingsRow('Notes', account.notes!, onTap: () => _openEditAccount(context, account)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Account ID: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Expanded(
                      child: Text(
                        account.id,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Copy ID',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: account.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Account ID copied to clipboard'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditAccount(context, account),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit Full Account Configuration'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Danger Zone: Delete Account
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.error, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_rounded, color: AppColors.error, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Danger Zone',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Deleting this account will permanently remove its associated transactions, spending records, and references from your ledger. This action is irreversible.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _openDeleteAccount(context, account),
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('Delete Account...', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _settingsRow(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
                ],
              ],
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: ADJUSTMENTS AUDIT LOG
  // ==========================================
  Widget _buildAdjustmentsTab(BuildContext context, Account account, String curr, bool isDark) {
    return FutureBuilder<List<AccountAdjustment>>(
      future: ref.watch(accountRepositoryProvider).getAccountAdjustments(account.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final adjustments = snapshot.data ?? [];
        if (adjustments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.balance_rounded, size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Adjustments Recorded',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The recorded balance matches the calculated ledger of transactions.\nUse adjustments to reconcile without modifying existing entries.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Adjust Balance Now'),
                    onPressed: () => _openAccountAdjustment(context, account),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Adjustment Audit Log (${adjustments.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New Adjustment'),
                  onPressed: () => _openAccountAdjustment(context, account),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...adjustments.map((adj) {
              final isInc = adj.isIncrease;
              final color = isInc ? AppColors.income : AppColors.expense;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(20),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isInc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                    color: color,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isInc ? 'Balance Increased' : 'Balance Decreased',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        DateFormat('dd MMM yyyy, hh:mm a').format(adj.createdAt),
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${isInc ? "+" : "-"}${CurrencyFormatter.format(adj.adjustmentAmount, symbol: curr)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Reason: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Expanded(
                            child: Text(
                              adj.reason,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Prior: ${CurrencyFormatter.format(adj.previousBalance, symbol: curr)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.0),
                            child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                          ),
                          Expanded(
                            child: Text(
                              'Reconciled: ${CurrencyFormatter.format(adj.newBalance, symbol: curr)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }
}
