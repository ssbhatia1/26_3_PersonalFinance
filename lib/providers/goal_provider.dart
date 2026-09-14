import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/financial_goal.dart';
import '../data/repositories/goal_repository.dart';
import 'account_provider.dart';
import 'auth_provider.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';

class GoalNotifier extends Notifier<AsyncValue<List<FinancialGoal>>> {
  GoalRepository get _repo => ref.read(goalRepositoryProvider);

  @override
  AsyncValue<List<FinancialGoal>> build() {
    Future.microtask(loadGoals);
    return const AsyncValue.loading();
  }

  void reset() {
    state = const AsyncValue.data([]);
  }

  Future<void> loadGoals({String? userId}) async {
    try {
      state = const AsyncValue.loading();
      final activeUserId = userId ?? ref.read(authProvider).user?.id;
      final list = await _repo.getAllGoals(userId: activeUserId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createGoal(FinancialGoal goal) async {
    await _repo.createGoal(goal);
    await loadGoals();
  }

  Future<void> updateGoal(FinancialGoal goal) async {
    await _repo.updateGoal(goal);
    await loadGoals();
  }

  Future<void> contribute(
    String goalId,
    double amount, {
    String? fundingAccountId,
    String? goalAccountId,
  }) async {
    await _repo.contributeToGoal(
      goalId,
      amount,
      fundingAccountId: fundingAccountId,
      goalAccountId: goalAccountId,
    );
    await loadGoals();
    if (fundingAccountId != null && fundingAccountId.isNotEmpty) {
      await ref.read(accountProvider.notifier).loadAccounts();
      await ref.read(transactionProvider.notifier).loadTransactions();
    }
  }

  Future<void> withdraw(
    String goalId,
    double amount, {
    String? receivingAccountId,
  }) async {
    await _repo.withdrawFromGoal(
      goalId,
      amount,
      receivingAccountId: receivingAccountId,
    );
    await loadGoals();
    if (receivingAccountId != null && receivingAccountId.isNotEmpty) {
      await ref.read(accountProvider.notifier).loadAccounts();
      await ref.read(transactionProvider.notifier).loadTransactions();
    }
  }

  Future<void> deleteGoal(String id) async {
    await _repo.deleteGoal(id);
    await loadGoals();
  }
}

final goalProvider = NotifierProvider<GoalNotifier, AsyncValue<List<FinancialGoal>>>(GoalNotifier.new);
