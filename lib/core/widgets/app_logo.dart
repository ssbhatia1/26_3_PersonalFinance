import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showShadow;
  final BoxBorder? border;
  final String? heroTag;

  const AppLogo({
    super.key,
    this.size = 48.0,
    this.borderRadius = 12.0,
    this.showShadow = false,
    this.border,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/images/app_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback if image asset is unavailable or in test environment
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF10B981),
                  Color(0xFF059669),
                  Color(0xFF047857),
                ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Center(
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: size * 0.55,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );

    if (showShadow) {
      imageWidget = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: border,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: size * 0.35,
              offset: Offset(0, size * 0.1),
            ),
          ],
        ),
        child: imageWidget,
      );
    } else if (border != null) {
      imageWidget = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: border,
        ),
        child: imageWidget,
      );
    }

    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
