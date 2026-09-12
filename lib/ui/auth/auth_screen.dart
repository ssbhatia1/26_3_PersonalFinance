import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';

enum AuthMode { login, register, forgotPassword, resetPassword }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  AuthMode _mode = AuthMode.login;

  // Form keys
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _forgotFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  // Text controllers (clean empty initial state, zero dummy credentials)
  final _loginUsernameOrEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _regFullNameController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();

  final _forgotEmailController = TextEditingController();

  final _resetEmailController = TextEditingController();
  final _resetTokenController = TextEditingController();
  final _resetNewPasswordController = TextEditingController();

  bool _obscureLoginPassword = true;
  bool _obscureRegPassword = true;
  bool _obscureResetPassword = true;

  @override
  void dispose() {
    _loginUsernameOrEmailController.dispose();
    _loginPasswordController.dispose();
    _regFullNameController.dispose();
    _regUsernameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    _forgotEmailController.dispose();
    _resetEmailController.dispose();
    _resetTokenController.dispose();
    _resetNewPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    ref.read(authProvider.notifier).clearError();
    ref.read(authProvider.notifier).clearInfo();
    setState(() {
      _mode = mode;
    });
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(
      usernameOrEmail: _loginUsernameOrEmailController.text.trim(),
      password: _loginPasswordController.text,
    );
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).register(
      fullName: _regFullNameController.text.trim(),
      username: _regUsernameController.text.trim(),
      email: _regEmailController.text.trim(),
      password: _regPasswordController.text,
    );
  }

  Future<void> _handleForgotPassword() async {
    if (!_forgotFormKey.currentState!.validate()) return;
    final email = _forgotEmailController.text.trim();
    final ok = await ref.read(authProvider.notifier).requestPasswordReset(email);
    if (ok) {
      final code = ref.read(authProvider).lastResetCode;
      _resetEmailController.text = email;
      if (code != null) {
        _resetTokenController.text = code;
      }
      setState(() {
        _mode = AuthMode.resetPassword;
      });
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).resetPassword(
      email: _resetEmailController.text.trim(),
      token: _resetTokenController.text.trim(),
      newPassword: _resetNewPasswordController.text,
    );
    if (ok) {
      _loginUsernameOrEmailController.text = _resetEmailController.text.trim();
      _loginPasswordController.text = _resetNewPasswordController.text;
      setState(() {
        _mode = AuthMode.login;
      });
    }
  }

  Future<void> _handleRestoreBackup(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result.isEmpty) return;

      final picked = result.first;
      final bytes = await picked.readAsBytes();
      final content = utf8.decode(bytes);

      final counts = await ref.read(settingsProvider.notifier).importBackupJson(content);

      // If the backup contains a restored user, populate username
      final dynamic parsed = jsonDecode(content);
      String? restoredUsername;
      if (parsed is Map && parsed['users'] is List && (parsed['users'] as List).isNotEmpty) {
        final firstUser = (parsed['users'] as List).first;
        if (firstUser is Map && firstUser['username'] != null) {
          restoredUsername = firstUser['username'].toString();
          _loginUsernameOrEmailController.text = restoredUsername;
        }
      }

      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            'Backup restored successfully! ${counts['accounts']} accounts, ${counts['transactions']} transactions imported.${restoredUsername != null ? ' Ready to log in as $restoredUsername.' : ''}',
          ),
          backgroundColor: AppColors.income,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Failed to restore backup: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 850;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: BoxConstraints(maxWidth: isWide ? 960 : 480),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: isWide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildBrandingPanel(context, isDark)),
                        Expanded(child: _buildFormPanel(context, authState, isDark)),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      _buildHeaderCompact(context, isDark),
                      _buildFormPanel(context, authState, isDark),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingPanel(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0D9488), const Color(0xFF0284C7)]
              : [const Color(0xFF0F766E), const Color(0xFF0369A1)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLogo(
                size: 72,
                borderRadius: 18,
                showShadow: true,
                heroTag: 'app_product_logo',
              ),
              const SizedBox(height: 20),
              const Text(
                'Personal Finance\nLedger',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'High-performance offline-first accounting, advanced analytics, and zero-compromise data privacy.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Column(
            children: [
              _buildFeatureRow(Icons.lock_rounded, 'Multi-round SHA-256 salted credentials'),
              const SizedBox(height: 12),
              _buildFeatureRow(Icons.token_rounded, 'Cryptographic session tokenization'),
              const SizedBox(height: 12),
              _buildFeatureRow(Icons.insights_rounded, 'Real-time multi-dimensional analytics'),
              const SizedBox(height: 12),
              _buildFeatureRow(Icons.sync_rounded, 'Instant local module synchronization'),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '100% Encrypted & Local Database',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCompact(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          const AppLogo(
            size: 46,
            borderRadius: 12,
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Finance Ledger',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Secure Authentication Hub',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel(BuildContext context, AuthState authState, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Alerts (Errors / Success)
          if (authState.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      authState.error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (authState.infoMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.income.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.income.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.income, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      authState.infoMessage!,
                      style: const TextStyle(
                        color: AppColors.income,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Restore from Backup Option (Available on Login Screen)
          if (_mode == AuthMode.login) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.settings_backup_restore_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Have an existing backup?',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Restore offline database from .json file',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _handleRestoreBackup(context),
                    icon: const Icon(Icons.file_open_rounded, size: 14),
                    label: const Text('Restore File', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Form Body
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildCurrentForm(authState, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentForm(AuthState authState, bool isDark) {
    switch (_mode) {
      case AuthMode.login:
        return _buildLoginForm(authState);
      case AuthMode.register:
        return _buildRegisterForm(authState);
      case AuthMode.forgotPassword:
        return _buildForgotPasswordForm(authState);
      case AuthMode.resetPassword:
        return _buildResetPasswordForm(authState);
    }
  }

  Widget _buildLoginForm(AuthState authState) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign In',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter your credentials to access your financial dashboard',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _loginUsernameOrEmailController,
            decoration: const InputDecoration(
              labelText: 'Email or Username',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter email or username' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _obscureLoginPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLoginPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Please enter password' : null,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _switchMode(AuthMode.forgotPassword),
              child: const Text('Forgot Password?', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: authState.isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: authState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("Don't have an account?", style: TextStyle(fontSize: 13)),
              TextButton(
                onPressed: () => _switchMode(AuthMode.register),
                child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(AuthState authState) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create Account',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start tracking wealth with private, offline-first security',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _regFullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.badge_outlined, size: 20),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your full name' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _regUsernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.account_circle_outlined, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().length < 3) return 'Must be at least 3 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _regEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
            validator: (v) {
              if (v == null || !v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _regPasswordController,
            obscureText: _obscureRegPassword,
            decoration: InputDecoration(
              labelText: 'Password (min 6 characters)',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscureRegPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                onPressed: () => setState(() => _obscureRegPassword = !_obscureRegPassword),
              ),
            ),
            validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _regConfirmPasswordController,
            obscureText: _obscureRegPassword,
            decoration: const InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: Icon(Icons.lock_reset, size: 20),
            ),
            validator: (v) {
              if (v != _regPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: authState.isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: authState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Sign Up & Launch', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Already have an account?', style: TextStyle(fontSize: 13)),
              TextButton(
                onPressed: () => _switchMode(AuthMode.login),
                child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPasswordForm(AuthState authState) {
    return Form(
      key: _forgotFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Reset Password',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter your registered email to receive a secure 6-digit verification token.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _forgotEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Registered Email',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
            validator: (v) => (v == null || !v.contains('@')) ? 'Please enter a valid email' : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: authState.isLoading ? null : _handleForgotPassword,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: authState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Generate Reset Code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Remembered your password?', style: TextStyle(fontSize: 13)),
              TextButton(
                onPressed: () => _switchMode(AuthMode.login),
                child: const Text('Back to Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResetPasswordForm(AuthState authState) {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter Reset Code',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Verify the 6-digit code and choose a strong new password.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _resetEmailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
            readOnly: true,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _resetTokenController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '6-Digit Verification Code',
              prefixIcon: Icon(Icons.pin_outlined, size: 20),
              counterText: '',
            ),
            validator: (v) => (v == null || v.trim().length != 6) ? 'Enter 6-digit code' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _resetNewPasswordController,
            obscureText: _obscureResetPassword,
            decoration: InputDecoration(
              labelText: 'New Password (min 6 characters)',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscureResetPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                onPressed: () => setState(() => _obscureResetPassword = !_obscureResetPassword),
              ),
            ),
            validator: (v) => (v == null || v.length < 6) ? 'Must be at least 6 characters' : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: authState.isLoading ? null : _handleResetPassword,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: authState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Update Password & Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _switchMode(AuthMode.login),
            child: const Text('Cancel and Return to Sign In'),
          ),
        ],
      ),
    );
  }
}
