import 'package:flutter/foundation.dart';
import '../models/public_holiday.dart';
import 'omni_mobile_api.dart';
import 'session_service.dart';

/// In-memory cache of the employee's calendar info: public holidays
/// plus the set of weekdays (Mon=1 … Sun=7 in Dart convention) that
/// the employee actually works on. Fetched once after login.
///
/// Consumed by the date pickers to grey out non-working days and by
/// the day-count math so weekends and holidays don't inflate the
/// duration shown to users.
class HolidayService extends ChangeNotifier {
  Map<String, PublicHoliday> _byIsoDate = const {};
  // Dart's DateTime.weekday is 1=Mon..7=Sun. We store using that.
  Set<int> _workingWeekdays = const {1, 2, 3, 4, 5};
  bool _loading = false;

  Map<String, PublicHoliday> get byIsoDate => _byIsoDate;
  Set<int> get workingWeekdays => _workingWeekdays;
  bool get loading => _loading;

  String _isoOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? holidayName(DateTime d) => _byIsoDate[_isoOf(d)]?.name;

  bool isHoliday(DateTime d) => holidayName(d) != null;

  /// True only if the day is a configured working weekday AND not a
  /// public holiday.
  bool isWorkingDay(DateTime d) {
    return _workingWeekdays.contains(d.weekday) && !isHoliday(d);
  }

  /// Inclusive count of working days in [start, end].
  int workingDaysBetween(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    var count = 0;
    var d = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(last)) {
      if (isWorkingDay(d)) count++;
      d = d.add(const Duration(days: 1));
    }
    return count;
  }

  Future<void> loadFromSession(SessionService session) async {
    if (_loading || !session.isLoggedIn) return;
    _loading = true;
    try {
      final api = OmniMobileApi(
        baseUrl: session.clientUrl,
        db: session.clientDb,
        token: session.token,
      );
      final res = await api.getPublicHolidays();
      _byIsoDate = {
        for (final h in res.holidays) _isoOf(h.date): h,
      };
      // Server returns Odoo's Monday=0 convention; convert to Dart's
      // Monday=1 by adding 1. Odoo Sunday=6 → Dart 7.
      _workingWeekdays =
          res.workingWeekdays.map((d) => d + 1).toSet();
      if (_workingWeekdays.isEmpty) {
        _workingWeekdays = {1, 2, 3, 4, 5};
      }
      notifyListeners();
    } catch (_) {
      // Non-fatal — calendar just won't have holiday/weekend markers.
    } finally {
      _loading = false;
    }
  }

  void clear() {
    _byIsoDate = const {};
    _workingWeekdays = const {1, 2, 3, 4, 5};
    notifyListeners();
  }
}
