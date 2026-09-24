import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _isoTimeFormat = DateFormat('HH:mm');
  static final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _displayTimeFormat = DateFormat('hh:mm a');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');

  /// Formats DateTime to ISO date 'yyyy-MM-dd' in local timezone
  static String toIsoDate(DateTime date) => _isoDateFormat.format(date);

  /// Formats DateTime to ISO time 'HH:mm' in local timezone
  static String toIsoTime(DateTime date) => _isoTimeFormat.format(date);

  /// Parse ISO date string 'yyyy-MM-dd' to DateTime
  static DateTime parseIsoDate(String dateStr) {
    try {
      return _isoDateFormat.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Format date for display: "Today", "Yesterday", or "24 Sep 2026"
  static String formatSmartDate(String isoDateStr) {
    final now = DateTime.now();
    final todayStr = toIsoDate(now);
    final yesterdayStr = toIsoDate(now.subtract(const Duration(days: 1)));

    if (isoDateStr == todayStr) {
      return 'Today';
    } else if (isoDateStr == yesterdayStr) {
      return 'Yesterday';
    } else {
      try {
        final parsed = _isoDateFormat.parse(isoDateStr);
        return _displayDateFormat.format(parsed);
      } catch (_) {
        return isoDateStr;
      }
    }
  }

  /// Format ISO time '14:30' into '02:30 PM'
  static String formatDisplayTime(String isoTimeStr) {
    try {
      final parsed = _isoTimeFormat.parse(isoTimeStr);
      return _displayTimeFormat.format(parsed);
    } catch (_) {
      return isoTimeStr;
    }
  }

  /// Format DateTime to readable month & year: "September 2026"
  static String formatMonthYear(DateTime date) => _monthYearFormat.format(date);

  /// Returns start of today (00:00:00)
  static DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

  /// Returns end of today (23:59:59)
  static DateTime endOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59, 59);

  /// Returns start of current week (Monday)
  static DateTime startOfWeek(DateTime date) {
    final weekday = date.weekday;
    final monday = date.subtract(Duration(days: weekday - 1));
    return startOfDay(monday);
  }

  /// Returns start of current month
  static DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month, 1);

  /// Returns end of current month
  static DateTime endOfMonth(DateTime date) {
    final nextMonth = DateTime(date.year, date.month + 1, 1);
    return nextMonth.subtract(const Duration(seconds: 1));
  }

  /// Returns start of current year
  static DateTime startOfYear(DateTime date) => DateTime(date.year, 1, 1);

  /// Returns end of current year
  static DateTime endOfYear(DateTime date) => DateTime(date.year, 12, 31, 23, 59, 59);
}
