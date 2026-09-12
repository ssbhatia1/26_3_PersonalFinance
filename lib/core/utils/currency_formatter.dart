import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(double amount, {String symbol = '₹', bool showSign = false, int decimalDigits = 2}) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    
    // Format based on standard grouping
    final formatter = NumberFormat.currency(
      symbol: '',
      decimalDigits: decimalDigits,
    );
    final formattedValue = formatter.format(absAmount).trim();

    if (showSign) {
      if (amount > 0) return '+$symbol$formattedValue';
      if (amount < 0) return '-$symbol$formattedValue';
      return '$symbol$formattedValue';
    }

    return isNegative ? '-$symbol$formattedValue' : '$symbol$formattedValue';
  }

  static String formatCompact(double amount, {String symbol = '₹'}) {
    final absAmount = amount.abs();
    final isNegative = amount < 0;
    String formatted;

    if (symbol == '₹') {
      // Indian numbering format (Lakhs, Crores)
      if (absAmount >= 10000000) {
        formatted = '${(absAmount / 10000000).toStringAsFixed(1)}Cr';
      } else if (absAmount >= 100000) {
        formatted = '${(absAmount / 100000).toStringAsFixed(1)}L';
      } else if (absAmount >= 1000) {
        formatted = '${(absAmount / 1000).toStringAsFixed(1)}K';
      } else {
        formatted = absAmount.toStringAsFixed(0);
      }
    } else {
      // International compact format (K, M, B)
      if (absAmount >= 1000000000) {
        formatted = '${(absAmount / 1000000000).toStringAsFixed(1)}B';
      } else if (absAmount >= 1000000) {
        formatted = '${(absAmount / 1000000).toStringAsFixed(1)}M';
      } else if (absAmount >= 1000) {
        formatted = '${(absAmount / 1000).toStringAsFixed(1)}K';
      } else {
        formatted = absAmount.toStringAsFixed(0);
      }
    }

    return isNegative ? '-$symbol$formatted' : '$symbol$formatted';
  }
}
