import 'package:flutter/foundation.dart';
import '../models/public_holiday.dart';
import 'omni_mobile_api.dart';
import 'session_service.dart';

/// In-memory cache of public holidays keyed by yyyy-MM-dd.
///
/// Fetched once after login; consumed by date pickers (apply / edit /
/// hourly date) to highlight non-working days.
class HolidayService extends ChangeNotifier {
  Map<String, PublicHoliday> _byIsoDate = const {};
  bool _loading = false;

  Map<String, PublicHoliday> get byIsoDate => _byIsoDate;
  bool get loading => _loading;

  String? holidayName(DateTime d) {
    final key =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return _byIsoDate[key]?.name;
  }

  bool isHoliday(DateTime d) => holidayName(d) != null;

  Future<void> loadFromSession(SessionService session) async {
    if (_loading || !session.isLoggedIn) return;
    _loading = true;
    try {
      final api = OmniMobileApi(
        baseUrl: session.clientUrl,
        db: session.clientDb,
        token: session.token,
      );
      final list = await api.getPublicHolidays();
      _byIsoDate = {
        for (final h in list)
          '${h.date.year.toString().padLeft(4, '0')}-${h.date.month.toString().padLeft(2, '0')}-${h.date.day.toString().padLeft(2, '0')}':
              h,
      };
      notifyListeners();
    } catch (_) {
      // Non-fatal — calendar just won't have holiday markers.
    } finally {
      _loading = false;
    }
  }

  void clear() {
    _byIsoDate = const {};
    notifyListeners();
  }
}
