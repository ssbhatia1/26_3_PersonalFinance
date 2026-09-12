import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/investment.dart';
import '../data/repositories/investment_repository.dart';
import 'account_provider.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

class InvestmentState {
  final List<Investment> investments;
  final bool isLoading;
  final String? error;

  const InvestmentState({
    this.investments = const [],
    this.isLoading = false,
    this.error,
  });

  InvestmentState copyWith({
    List<Investment>? investments,
    bool? isLoading,
    String? error,
  }) {
    return InvestmentState(
      investments: investments ?? this.investments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class InvestmentNotifier extends Notifier<InvestmentState> {
  InvestmentRepository get _repo => ref.read(investmentRepositoryProvider);

  @override
  InvestmentState build() {
    Future.microtask(loadInvestments);
    return const InvestmentState();
  }

  void reset() {
    state = const InvestmentState();
  }

  Future<void> loadInvestments({String? userId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final activeUserId = userId ?? ref.read(authProvider).user?.id;
      final list = await _repo.getAllInvestments(userId: activeUserId);
      state = state.copyWith(investments: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createInvestment(
    Investment investment, {
    bool deductFromAccount = false,
  }) async {
    await _repo.createInvestment(investment);
    if (deductFromAccount && investment.accountId != null && investment.investedAmount > 0) {
      final accounts = ref.read(accountProvider).accounts;
      final acc = accounts.where((a) => a.id == investment.accountId).firstOrNull;
      if (acc != null) {
        final newBal = acc.currentBalance - investment.investedAmount;
        await ref.read(accountProvider.notifier).adjustAccountBalance(
          accountId: acc.id,
          newBalance: newBal,
          reason: 'Funded investment: ${investment.name}',
          timestamp: investment.startDate,
        );
      }
    } else {
      await ref.read(accountProvider.notifier).loadAccounts();
    }
    await loadInvestments();
  }

  Future<void> updateInvestment(Investment investment) async {
    await _repo.updateInvestment(investment);
    await ref.read(accountProvider.notifier).loadAccounts();
    await loadInvestments();
  }

  Future<void> deleteInvestment(String id) async {
    await _repo.deleteInvestment(id);
    await ref.read(accountProvider.notifier).loadAccounts();
    await loadInvestments();
  }
}

final investmentProvider = NotifierProvider<InvestmentNotifier, InvestmentState>(InvestmentNotifier.new);

final investmentSummaryProvider = Provider<Map<String, dynamic>>((ref) {
  final state = ref.watch(investmentProvider);
  final list = state.investments;

  double totalInvested = 0.0;
  double totalCurrentValue = 0.0;
  double totalExpectedReturns = 0.0;
  int activeCount = 0;

  for (final inv in list) {
    if (inv.status == 'active') {
      activeCount++;
      totalInvested += inv.investedAmount;
      totalCurrentValue += inv.currentValue;
      totalExpectedReturns += inv.expectedReturns;
    }
  }

  final totalProfitLoss = totalCurrentValue - totalInvested;
  final totalProfitLossPercent = totalInvested > 0 ? (totalProfitLoss / totalInvested) * 100 : 0.0;

  return {
    'totalInvested': totalInvested,
    'totalCurrentValue': totalCurrentValue,
    'totalExpectedReturns': totalExpectedReturns,
    'totalProfitLoss': totalProfitLoss,
    'totalProfitLossPercent': totalProfitLossPercent,
    'isProfitable': totalProfitLoss >= 0,
    'activeCount': activeCount,
    'totalCount': list.length,
  };
});
