import 'package:intl/intl.dart';

/// Utilities for converting Odoo UTC datetime strings to local time.
///
/// Odoo returns datetimes as "yyyy-MM-dd HH:mm:ss" in UTC
/// but without a timezone suffix. Dart's DateTime.parse treats
/// strings without a suffix as local time, so we explicitly
/// mark them as UTC before converting to local.
class DateTimeUtils {
  /// Parse an Odoo datetime string as UTC.
  /// Returns null if the input is null, empty, or unparseable.
  static DateTime? parseOdooUtc(String? value) {
    if (value == null || value.isEmpty || value == 'false') return null;
    try {
      var s = value.trim();
      // If it already contains timezone info, parse directly
      if (s.endsWith('Z') || s.contains('+') || s.contains('T')) {
        return DateTime.parse(s).toUtc();
      }
      // Odoo format "yyyy-MM-dd HH:mm:ss" — treat as UTC
      return DateTime.parse('${s}Z').toUtc();
    } catch (_) {
      return null;
    }
  }

  /// Format as local time only: "09:35"
  static String formatLocalTime(String? value) {
    final dt = parseOdooUtc(value);
    if (dt == null) return '--:--';
    final local = dt.toLocal();
    return DateFormat.Hm().format(local);
  }

  /// Format as local date and time: "27 Apr 09:35"
  static String formatLocalDateTime(String? value) {
    final dt = parseOdooUtc(value);
    if (dt == null) return '-';
    final local = dt.toLocal();
    return DateFormat('dd MMM HH:mm').format(local);
  }

  /// Format as local date only: "27 Apr 2026"
  static String formatLocalDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    try {
      final dt = DateTime.parse(value);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return value;
    }
  }

  /// Relative-ish label for a submission timestamp. Used as the
  /// primary date on list cards where "when did I submit this" is
  /// the dominant question (vs. when the receipt was issued):
  ///   • today           → "Submitted today"
  ///   • yesterday       → "Submitted yesterday"
  ///   • within 7 days   → "Submitted Nd ago"
  ///   • within 1 year   → "Submitted 27 Apr"
  ///   • older           → "Submitted 27 Apr 2024"
  /// Accepts the Odoo "yyyy-MM-dd HH:mm:ss" UTC shape via parseOdooUtc.
  static String formatSubmittedAgo(String? value) {
    final dt = parseOdooUtc(value);
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(local.year, local.month, local.day);
    final delta = today.difference(d).inDays;
    if (delta == 0) return 'Submitted today';
    if (delta == 1) return 'Submitted yesterday';
    if (delta < 7) return 'Submitted ${delta}d ago';
    if (local.year == now.year) {
      return 'Submitted ${DateFormat('d MMM').format(local)}';
    }
    return 'Submitted ${DateFormat('d MMM yyyy').format(local)}';
  }
}
