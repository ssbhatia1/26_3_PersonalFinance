import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import 'app_logo.dart';
import '../../ui/dashboard/dashboard_screen.dart';
import '../../ui/accounts/accounts_screen.dart';
import '../../ui/transactions/transactions_screen.dart';
import '../../ui/transactions/transaction_form_screen.dart';
import '../../ui/budgets/budgets_screen.dart';
import '../../ui/goals/goals_screen.dart';
import '../../ui/investments/investments_screen.dart';
import '../../ui/loans/loans_screen.dart';
import '../../ui/recurring/recurring_screen.dart';
import '../../ui/reports/reports_screen.dart';
import '../../ui/settings/settings_screen.dart';
import '../../providers/auth_provider.dart';

class ResponsiveScaffold extends ConsumerStatefulWidget {
  const ResponsiveScaffold({super.key});

  @override
  ConsumerState<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends ConsumerState<ResponsiveScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    AccountsScreen(),
    TransactionsScreen(),
    BudgetsScreen(),
    InvestmentsScreen(),
    RecurringScreen(),
    LoansScreen(),
    GoalsScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  final List<NavigationDestination> _navDestinations = const [
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Accounts'),
    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transactions'),
    NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Budgets'),
    NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'More'),
  ];

  void _openAddTransactionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TransactionFormScreen(),
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    // Only display global "New Entry" on Transactions tab (2).
    // Dashboard (0) does not show the New Entry button per user preference.
    // Budgets (3) and Investments (4) manage their own specialized FABs ('New Budget', 'Add Investment').
    // Other tabs have dedicated inline/appbar actions.
    if (_selectedIndex == 2) {
      return FloatingActionButton.extended(
        onPressed: () => _openAddTransactionModal(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text('New Entry', style: TextStyle(fontWeight: FontWeight.w700)),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      floatingActionButton: _buildFloatingActionButton(context),
      body: isDesktop ? _buildDesktopLayout(isDark) : _screens[_selectedIndex],
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex > 4 ? 4 : _selectedIndex,
              onDestinationSelected: (index) {
                if (index == 4) {
                  _showMoreMenu(context);
                } else {
                  setState(() => _selectedIndex = index);
                }
              },
              destinations: _navDestinations,
            ),
    );
  }

  Widget _buildDesktopLayout(bool isDark) {
    final navRailDestinations = const [
      NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
      NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: Text('Accounts')),
      NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Transactions')),
      NavigationRailDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: Text('Budgets')),
      NavigationRailDestination(icon: Icon(Icons.trending_up_rounded), selectedIcon: Icon(Icons.trending_up), label: Text('Investments')),
      NavigationRailDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: Text('Recurring')),
      NavigationRailDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: Text('Loans & Debt')),
      NavigationRailDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: Text('Goals')),
      NavigationRailDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: Text('Reports')),
      NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
    ];

    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Row(
      children: [
        LayoutBuilder(
          builder: (context, constraint) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraint.maxHeight),
                child: IntrinsicHeight(
                  child: NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: AppLogo(
                        size: 42,
                        borderRadius: 12,
                        showShadow: true,
                      ),
                    ),
                    trailing: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: '${user?.fullName ?? user?.username ?? "User"} (${user?.email ?? ""})',
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary.withOpacity(0.2),
                              child: Text(
                                (user?.fullName.isNotEmpty == true
                                        ? user!.fullName[0]
                                        : (user?.username.isNotEmpty == true ? user!.username[0] : 'U'))
                                    .toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            tooltip: 'Log Out',
                            icon: const Icon(Icons.logout_rounded, size: 20),
                            onPressed: () => _confirmLogout(context),
                          ),
                        ],
                      ),
                    ),
                    destinations: navRailDestinations,
                  ),
                ),
              ),
            );
          },
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: _screens[_selectedIndex],
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            AppLogo(
              size: 28,
              borderRadius: 7,
              showShadow: true,
            ),
            SizedBox(width: 10),
            Text('Sign Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out? Your financial records remain encrypted and safely stored in your local SQLite vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    final user = ref.read(authProvider).user;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    AppLogo(size: 38, borderRadius: 10),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Finance',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Manage Better. Save Smarter.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (user != null)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: Text(
                      (user.fullName.isNotEmpty ? user.fullName[0] : user.username[0]).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  title: Text(user.fullName.isNotEmpty ? user.fullName : user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(user.email, style: const TextStyle(fontSize: 12)),
                ),
              if (user != null) const Divider(),
              ListTile(
                leading: const Icon(Icons.trending_up_rounded, color: AppColors.investment),
                title: const Text('Investments & Portfolios'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedIndex = 4);
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule, color: AppColors.primary),
                title: const Text('Recurring Transactions'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedIndex = 5);
                },
              ),
              ListTile(
                leading: const Icon(Icons.handshake, color: AppColors.liability),
                title: const Text('Loans & Debts'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedIndex = 6);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag, color: AppColors.goal),
                title: const Text('Financial Goals'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedIndex = 7);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insights, color: AppColors.asset),
                title: const Text('Reports & Analytics'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedIndex = 8);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings & Backup'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedIndex = 9);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                title: const Text('Log Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmLogout(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
