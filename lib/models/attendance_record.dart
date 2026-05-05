class AttendanceRecord {
  final int id;
  final DateTime? date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double workedHours;
  final String? inMode;
  final String? outMode;
  final double? inLatitude;
  final double? inLongitude;

  AttendanceRecord({
    required this.id,
    this.date,
    this.checkIn,
    this.checkOut,
    this.workedHours = 0,
    this.inMode,
    this.outMode,
    this.inLatitude,
    this.inLongitude,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] ?? 0,
      date: _parseDate(json['date']),
      checkIn: _parseDateTime(json['check_in']),
      checkOut: _parseDateTime(json['check_out']),
      workedHours: (json['worked_hours'] as num?)?.toDouble() ?? 0,
      inMode: json['in_mode']?.toString(),
      outMode: json['out_mode']?.toString(),
      inLatitude: (json['in_latitude'] as num?)?.toDouble(),
      inLongitude: (json['in_longitude'] as num?)?.toDouble(),
    );
  }

  bool get isOpen => checkOut == null;

  /// 'Mobile' / 'Kiosk' / 'Manual' / 'Auto check-out' / '—' — surfaced
  /// as a small pill so the user can spot HR-corrected entries vs
  /// in-app check-ins.
  String get modeLabel {
    switch (inMode) {
      case 'mobile':
        return 'Mobile';
      case 'kiosk':
        return 'Kiosk';
      case 'systray':
        return 'Web';
      case 'manual':
        return 'Manual';
      case 'auto_check_out':
        return 'Auto check-out';
      default:
        return '—';
    }
  }

  /// '8.5h' / '8h' — short form for the times row. Returns 'so far'
  /// suffix from the caller; we just produce the number.
  String get hoursLabel {
    final h = workedHours;
    if (h == h.roundToDouble()) return '${h.toInt()}h';
    return '${h.toStringAsFixed(1)}h';
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null || v == false) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null || v == false) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    // Server returns ISO8601 in UTC (no zone). Treat as UTC, then convert
    // to local for display so check-in/out times are correct in the
    // user's timezone.
    final parsed = DateTime.tryParse(s);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : DateTime.utc(
      parsed.year, parsed.month, parsed.day,
      parsed.hour, parsed.minute, parsed.second,
    ).toLocal();
  }
}
