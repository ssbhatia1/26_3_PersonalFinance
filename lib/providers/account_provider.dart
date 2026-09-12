import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/account.dart';
import '../data/models/account_adjustment.dart';
import '../data/repositories/account_repository.dart';
import 'auth_provider.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';

class AccountState {
  final List<Account> accounts;
  final Map<String, double> netWorthSummary;
  final bool isLoading;
  final String? error;

  const AccountState({
    this.accounts = const [],
    this.netWorthSummary = const {
      'netWorth': 0.0,
      'totalAssets': 0.0,
      'totalLiabilities': 0.0,
      'totalBank': 0.0,
      'totalCash': 0.0,
      'totalInvestments': 0.0,
    },
    this.isLoading = false,
    this.error,
  });

  AccountState copyWith({
    List<Account>? accounts,
    Map<String, double>? netWorthSummary,
    bool? isLoading,
    String? error,
  }) {
    return AccountState(
      accounts: accounts ?? this.accounts,
      netWorthSummary: netWorthSummary ?? this.netWorthSummary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AccountNotifier extends Notifier<AccountState> {
  AccountRepository get _repository => ref.read(accountRepositoryProvider);

  @override
  AccountState build() {
    Future.microtask(loadAccounts);
    return const AccountState();
  }

  void reset() {
    state = const AccountState();
  }

  Future<void> loadAccounts({String? userId, String? sessionToken}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final activeUserId = userId ?? ref.read(authProvider).user?.id;
      final accounts = await _repository.getAllAccounts(
        userId: activeUserId,
        sessionToken: sessionToken,
      );
      final summary = await _repository.getNetWorthSummary(userId: activeUserId);
      if (!ref.mounted) return;
      state = state.copyWith(
        accounts: accounts,
        netWorthSummary: summary,
        isLoading: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Finds an account by its unique security token
  Future<Account?> getAccountByToken(String token) async {
    return await _repository.getAccountByToken(token);
  }

  /// Rotates the security token of an account
  Future<Account> rotateAccountToken(String accountId) async {
    final updated = await _repository.rotateAccountToken(accountId);
    await loadAccounts();
    return updated;
  }

  Future<void> addAccount(Account account) async {
    final activeUserId = ref.read(authProvider).user?.id;
    final accountToSave = (account.userId == null && activeUserId != null)
        ? account.copyWith(userId: activeUserId)
        : account;
    await _repository.createAccount(accountToSave);
    await loadAccounts(userId: activeUserId);
  }

  Future<void> updateAccount(Account account) async {
    await _repository.updateAccount(account);
    await loadAccounts();
  }

  Future<void> deleteAccount(String accountId) async {
    await _repository.deleteAccount(accountId);
    await loadAccounts();
    // Refresh transaction list and cash flow summaries
    try {
      ref.read(transactionProvider.notifier).loadTransactions();
    } catch (_) {}
  }

  Future<AccountAdjustment> adjustAccountBalance({
    required String accountId,
    required double newBalance,
    required String reason,
    DateTime? timestamp,
  }) async {
    final adjustment = await _repository.adjustAccountBalance(
      accountId: accountId,
      newBalance: newBalance,
      reason: reason,
      timestamp: timestamp,
    );
    await loadAccounts();
    try {
      ref.read(transactionProvider.notifier).loadTransactions();
    } catch (_) {}
    return adjustment;
  }

  Future<List<AccountAdjustment>> getAccountAdjustments(String accountId) async {
    return await _repository.getAccountAdjustments(accountId);
  }
}

final accountProvider = NotifierProvider<AccountNotifier, AccountState>(AccountNotifier.new);
