import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user.dart';
import '../data/repositories/auth_repository.dart';
import 'account_provider.dart';
import 'budget_provider.dart';
import 'database_provider.dart';
import 'goal_provider.dart';
import 'investment_provider.dart';
import 'loan_provider.dart';
import 'recurring_provider.dart';
import 'transaction_provider.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final bool isInitializing;
  final String? error;
  final String? infoMessage;
  final String? lastResetCode;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isInitializing = false,
    this.error,
    this.infoMessage,
    this.lastResetCode,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool clearUser = false,
    bool? isLoading,
    bool? isInitializing,
    String? error,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
    String? lastResetCode,
    bool clearResetCode = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      error: clearError ? null : (error ?? this.error),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      lastResetCode: clearResetCode ? null : (lastResetCode ?? this.lastResetCode),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    Future.microtask(initAuth);
    return const AuthState(isInitializing: true);
  }

  Future<void> initAuth() async {
    try {
      final user = await _repository.restoreSession();
      if (!ref.mounted) return;
      state = state.copyWith(
        user: user,
        clearUser: user == null,
        isInitializing: false,
      );
      if (user != null) {
        _syncUserFinancialData(user);
      }
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        clearUser: true,
        isInitializing: false,
      );
      _resetFinancialData();
    }
  }

  Future<bool> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      final user = await _repository.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );
      state = state.copyWith(
        user: user,
        isLoading: false,
      );
      _syncUserFinancialData(user);
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        error: msg,
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      final user = await _repository.register(
        email: email,
        username: username,
        password: password,
        fullName: fullName,
      );
      state = state.copyWith(
        user: user,
        isLoading: false,
        infoMessage: 'Welcome to your financial hub, ${user.fullName}!',
      );
      _syncUserFinancialData(user);
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        error: msg,
      );
      return false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      final code = await _repository.requestPasswordReset(email);
      state = state.copyWith(
        isLoading: false,
        lastResetCode: code,
        infoMessage: 'Verification code generated. Code: $code',
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        error: msg,
      );
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      await _repository.resetPassword(
        email: email,
        token: token,
        newPassword: newPassword,
      );
      state = state.copyWith(
        isLoading: false,
        clearResetCode: true,
        infoMessage: 'Password successfully reset! Please login with your new credentials.',
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        error: msg,
      );
      return false;
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    required String email,
    required String username,
  }) async {
    final user = state.user;
    if (user == null) return false;

    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      final updated = await _repository.updateProfile(
        userId: user.id,
        fullName: fullName,
        email: email,
        username: username,
      );
      state = state.copyWith(
        user: updated,
        isLoading: false,
        infoMessage: 'Profile updated successfully.',
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        error: msg,
      );
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = state.user;
    if (user == null) return false;

    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      final updated = await _repository.changePassword(
        userId: user.id,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(
        user: updated,
        isLoading: false,
        infoMessage: 'Password changed successfully.',
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        error: msg,
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.logout();
    } finally {
      state = const AuthState(isInitializing: false);
      _resetFinancialData();
    }
  }

  void _syncUserFinancialData(User? user) {
    if (user == null) {
      _resetFinancialData();
      return;
    }
    try {
      ref.read(accountProvider.notifier).loadAccounts(userId: user.id);
    } catch (_) {}
    try {
      ref.read(transactionProvider.notifier).loadTransactions(userId: user.id);
    } catch (_) {}
    try {
      ref.read(recurringProvider.notifier).loadRecurring(userId: user.id);
    } catch (_) {}
    try {
      ref.read(budgetProvider.notifier).loadBudgets();
    } catch (_) {}
    try {
      ref.read(loanProvider.notifier).loadLoans(userId: user.id);
    } catch (_) {}
    try {
      ref.read(goalProvider.notifier).loadGoals(userId: user.id);
    } catch (_) {}
    try {
      ref.read(investmentProvider.notifier).loadInvestments(userId: user.id);
    } catch (_) {}
  }

  void _resetFinancialData() {
    try {
      ref.read(accountProvider.notifier).reset();
    } catch (_) {}
    try {
      ref.read(transactionProvider.notifier).reset();
    } catch (_) {}
    try {
      ref.read(recurringProvider.notifier).reset();
    } catch (_) {}
    try {
      ref.read(budgetProvider.notifier).reset();
    } catch (_) {}
    try {
      ref.read(loanProvider.notifier).reset();
    } catch (_) {}
    try {
      ref.read(goalProvider.notifier).reset();
    } catch (_) {}
    try {
      ref.read(investmentProvider.notifier).reset();
    } catch (_) {}
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearInfo() {
    state = state.copyWith(clearInfo: true);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
