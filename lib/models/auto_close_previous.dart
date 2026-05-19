/// Returned in the check-in response when the connector's Phase 1
/// forgotten-check-out guard had to auto-close a prior attendance.
/// The mobile uses this to render a one-time yellow banner explaining
/// to the user what happened.
class AutoClosePrevious {
  final int attendanceId;
  final String originalCheckIn;
  final String inferredCheckOut;
  final double hoursAssumed;
  final double hoursOpenWhenClosed;

  AutoClosePrevious({
    required this.attendanceId,
    required this.originalCheckIn,
    required this.inferredCheckOut,
    required this.hoursAssumed,
    required this.hoursOpenWhenClosed,
  });

  factory AutoClosePrevious.fromJson(Map<String, dynamic> json) {
    return AutoClosePrevious(
      attendanceId: (json['attendance_id'] as num?)?.toInt() ?? 0,
      originalCheckIn: json['original_check_in']?.toString() ?? '',
      inferredCheckOut: json['inferred_check_out']?.toString() ?? '',
      hoursAssumed: (json['hours_assumed'] as num?)?.toDouble() ?? 0.0,
      hoursOpenWhenClosed:
          (json['hours_open_when_closed'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
