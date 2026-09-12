import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/loan.dart';
import '../data/models/loan_repayment.dart';
import '../data/repositories/loan_repository.dart';
import 'account_provider.dart';
import 'auth_provider.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';

class LoanState {
  final List<Loan> loans;
  final bool isLoading;
  final String? error;

  const LoanState({
    this.loans = const [],
    this.isLoading = false,
    this.error,
  });

  double get totalBorrowed => loans
      .where((l) => l.isBorrowed && l.status == 'active')
      .fold(0.0, (sum, l) => sum + l.outstandingBalance);

  double get totalLent => loans
      .where((l) => l.isLent && l.status == 'active')
      .fold(0.0, (sum, l) => sum + l.outstandingBalance);

  LoanState copyWith({
    List<Loan>? loans,
    bool? isLoading,
    String? error,
  }) {
    return LoanState(
      loans: loans ?? this.loans,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class LoanNotifier extends Notifier<LoanState> {
  LoanRepository get _repository => ref.read(loanRepositoryProvider);

  @override
  LoanState build() {
    Future.microtask(loadLoans);
    return const LoanState();
  }

  void reset() {
    state = const LoanState();
  }

  Future<void> loadLoans({String? userId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final activeUserId = userId ?? ref.read(authProvider).user?.id;
      final list = await _repository.getAllLoans(userId: activeUserId);
      state = state.copyWith(loans: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createLoan(Loan loan, {bool disburseToAccount = false}) async {
    await _repository.createLoan(loan, disburseToAccount: disburseToAccount);
    await loadLoans();
    if (disburseToAccount) {
      await ref.read(accountProvider.notifier).loadAccounts();
      await ref.read(transactionProvider.notifier).loadTransactions();
    }
  }

  Future<void> recordRepayment({
    required Loan loan,
    required double paymentAmount,
    required String paymentAccountId,
    double interestAmount = 0.0,
    String? note,
  }) async {
    await _repository.recordLoanRepayment(
      loan: loan,
      paymentAmount: paymentAmount,
      paymentAccountId: paymentAccountId,
      interestAmount: interestAmount,
      note: note,
    );
    await loadLoans();
    await ref.read(accountProvider.notifier).loadAccounts();
    await ref.read(transactionProvider.notifier).loadTransactions();
    ref.invalidate(loanRepaymentsProvider(loan.id));
  }

  Future<void> deleteLoan(String id) async {
    await _repository.deleteLoan(id);
    await loadLoans();
  }
}

final loanProvider = NotifierProvider<LoanNotifier, LoanState>(LoanNotifier.new);

/// Provider for repayments history of a specific loan
final loanRepaymentsProvider = FutureProvider.family<List<LoanRepayment>, String>((ref, loanId) async {
  final repo = ref.watch(loanRepositoryProvider);
  return repo.getLoanRepayments(loanId);
});
