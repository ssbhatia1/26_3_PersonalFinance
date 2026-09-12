import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/loan.dart';
import '../../providers/loan_provider.dart';
import '../../providers/settings_provider.dart';
import 'loan_form_dialog.dart';
import 'loan_history_dialog.dart';
import 'loan_repayment_dialog.dart';
import '../recurring/recurring_form_dialog.dart';

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  void _openAdd(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const LoanFormDialog(),
    );
  }

  void _openRepayment(BuildContext context, Loan loan) {
    showDialog(
      context: context,
      builder: (ctx) => LoanRepaymentDialog(loan: loan),
    );
  }

  void _openEdit(BuildContext context, Loan loan) {
    showDialog(
      context: context,
      builder: (ctx) => LoanFormDialog(loanToEdit: loan),
    );
  }

  void _openHistory(BuildContext context, Loan loan) {
    LoanHistoryDialog.show(context, loan);
  }

  void _setupRecurringEmi(BuildContext context, Loan loan) {
    showDialog(
      context: context,
      builder: (ctx) => RecurringFormDialog(
        prefillTitle: 'EMI: ${loan.borrowerLenderName}',
        prefillAmount: loan.emiAmount > 0 ? loan.emiAmount : null,
        prefillType: loan.isBorrowed ? 'expense' : 'income',
        prefillAccountId: loan.accountId,
        prefillCategoryId: 'cat_exp_emi',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanState = ref.watch(loanProvider);
    final settings = ref.watch(settingsProvider);
    final curr = settings.currency;

    final totalBorrowed = loanState.totalBorrowed;
    final totalLent = loanState.totalLent;
    final loans = loanState.loans;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans, EMIs & Debts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Loan',
            onPressed: () => _openAdd(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Debt summary cards
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  title: 'Borrowed (Payables)',
                  amount: totalBorrowed,
                  symbol: curr,
                  color: AppColors.liability,
                  icon: Icons.call_received_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  title: 'Lent (Receivables)',
                  amount: totalLent,
                  symbol: curr,
                  color: AppColors.primary,
                  icon: Icons.call_made_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Obligations & Records',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () => _openAdd(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Loan'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (loans.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.handshake_outlined, size: 56, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No loans or debts recorded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Keep track of personal loans, home loans, vehicle EMIs, or money lent to friends.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _openAdd(context),
                      child: const Text('Record Loan'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...loans.map((loan) => _buildLoanCard(context, ref, loan, curr)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required double amount,
    required String symbol,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              CurrencyFormatter.format(amount, symbol: symbol),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanCard(BuildContext context, WidgetRef ref, Loan loan, String curr) {
    final isBorrowed = loan.isBorrowed;
    final color = isBorrowed ? AppColors.liability : AppColors.asset;
    final pct = loan.progressPercentage;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color.withAlpha(25),
                      child: Icon(
                        isBorrowed ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.borrowerLenderName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${isBorrowed ? "Borrowed from" : "Lent to"} • ${DateFormatter.formatShortDate(loan.startDate)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: loan.status == 'closed' ? Colors.grey.withAlpha(50) : color.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    loan.status.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: AppColors.darkBorder,
                color: color,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Outstanding: ${CurrencyFormatter.format(loan.outstandingBalance, symbol: curr)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  'Principal: ${CurrencyFormatter.format(loan.principal, symbol: curr)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (loan.emiAmount > 0)
                  Text(
                    'EMI: ${CurrencyFormatter.format(loan.emiAmount, symbol: curr)}/month  •  ',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                Text(
                  '${loan.interestRate}% p.a.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (loan.isFlexibleInterest) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.primary.withAlpha(50)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, size: 10, color: AppColors.primary),
                        SizedBox(width: 3),
                        Text(
                          'Flexible Rate',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openHistory(context, loan),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('History'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (loan.emiAmount > 0) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.repeat_rounded, size: 18, color: AppColors.primary),
                    tooltip: 'Schedule Recurring EMI',
                    onPressed: () => _setupRecurringEmi(context, loan),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                  tooltip: 'Edit Loan & Rate',
                  onPressed: () => _openEdit(context, loan),
                ),
                const SizedBox(width: 4),
                if (loan.status == 'active')
                  ElevatedButton.icon(
                    onPressed: () => _openRepayment(context, loan),
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: Text(isBorrowed ? 'Pay EMI / Repay' : 'Record Receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  tooltip: 'Delete Record',
                  onPressed: () {
                    ref.read(loanProvider.notifier).deleteLoan(loan.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
