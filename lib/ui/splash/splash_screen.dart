import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/responsive_scaffold.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/settings_provider.dart';
import '../auth/auth_screen.dart';
import '../onboarding/tutorial_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  final Duration minDuration;
  final VoidCallback? onFinished;

  const SplashScreen({
    super.key,
    this.minDuration = const Duration(milliseconds: 1900),
    this.onFinished,
  });

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  String _loadingStatus = 'Initializing secure local ledger...';
  bool _minTimerDone = false;
  bool _hasNavigated = false;

  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeIn),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    if (widget.minDuration > Duration.zero) {
      _animController.repeat(reverse: true);
    }

    _startSplashLifecycle();
  }

  void _startSplashLifecycle() {
    if (widget.minDuration == Duration.zero) {
      _minTimerDone = true;
      _checkAndNavigate();
      return;
    }

    // Cycle loading status text
    _timers.add(Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _loadingStatus = 'Verifying cryptographic security...';
        });
      }
    }));

    _timers.add(Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _loadingStatus = 'Loading financial instruments...';
        });
      }
    }));

    // Minimum splash duration: ~1.9s for a refined personal brand impression
    _timers.add(Timer(widget.minDuration, () {
      if (mounted) {
        _minTimerDone = true;
        _checkAndNavigate();
      }
    }));
  }

  void _checkAndNavigate() {
    if (_hasNavigated || !mounted) return;

    final onboardingState = ref.read(onboardingProvider);
    final authState = ref.read(authProvider);

    // Wait until both providers finish their initialization
    if (onboardingState.isInitializing || authState.isInitializing || !_minTimerDone) {
      return;
    }

    _hasNavigated = true;
    _animController.stop();

    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }

    Widget targetScreen;
    if (!onboardingState.hasSeenTutorial) {
      targetScreen = const TutorialScreen();
    } else if (authState.isAuthenticated) {
      targetScreen = const ResponsiveScaffold();
    } else {
      targetScreen = const AuthScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in onboarding and auth states to trigger navigation as soon as ready
    ref.listen<OnboardingState>(onboardingProvider, (_, __) => _checkAndNavigate());
    ref.listen<AuthState>(authProvider, (_, __) => _checkAndNavigate());

    final settings = ref.watch(settingsProvider);
    final bool isDark;
    if (settings.themeMode == ThemeMode.light) {
      isDark = false;
    } else if (settings.themeMode == ThemeMode.dark) {
      isDark = true;
    } else {
      isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }

    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final badgeBg = isDark ? Colors.white.withOpacity(0.08) : AppColors.primary.withOpacity(0.08);
    final badgeBorder = isDark ? Colors.white12 : AppColors.primary.withOpacity(0.25);
    final badgeText = isDark ? AppColors.primaryLight : const Color(0xFF047857);
    final progressBg = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final statusColor = isDark ? Colors.white.withOpacity(0.70) : const Color(0xFF64748B);
    final badgeIconColor = isDark ? Colors.white54 : const Color(0xFF64748B);
    final badgeLabelColor = isDark ? Colors.white.withOpacity(0.60) : const Color(0xFF64748B);
    final versionColor = isDark ? Colors.white.withOpacity(0.35) : const Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Ambient Background Glow Circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(isDark ? 0.18 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.transfer.withOpacity(isDark ? 0.15 : 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Central Branded Hero Content
          Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: _scaleAnimation.value * _pulseAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product Logo with Ambient Glow
                  AppLogo(
                    size: 120,
                    borderRadius: 24,
                    showShadow: true,
                    heroTag: 'app_product_logo',
                    border: isDark ? null : Border.all(color: AppColors.primary.withOpacity(0.15), width: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // App Title
                  Text(
                    'Personal Finance',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Branded Subtitle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Text(
                      'PRIVATE  •  OFFLINE-FIRST  •  LEDGER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeText,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Mini Loading Bar
                  SizedBox(
                    width: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.minDuration == Duration.zero ? 1.0 : null,
                        minHeight: 4,
                        backgroundColor: progressBg,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dynamic Loading Status Text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _loadingStatus,
                      key: ValueKey<String>(_loadingStatus),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Architecture & Security Badges
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: badgeIconColor),
                    const SizedBox(width: 6),
                    Text(
                      '100% On-Device SQLite  •  Zero Cloud Dependency',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: badgeLabelColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.0.0 Production',
                  style: TextStyle(
                    fontSize: 10,
                    color: versionColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
