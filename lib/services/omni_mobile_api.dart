import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/attendance_record.dart';
import '../models/attendance_status.dart';
import '../models/leave_type.dart';
import '../models/leave_record.dart';
import '../models/public_holiday.dart';

class OmniMobileApi {
  final String baseUrl;
  final String db;
  final String token;

  OmniMobileApi({
    required this.baseUrl,
    required this.db,
    required this.token,
  });

  /// Wired in main.dart at app boot. Called whenever any /api/v1/...
  /// call returns `error: invalid_session` (or the legacy alias
  /// `invalid_token`). Typical wiring: SessionService.clearSession,
  /// which causes the top-level Consumer<SessionService> in
  /// OmniHrApp to re-render and route the user back to LoginScreen.
  static void Function()? onInvalidSession;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) =>
      Uri.parse('$baseUrl/api/v1/omni_mobile$path?db=$db');

  Future<Map<String, dynamic>> _post(String path,
      [Map<String, dynamic>? body]) async {
    final response = await http.post(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body ?? {}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      final code = data['error']?.toString();
      // 'invalid_token' kept for legacy; new server returns 'invalid_session'.
      if (code == 'invalid_session' || code == 'invalid_token') {
        onInvalidSession?.call();
      }
      throw ApiException.fromBody(data);
    }
    return data;
  }

  // -- Auth --

  Future<Map<String, dynamic>> login({
    required String login,
    required String password,
    String? deviceId,
    String? appVersion,
  }) async {
    return _post('/login', {
      'login': login,
      'password': password,
      if (deviceId != null) 'device_id': deviceId,
      if (appVersion != null) 'app_version': appVersion,
    });
  }

  Future<Map<String, dynamic>> logout() async {
    return _post('/logout');
  }

  Future<Map<String, dynamic>> me() async {
    return _post('/me');
  }

  // -- Attendance --

  Future<AttendanceStatus> getAttendanceStatus() async {
    final data = await _post('/attendance/status');
    return AttendanceStatus.fromJson(data);
  }

  Future<Map<String, dynamic>> checkIn({
    required double latitude,
    required double longitude,
    bool faceVerified = true,
    String? deviceId,
    bool devLocation = false,
  }) async {
    return _post('/attendance/check_in', {
      'latitude': latitude,
      'longitude': longitude,
      'face_verified': faceVerified,
      if (deviceId != null) 'device_id': deviceId,
      // Server bypasses geofence when this flag is set. Only sent
      // when DevConstants.useDevLocation is true. Server logs a
      // warning per call so dev usage is auditable.
      if (devLocation) '_dev_location': true,
    });
  }

  Future<Map<String, dynamic>> checkOut({
    required double latitude,
    required double longitude,
    bool faceVerified = true,
    String? deviceId,
    bool devLocation = false,
  }) async {
    return _post('/attendance/check_out', {
      'latitude': latitude,
      'longitude': longitude,
      'face_verified': faceVerified,
      if (deviceId != null) 'device_id': deviceId,
      if (devLocation) '_dev_location': true,
    });
  }

  Future<List<AttendanceRecord>> getAttendanceHistory() async {
    final data = await _post('/attendance/history');
    final list = (data['attendances'] as List<dynamic>?) ?? const [];
    return list
        .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -- Leave --

  Future<List<LeaveType>> getLeaveTypes() async {
    final data = await _post('/leave/types');
    final list = data['leave_types'] as List<dynamic>;
    return list
        .map((e) => LeaveType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> applyLeave({
    required int holidayStatusId,
    required String dateFrom,
    required String dateTo,
    String reason = '',
    String? dateFromPeriod,
    String? dateToPeriod,
    double? hourFrom,
    double? hourTo,
    Map<String, dynamic>? attachment,
  }) async {
    return _post('/leave/apply', {
      'holiday_status_id': holidayStatusId,
      'date_from': dateFrom,
      'date_to': dateTo,
      'reason': reason,
      if (dateFromPeriod != null) 'date_from_period': dateFromPeriod,
      if (dateToPeriod != null) 'date_to_period': dateToPeriod,
      if (hourFrom != null) 'hour_from': hourFrom,
      if (hourTo != null) 'hour_to': hourTo,
      if (attachment != null) 'attachment': attachment,
    });
  }

  // -- Face enrollment --

  Future<Map<String, dynamic>> getEnrolledFace() async {
    return _post('/face/enrolled');
  }

  Future<Map<String, dynamic>> enrollFace({
    required String faceImageBase64,
    String filename = 'enrollment.jpg',
  }) async {
    return _post('/face/enroll', {
      'face_image_base64': faceImageBase64,
      'filename': filename,
    });
  }

  Future<Map<String, dynamic>> clearEnrolledFace() async {
    return _post('/face/clear');
  }

  Future<List<LeaveRecord>> getLeaveHistory() async {
    final data = await _post('/leave/history');
    final list = data['leaves'] as List<dynamic>;
    return list
        .map((e) => LeaveRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> cancelLeave({
    required int leaveId,
    String? reason,
  }) async {
    return _post('/leave/cancel', {
      'leave_id': leaveId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<CalendarInfoResponse> getPublicHolidays() async {
    final data = await _post('/public_holidays');
    final list = data['holidays'] as List<dynamic>;
    final weekdays = (data['working_weekdays'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const [0, 1, 2, 3, 4]; // server convention: Mon=0..Sun=6
    return CalendarInfoResponse(
      holidays: list
          .map((e) => PublicHoliday.fromJson(e as Map<String, dynamic>))
          .toList(),
      workingWeekdays: weekdays,
    );
  }

  Future<Map<String, dynamic>> deleteAttachment(int attachmentId) {
    return _post('/leave/attachment/delete', {'attachment_id': attachmentId});
  }

  Future<Map<String, dynamic>> getAttachment(int attachmentId) {
    return _post('/leave/attachment/get', {'attachment_id': attachmentId});
  }

  Future<Map<String, dynamic>> modifyLeave({
    required int leaveId,
    required String dateFrom,
    required String dateTo,
    required String reason,
    String? dateFromPeriod,
    String? dateToPeriod,
    double? hourFrom,
    double? hourTo,
    Map<String, dynamic>? attachment,
  }) async {
    return _post('/leave/modify', {
      'leave_id': leaveId,
      'date_from': dateFrom,
      'date_to': dateTo,
      'reason': reason,
      if (dateFromPeriod != null) 'date_from_period': dateFromPeriod,
      if (dateToPeriod != null) 'date_to_period': dateToPeriod,
      if (hourFrom != null) 'hour_from': hourFrom,
      if (hourTo != null) 'hour_to': hourTo,
      if (attachment != null) 'attachment': attachment,
    });
  }
}

class CalendarInfoResponse {
  final List<PublicHoliday> holidays;
  final List<int> workingWeekdays; // Odoo: Mon=0..Sun=6

  CalendarInfoResponse({
    required this.holidays,
    required this.workingWeekdays,
  });
}

class ApiException implements Exception {
  /// Server-side error code, e.g. "outside_geofence",
  /// "office_geofence_not_configured", "face_not_verified".
  final String errorCode;

  /// Whole response body for inspection by the UI.
  final Map<String, dynamic>? data;

  /// Populated for outside_geofence — meters from office at submit time.
  final double? distanceFromOffice;

  /// Populated for outside_geofence — meters of allowed radius.
  final double? allowedRadius;

  ApiException(
    this.errorCode, {
    this.data,
    this.distanceFromOffice,
    this.allowedRadius,
  });

  /// Backwards-compatible getter for callers that still inspect
  /// `e.toString()` for keyword matching.
  String get error => errorCode;

  factory ApiException.fromBody(Map<String, dynamic> body) {
    final code = body['error']?.toString() ?? 'Unknown error';
    return ApiException(
      code,
      data: body,
      distanceFromOffice:
          (body['distance_from_office'] as num?)?.toDouble(),
      allowedRadius: (body['allowed_radius'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() => errorCode;
}
