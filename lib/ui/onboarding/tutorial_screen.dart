import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/reminder_provider.dart';

class TutorialItem {
  final String stepBadge;
  final String title;
  final String subtitle;
  final IconData heroIcon;
  final Color accentColor;
  final Widget visualWidget;
  final List<TutorialFeature> features;

  const TutorialItem({
    required this.stepBadge,
    required this.title,
    required this.subtitle,
    required this.heroIcon,
    required this.accentColor,
    required this.visualWidget,
    required this.features,
  });
}

class TutorialFeature {
  final IconData icon;
  final String title;
  final String description;

  const TutorialFeature({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class TutorialScreen extends ConsumerStatefulWidget {
  final bool isFromSettings;

  const TutorialScreen({
    super.key,
    this.isFromSettings = false,
  });

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleFinish() async {
    if (!widget.isFromSettings) {
      final reminderState = ref.read(reminderProvider);
      if (!reminderState.hasBeenPrompted && mounted) {
        await _showFirstTimeReminderDialog();
      }
      await ref.read(onboardingProvider.notifier).completeTutorial();
    }
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showFirstTimeReminderDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    TimeOfDay selectedTime = const TimeOfDay(hour: 20, minute: 0);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final hour = selectedTime.hourOfPeriod == 0 ? 12 : selectedTime.hourOfPeriod;
            final minute = selectedTime.minute.toString().padLeft(2, '0');
            final period = selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
            final timeStr = '$hour:$minute $period';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.alarm_on_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Daily Reminder',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Building a consistent habit is the key to mastering your money. Would you like a gentle daily reminder to record your expenses and check your budget?',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 18),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Reminder Time',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref.read(reminderProvider.notifier).setupFirstTimeReminder(
                              enabled: false,
                            );
                            Navigator.of(ctx).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Maybe Later'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ref.read(reminderProvider.notifier).setupFirstTimeReminder(
                              enabled: true,
                              time: selectedTime,
                            );
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Enable',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _handleFinish();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 700;

    final slides = _buildSlides(isDark);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 760),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // Top Action Bar
                _buildTopBar(isDark),
                const SizedBox(height: 12),

                // Carousel Body
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: slides.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = slides[index];
                      return _buildSlideContent(item, isDark, isDesktop);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Bottom Navigation & Indicators
                _buildBottomControls(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Brand logo & title
        Row(
          children: [
            const AppLogo(
              size: 32,
              borderRadius: 8,
              showShadow: true,
            ),
            const SizedBox(width: 10),
            Text(
              'Personal Finance',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),

        // Skip / Close Button
        TextButton(
          onPressed: _handleFinish,
          style: TextButton.styleFrom(
            foregroundColor: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isFromSettings ? 'Close Guide' : 'Skip Intro',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.close_rounded, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlideContent(TutorialItem item, bool isDark, bool isDesktop) {
    final cardBg = isDark ? const Color(0xFF131B2A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF233249) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),

          // Step Badge Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: item.accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: item.accentColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.heroIcon, size: 14, color: item.accentColor),
                const SizedBox(width: 6),
                Text(
                  item.stepBadge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: item.accentColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Headline
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 26 : 22,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              item.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Interactive Visual Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: item.visualWidget,
          ),
          const SizedBox(height: 20),

          // 3 Distinct Feature Bullets
          Column(
            children: item.features.map((feature) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.accentColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(feature.icon, size: 16, color: item.accentColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            feature.description,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(bool isDark) {
    final isLastPage = _currentPage == 4;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          if (_currentPage > 0)
            OutlinedButton.icon(
              onPressed: _prevPage,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                foregroundColor: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                side: BorderSide(
                  color: isDark ? const Color(0xFF233249) : const Color(0xFFE2E8F0),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          else
            const SizedBox(width: 80),

          // Page Indicator Dots / Pills
          Row(
            children: List.generate(5, (index) {
              final isCurrent = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isCurrent ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primary
                      : (isDark ? const Color(0xFF233249) : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Next / Get Started Button
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLastPage
                      ? (widget.isFromSettings ? 'Done' : 'Get Started')
                      : 'Next',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Icon(
                  isLastPage ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<TutorialItem> _buildSlides(bool isDark) {
    final subCardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return [
      // -------------------------------------------------------------
      // SLIDE 1: Accounts & Multi-Currency Hub
      // -------------------------------------------------------------
      TutorialItem(
        stepBadge: '1 of 5 • Account Hub',
        title: 'Unified Multi-Account Ledger',
        subtitle: 'Consolidate bank accounts, UPI, cash, credit cards, and investments into a single unified ledger.',
        heroIcon: Icons.account_balance_wallet_rounded,
        accentColor: AppColors.primary,
        visualWidget: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Net Worth', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    SizedBox(height: 2),
                    Text('₹ 4,82,450.00', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.incomeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward, size: 12, color: AppColors.income),
                      SizedBox(width: 4),
                      Text('+8.4% this mo', style: TextStyle(fontSize: 11, color: AppColors.income, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMockAccountBadge('HDFC Bank', '₹ 1,45,200', Icons.account_balance, AppColors.asset, subCardBg),
                _buildMockAccountBadge('UPI Wallet', '₹ 8,350', Icons.phone_android, AppColors.info, subCardBg),
                _buildMockAccountBadge('Credit Card', '-₹ 14,800', Icons.credit_card, AppColors.expense, subCardBg),
                _buildMockAccountBadge('Cash Stash', '₹ 12,000', Icons.payments, AppColors.warning, subCardBg),
                _buildMockAccountBadge('Mutual Fund SIP', '₹ 3,31,700', Icons.trending_up, AppColors.investment, subCardBg),
              ],
            ),
          ],
        ),
        features: const [
          TutorialFeature(
            icon: Icons.account_tree_outlined,
            title: '14+ Account Instrument Types',
            description: 'Track Cash, Savings, Current, UPI, Credit Cards, FDs, RDs, Investments & Loans with individual balances.',
          ),
          TutorialFeature(
            icon: Icons.currency_exchange_rounded,
            title: 'Multi-Currency Precision',
            description: 'Configure your primary currency across ₹ INR, \$ USD, € EUR, £ GBP, and ¥ JPY anytime.',
          ),
          TutorialFeature(
            icon: Icons.flash_on_rounded,
            title: 'Instant Local Calculations',
            description: 'Every balance update and calculation resolves locally with instantaneous SQLite response.',
          ),
        ],
      ),

      // -------------------------------------------------------------
      // SLIDE 2: Smart Transactions & Double-Entry Integrity
      // -------------------------------------------------------------
      TutorialItem(
        stepBadge: '2 of 5 • Transactions',
        title: 'Smart Income, Expense & Transfers',
        subtitle: 'Log financial movements with strict accounting integrity. Transfers never distort your income or expense reports.',
        heroIcon: Icons.swap_horiz_rounded,
        accentColor: AppColors.transfer,
        visualWidget: Column(
          children: [
            _buildMockTxRow(
              icon: Icons.arrow_downward_rounded,
              color: AppColors.income,
              title: 'Monthly Salary',
              subtitle: 'Bank Account • Income',
              amount: '+₹ 75,000',
              subCardBg: subCardBg,
            ),
            const SizedBox(height: 8),
            _buildMockTxRow(
              icon: Icons.swap_horiz_rounded,
              color: AppColors.transfer,
              title: 'Transfer to UPI Wallet',
              subtitle: 'HDFC → Google Pay • Non-distorting',
              amount: '₹ 5,000',
              subCardBg: subCardBg,
            ),
            const SizedBox(height: 8),
            _buildMockTxRow(
              icon: Icons.arrow_upward_rounded,
              color: AppColors.expense,
              title: 'Grocery Supermarket',
              subtitle: 'UPI • Food & Dining',
              amount: '-₹ 2,450',
              subCardBg: subCardBg,
            ),
          ],
        ),
        features: const [
          TutorialFeature(
            icon: Icons.balance_rounded,
            title: 'Strict Accounting Business Logic',
            description: 'Transfers decrease source and increase destination accounts without falsifying monthly cash flow totals.',
          ),
          TutorialFeature(
            icon: Icons.label_important_outline_rounded,
            title: 'Rich Metadata & Split Tags',
            description: 'Record payees, reference IDs, payment methods, transaction notes, and attach photo receipts.',
          ),
          TutorialFeature(
            icon: Icons.update_rounded,
            title: 'Scheduled & Recurring Rules',
            description: 'Automate recurring salaries, subscriptions, rent, and investments with reliable schedule tracking.',
          ),
        ],
      ),

      // -------------------------------------------------------------
      // SLIDE 3: Intelligent Budgets & Spending Control
      // -------------------------------------------------------------
      TutorialItem(
        stepBadge: '3 of 5 • Budgeting',
        title: 'Proactive Budgets & Spending Limits',
        subtitle: 'Set monthly limits across specific categories to safeguard your savings and avoid surprise shortfalls.',
        heroIcon: Icons.pie_chart_rounded,
        accentColor: AppColors.liability,
        visualWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMockBudgetBar('Food & Dining', 0.65, '₹ 9,750 / ₹ 15,000', AppColors.primary, 'Healthy'),
            const SizedBox(height: 12),
            _buildMockBudgetBar('Shopping & Gadgets', 0.88, '₹ 8,800 / ₹ 10,000', AppColors.warning, 'Warning 88%'),
            const SizedBox(height: 12),
            _buildMockBudgetBar('Weekend Entertainment', 0.98, '₹ 4,900 / ₹ 5,000', AppColors.expense, 'Critical 98%'),
          ],
        ),
        features: const [
          TutorialFeature(
            icon: Icons.check_box_outlined,
            title: 'Category & Global Limits',
            description: 'Allocate monthly spending allowances per category with real-time remaining balance calculations.',
          ),
          TutorialFeature(
            icon: Icons.notifications_active_outlined,
            title: 'Proactive Utilization Meters',
            description: 'Color-coded visual progress indicators turn from Emerald to Amber to Coral Rose as you approach limits.',
          ),
          TutorialFeature(
            icon: Icons.savings_outlined,
            title: 'Zero-Based Envelope Accounting',
            description: 'Ensure every rupee earned is intentionally designated for expenses, debt repayment, or savings goals.',
          ),
        ],
      ),

      // -------------------------------------------------------------
      // SLIDE 4: Debt, Loans & Liability Management
      // -------------------------------------------------------------
      TutorialItem(
        stepBadge: '4 of 5 • Loans & Debts',
        title: 'Track Loans, EMIs & Money Lent',
        subtitle: 'Complete clarity on home/auto loans, credit liabilities, and money lent to or borrowed from others.',
        heroIcon: Icons.trending_down_rounded,
        accentColor: AppColors.expense,
        visualWidget: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: subCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.expense.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Home Loan Outstanding', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      SizedBox(height: 2),
                      Text('₹ 18,40,000', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.expense)),
                      Text('Next EMI: ₹ 24,500 due 5th', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Money Lent Out', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      SizedBox(height: 2),
                      Text('₹ 15,000', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.income)),
                      Text('Rahul • Due in 12 days', style: TextStyle(fontSize: 10, color: AppColors.income)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        features: const [
          TutorialFeature(
            icon: Icons.calculate_outlined,
            title: 'Principal vs Interest Separation',
            description: 'Repayments reduce liability while interest is logged as true expense, preserving balance sheet accuracy.',
          ),
          TutorialFeature(
            icon: Icons.handshake_outlined,
            title: 'Personal Lending & Borrowing',
            description: 'Track receivables from friends/family and liabilities with borrower names and target settlement dates.',
          ),
          TutorialFeature(
            icon: Icons.history_rounded,
            title: 'Full Payment History & Amortization',
            description: 'Keep an auditable ledger of every EMI paid, outstanding balances, and remaining tenures.',
          ),
        ],
      ),

      // -------------------------------------------------------------
      // SLIDE 5: Deep Visual Analytics & 100% Privacy
      // -------------------------------------------------------------
      TutorialItem(
        stepBadge: '5 of 5 • Privacy & Insights',
        title: 'Deep Analytics, 100% Private',
        subtitle: 'Interactive visual charts, exportable CSV spreadsheets, and zero external tracking or cloud reliance.',
        heroIcon: Icons.shield_rounded,
        accentColor: AppColors.income,
        visualWidget: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSecurityPill(Icons.storage_rounded, 'Local SQLite', AppColors.primary, subCardBg),
                _buildSecurityPill(Icons.lock_rounded, 'SHA-256 Auth', AppColors.asset, subCardBg),
                _buildSecurityPill(Icons.cloud_off_rounded, '0% Cloud Leak', AppColors.income, subCardBg),
                _buildSecurityPill(Icons.file_download_rounded, 'CSV / JSON', AppColors.transfer, subCardBg),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.income.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_rounded, size: 16, color: AppColors.income),
                  SizedBox(width: 8),
                  Text(
                    'Your financial records remain 100% on this device',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.income),
                  ),
                ],
              ),
            ),
          ],
        ),
        features: const [
          TutorialFeature(
            icon: Icons.bar_chart_rounded,
            title: 'Interactive fl_chart Analytics',
            description: 'Examine month-over-month cash flows, spending heatmaps, net worth curves, and category breakdowns.',
          ),
          TutorialFeature(
            icon: Icons.backup_table_rounded,
            title: 'One-Click CSV & JSON Backups',
            description: 'Export all your transactions to standard CSV or generate complete encrypted JSON backups anytime.',
          ),
          TutorialFeature(
            icon: Icons.vpn_key_rounded,
            title: 'Zero Ads, Zero Data Harvesting',
            description: 'No third-party trackers, no mandatory cloud sync, no financial surveillance. Complete peace of mind.',
          ),
        ],
      ),
    ];
  }

  Widget _buildMockAccountBadge(String name, String balance, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Text(
            balance,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMockTxRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String amount,
    required Color subCardBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: subCardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockBudgetBar(String title, double progress, String amountStr, Color color, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Row(
              children: [
                Text(amountStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 6),
                Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityPill(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
