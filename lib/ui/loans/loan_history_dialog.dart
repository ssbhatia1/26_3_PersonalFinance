import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/loan.dart';
import '../../providers/loan_provider.dart';
import '../../providers/settings_provider.dart';
import 'loan_repayment_dialog.dart';

class LoanHistoryDialog extends ConsumerWidget {
  final Loan loan;

  const LoanHistoryDialog({super.key, required this.loan});

  static void show(BuildContext context, Loan loan) {
    showDialog(
      context: context,
      builder: (_) => LoanHistoryDialog(loan: loan),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repaymentsAsync = ref.watch(loanRepaymentsProvider(loan.id));
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBorrowed = loan.isBorrowed;
    final color = isBorrowed ? AppColors.liability : AppColors.asset;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.history_rounded, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${loan.borrowerLenderName} • Repayment History',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isBorrowed ? 'Loan Repayments & Interest Log' : 'Receipts & Recovery Log',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // KPI Quick Summary Row
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _kpiItem(
                      label: 'Principal',
                      value: CurrencyFormatter.format(loan.principal, symbol: curr),
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    _kpiItem(
                      label: 'Outstanding',
                      value: CurrencyFormatter.format(loan.outstandingBalance, symbol: curr),
                      color: color,
                    ),
                    _kpiItem(
                      label: 'Repaid',
                      value: CurrencyFormatter.format(loan.paidAmount, symbol: curr),
                      color: AppColors.income,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Repayment Activity',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // History list
              Expanded(
                child: repaymentsAsync.when(
                  data: (repayments) {
                    if (repayments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text(
                              'No repayments recorded yet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Record an EMI or payment to start tracking loan history.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (loan.status == 'active')
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  showDialog(
                                    context: context,
                                    builder: (_) => LoanRepaymentDialog(loan: loan),
                                  );
                                },
                                icon: const Icon(Icons.payment_rounded, size: 16),
                                label: Text(isBorrowed ? 'Pay EMI / Repay' : 'Record Receipt'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: repayments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final r = repayments[idx];
                        return Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline, color: AppColors.income, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          DateFormatter.formatFullDate(r.paymentDate),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      CurrencyFormatter.format(r.paymentAmount, symbol: curr),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.income.withAlpha(25),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Principal: ${CurrencyFormatter.format(r.principalAmount, symbol: curr)}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.income),
                                      ),
                                    ),
                                    if (r.interestAmount > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withAlpha(25),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Interest: ${CurrencyFormatter.format(r.interestAmount, symbol: curr)}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.account_balance_wallet_outlined, size: 13, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Paid from: ${r.accountName ?? "Account"}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                                    ),
                                    if (r.notes != null && r.notes!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '• ${r.notes}',
                                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (loan.status == 'active')
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (_) => LoanRepaymentDialog(loan: loan),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Repayment'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiItem({required String label, required String value, required Color color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
