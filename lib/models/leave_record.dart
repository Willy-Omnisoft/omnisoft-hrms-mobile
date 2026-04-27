class LeaveRecord {
  final int id;
  final String leaveType;
  final String? dateFrom;
  final String? dateTo;
  final double numberOfDays;
  final String state;
  final String reason;

  LeaveRecord({
    required this.id,
    required this.leaveType,
    this.dateFrom,
    this.dateTo,
    required this.numberOfDays,
    required this.state,
    this.reason = '',
  });

  factory LeaveRecord.fromJson(Map<String, dynamic> json) {
    return LeaveRecord(
      id: json['id'] ?? 0,
      leaveType: json['leave_type'] ?? '',
      dateFrom: json['date_from']?.toString(),
      dateTo: json['date_to']?.toString(),
      numberOfDays: (json['number_of_days'] ?? 0).toDouble(),
      state: json['state'] ?? '',
      reason: json['reason'] ?? '',
    );
  }

  String get stateLabel {
    switch (state) {
      case 'draft':
        return 'Draft';
      case 'confirm':
        return 'Pending';
      case 'validate1':
        return 'Approved (L1)';
      case 'validate':
        return 'Approved';
      case 'refuse':
        return 'Refused';
      default:
        return state;
    }
  }
}
