import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/attendance_status.dart';
import '../models/leave_type.dart';
import '../models/leave_record.dart';

class OmniMobileApi {
  final String baseUrl;
  final String db;
  final String token;

  OmniMobileApi({
    required this.baseUrl,
    required this.db,
    required this.token,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
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
      throw ApiException(data['error']?.toString() ?? 'Unknown error', data);
    }
    return data;
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
  }) async {
    return _post('/attendance/check_in', {
      'latitude': latitude,
      'longitude': longitude,
      'face_verified': faceVerified,
      if (deviceId != null) 'device_id': deviceId,
    });
  }

  Future<Map<String, dynamic>> checkOut({
    required double latitude,
    required double longitude,
    bool faceVerified = true,
    String? deviceId,
  }) async {
    return _post('/attendance/check_out', {
      'latitude': latitude,
      'longitude': longitude,
      'face_verified': faceVerified,
      if (deviceId != null) 'device_id': deviceId,
    });
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

class ApiException implements Exception {
  final String error;
  final Map<String, dynamic>? data;
  ApiException(this.error, [this.data]);

  @override
  String toString() => error;
}
