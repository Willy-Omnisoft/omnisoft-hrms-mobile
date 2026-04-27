class AttendanceStatus {
  final bool checkedIn;
  final String? currentCheckInTime;
  final String? lastCheckInTime;
  final double hoursToday;
  final int employeeId;
  final String authType;

  AttendanceStatus({
    required this.checkedIn,
    this.currentCheckInTime,
    this.lastCheckInTime,
    required this.hoursToday,
    required this.employeeId,
    required this.authType,
  });

  factory AttendanceStatus.fromJson(Map<String, dynamic> json) {
    return AttendanceStatus(
      checkedIn: json['checked_in'] == true,
      currentCheckInTime: json['current_check_in_time']?.toString(),
      lastCheckInTime: json['last_check_in_time']?.toString(),
      hoursToday: (json['hours_today'] ?? 0).toDouble(),
      employeeId: json['employee_id'] ?? 0,
      authType: json['auth_type'] ?? '',
    );
  }
}
