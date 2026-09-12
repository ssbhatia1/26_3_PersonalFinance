import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/transaction.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import 'attachment_preview_dialog.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _editTransaction(BuildContext context, TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionFormScreen(transactionToEdit: tx),
    );
  }

  Future<void> _previewTransactionAttachments(BuildContext context, TransactionModel tx) async {
    final repo = ref.read(attachmentRepositoryProvider);
    final atts = await repo.getAttachmentsByTransaction(tx.id);
    if (!mounted) return;
    if (atts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attachments found for this transaction.')),
      );
      return;
    }
    AttachmentPreviewDialog.show(
      context: context,
      attachments: atts,
      allowDelete: false,
    );
  }

  void _confirmDelete(BuildContext context, String txId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('This will delete the transaction and mathematically reverse its balance effect on the linked accounts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(transactionProvider.notifier).deleteTransaction(txId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final state = ref.read(transactionProvider);
    final initialRange = DateTimeRange(
      start: state.filter.startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      end: state.filter.endDate ?? DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      ref.read(transactionProvider.notifier).setDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(transactionProvider);
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;

    final filter = txState.filter;
    final transactions = txState.transactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger & Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Filter by Date Range',
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_off_rounded),
            tooltip: 'Reset Filters',
            onPressed: () => ref.read(transactionProvider.notifier).resetFilters(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search description, payee, reference...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(transactionProvider.notifier).setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    ref.read(transactionProvider.notifier).setSearchQuery(val);
                  },
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('all', 'All Types', filter.type),
                      const SizedBox(width: 8),
                      _filterChip('expense', 'Expenses', filter.type, color: AppColors.expense),
                      const SizedBox(width: 8),
                      _filterChip('income', 'Income', filter.type, color: AppColors.income),
                      const SizedBox(width: 8),
                      _filterChip('transfer', 'Transfers', filter.type, color: AppColors.transfer),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Transaction List
          Expanded(
            child: txState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text(
                              'No transactions found matching criteria',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                ref.read(transactionProvider.notifier).resetFilters();
                              },
                              child: const Text('Reset All Filters'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final tx = transactions[idx];
                          final isIncome = tx.isIncome;
                          final isTransfer = tx.isTransfer;

                          Color color = isIncome
                              ? AppColors.income
                              : (isTransfer ? AppColors.transfer : AppColors.expense);

                          return ListTile(
                            onTap: () => _editTransaction(context, tx),
                            onLongPress: () => _confirmDelete(context, tx.id),
                            leading: CircleAvatar(
                              backgroundColor: color.withAlpha(25),
                              child: Icon(
                                isIncome
                                    ? Icons.arrow_downward_rounded
                                    : (isTransfer ? Icons.swap_horiz_rounded : Icons.arrow_upward_rounded),
                                color: color,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          tx.description?.isNotEmpty == true
                                              ? tx.description!
                                              : (tx.categoryName ?? 'Transaction'),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (tx.categoryId == 'cat_exp_emi' ||
                                          (tx.description != null && tx.description!.toLowerCase().contains('loan'))) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.liability.withAlpha(30),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'LOAN',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.liability),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${isIncome ? '+' : (isTransfer ? '' : '-')}${CurrencyFormatter.format(tx.amount, symbol: curr)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                children: [
                                  Icon(
                                    isTransfer
                                        ? Icons.swap_horiz_rounded
                                        : (isIncome ? Icons.account_balance_rounded : Icons.credit_card_rounded),
                                    size: 13,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      isTransfer
                                          ? '${tx.sourceAccountName ?? "From"} → ${tx.destinationAccountName ?? "To"}'
                                          : '${isIncome ? "Received in" : "Paid from"}: ${tx.sourceAccountName ?? "Account"} • ${tx.categoryName ?? "General"}',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (tx.attachmentCount > 0) ...[
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () => _previewTransactionAttachments(context, tx),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withAlpha(25),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.attach_file_rounded, size: 12, color: AppColors.primary),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${tx.attachmentCount}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormatter.formatDisplay(tx.date),
                                    style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (tx.attachmentCount > 0)
                                  IconButton(
                                    icon: const Icon(Icons.attach_file_rounded, size: 18, color: AppColors.primary),
                                    tooltip: 'Preview ${tx.attachmentCount} Attachment(s)',
                                    onPressed: () => _previewTransactionAttachments(context, tx),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                  onPressed: () => _confirmDelete(context, tx.id),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String typeKey, String label, String currentType, {Color? color}) {
    final isSelected = currentType == typeKey;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => ref.read(transactionProvider.notifier).setFilterType(typeKey),
      selectedColor: (color ?? AppColors.primary).withAlpha(40),
      checkmarkColor: color ?? AppColors.primary,
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? (color ?? AppColors.primary) : null,
      ),
    );
  }
}
