import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _dayMonthYear = DateFormat('dd MMM yyyy');
  static final DateFormat _monthYear = DateFormat('MMM yyyy');
  static final DateFormat _shortDate = DateFormat('dd MMM');
  static final DateFormat _isoFormat = DateFormat('yyyy-MM-ddTHH:mm:ss');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');

  static String formatDisplay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final aDate = DateTime(date.year, date.month, date.day);

    if (aDate == today) {
      return 'Today, ${_timeFormat.format(date)}';
    } else if (aDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${_timeFormat.format(date)}';
    } else if (date.year == now.year) {
      return '${_shortDate.format(date)}, ${_timeFormat.format(date)}';
    }
    return '${_dayMonthYear.format(date)}, ${_timeFormat.format(date)}';
  }

  static String formatShortDate(DateTime date) {
    return _shortDate.format(date);
  }

  static String formatFullDate(DateTime date) {
    return _dayMonthYear.format(date);
  }

  static String formatMonthYear(DateTime date) {
    return _monthYear.format(date);
  }

  static String toIso(DateTime date) {
    return _isoFormat.format(date);
  }

  static DateTime parseIso(String isoString) {
    return DateTime.tryParse(isoString) ?? DateTime.now();
  }
}
