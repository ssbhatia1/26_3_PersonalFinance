import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/transaction.dart';

class TransactionRecordsTable extends StatefulWidget {
  final List<TransactionModel> transactions;
  final String currency;
  final int initialRowsPerPage;

  const TransactionRecordsTable({
    super.key,
    required this.transactions,
    required this.currency,
    this.initialRowsPerPage = 10,
  });

  @override
  State<TransactionRecordsTable> createState() => _TransactionRecordsTableState();
}

class _TransactionRecordsTableState extends State<TransactionRecordsTable> {
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'income', 'expense', 'transfer'
  late int _rowsPerPage;
  int _currentPage = 0;

  static const List<int> _pageSizeOptions = [5, 10, 20, 50, 100];

  @override
  void initState() {
    super.initState();
    _rowsPerPage = _pageSizeOptions.contains(widget.initialRowsPerPage)
        ? widget.initialRowsPerPage
        : 10;
  }

  void _onRowsPerPageChanged(int? newValue) {
    if (newValue != null && newValue != _rowsPerPage) {
      setState(() {
        _rowsPerPage = newValue;
        _currentPage = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var filtered = widget.transactions.where((t) {
      if (_filterType == 'income' && !t.isIncome) return false;
      if (_filterType == 'expense' && !t.isExpense) return false;
      if (_filterType == 'transfer' && !t.isTransfer) return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final desc = (t.description ?? '').toLowerCase();
        final cat = (t.categoryName ?? '').toLowerCase();
        final acc = (t.sourceAccountName ?? '').toLowerCase();
        final payee = (t.payeePayer ?? '').toLowerCase();
        if (!desc.contains(query) &&
            !cat.contains(query) &&
            !acc.contains(query) &&
            !payee.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    final totalPages = filtered.isEmpty ? 1 : (filtered.length / _rowsPerPage).ceil();
    final effectivePage = _currentPage.clamp(0, totalPages - 1);
    final startIndex = effectivePage * _rowsPerPage;
    final pageItems = filtered.skip(startIndex).take(_rowsPerPage).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Filters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transaction Record Ledger (Detailed Table)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Audit-ready record level ledger with real-time filters',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Search Input
              SizedBox(
                width: 200,
                child: TextField(
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _currentPage = 0;
                  }),
                  decoration: InputDecoration(
                    hintText: 'Search ledger…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter Chips & Entries per page selector
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final filterRow = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All Records', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Inflow (Income)', 'income'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Outflow (Expenses)', 'expense'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Transfers', 'transfer'),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    filterRow,
                    const SizedBox(height: 10),
                    _buildRowsPerPageSelector(isDark, compact: true),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: filterRow),
                  const SizedBox(width: 12),
                  _buildRowsPerPageSelector(isDark, compact: true),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Responsive Data Table fitting horizontally
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('No transactions match the selected filter.'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final colSpacing = ((availableWidth - 500) / 4).clamp(16.0, 64.0);

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: availableWidth > 560
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: availableWidth.clamp(540.0, double.infinity),
                    ),
                    child: DataTable(
                      columnSpacing: colSpacing,
                      horizontalMargin: 12,
                      headingRowHeight: 42,
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 52,
                      headingRowColor: WidgetStateProperty.all(
                        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      ),
                      columns: const [
                        DataColumn(label: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('DESCRIPTION / PAYEE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('AMOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), numeric: true),
                      ],
                      rows: pageItems.map((tx) {
                        final isIncome = tx.isIncome;
                        final isTransfer = tx.isTransfer;
                        final color = isIncome
                            ? AppColors.income
                            : (isTransfer ? AppColors.transfer : AppColors.expense);

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                DateFormatter.formatDisplay(tx.date),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    tx.description?.isNotEmpty == true ? tx.description! : 'Unlabeled',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    isTransfer
                                        ? '${tx.sourceAccountName ?? "From"} → ${tx.destinationAccountName ?? "To"}'
                                        : '${isIncome ? "Received in" : "Paid from"}: ${tx.sourceAccountName ?? "Account"}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tx.categoryName ?? 'General',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tx.isReconciled
                                      ? AppColors.income.withOpacity(0.12)
                                      : Colors.grey.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tx.isReconciled ? 'Cleared' : 'Posted',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: tx.isReconciled ? AppColors.income : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${isIncome ? "+" : (isTransfer ? "" : "-")}${CurrencyFormatter.format(tx.amount, symbol: widget.currency)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),

          // Pagination Controls
          if (filtered.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 10,
              children: [
                _buildRowsPerPageSelector(isDark),
                Text(
                  'Showing ${startIndex + 1} to ${(startIndex + pageItems.length)} of ${filtered.length} entries',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page_rounded, size: 20),
                      tooltip: 'First Page',
                      onPressed: effectivePage > 0
                          ? () => setState(() => _currentPage = 0)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      tooltip: 'Previous Page',
                      onPressed: effectivePage > 0
                          ? () => setState(() => _currentPage = effectivePage - 1)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        'Page ${effectivePage + 1} of $totalPages',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      tooltip: 'Next Page',
                      onPressed: (effectivePage + 1) < totalPages
                          ? () => setState(() => _currentPage = effectivePage + 1)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page_rounded, size: 20),
                      tooltip: 'Last Page',
                      onPressed: (effectivePage + 1) < totalPages
                          ? () => setState(() => _currentPage = totalPages - 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRowsPerPageSelector(bool isDark, {bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          compact ? 'Show:' : 'Show',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _rowsPerPage,
              isDense: true,
              icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
              elevation: 4,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              onChanged: _onRowsPerPageChanged,
              items: _pageSizeOptions.map<DropdownMenuItem<int>>((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('$value'),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          compact ? 'entries' : 'entries per page',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isSelected = _filterType == type;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = type;
          _currentPage = 0;
        });
      },
    );
  }
}
