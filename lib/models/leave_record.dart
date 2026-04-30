class LeaveRecord {
  final int id;
  final int leaveTypeId;
  final String leaveType;
  final String? dateFrom;
  final String? dateTo;
  final double numberOfDays;
  final String state;
  final String reason;
  final double? allocationTotal;
  final double? allocationTaken;
  final double? allocationRemaining;
  final bool requiresAllocation;
  final String requestUnit;
  final String? dateFromPeriod;
  final String? dateToPeriod;

  LeaveRecord({
    required this.id,
    this.leaveTypeId = 0,
    required this.leaveType,
    this.dateFrom,
    this.dateTo,
    required this.numberOfDays,
    required this.state,
    this.reason = '',
    this.allocationTotal,
    this.allocationTaken,
    this.allocationRemaining,
    this.requiresAllocation = false,
    this.requestUnit = 'day',
    this.dateFromPeriod,
    this.dateToPeriod,
  });

  factory LeaveRecord.fromJson(Map<String, dynamic> json) {
    return LeaveRecord(
      id: json['id'] ?? 0,
      leaveTypeId: json['leave_type_id'] ?? 0,
      leaveType: json['leave_type'] ?? '',
      dateFrom: json['date_from']?.toString(),
      dateTo: json['date_to']?.toString(),
      numberOfDays: (json['number_of_days'] ?? 0).toDouble(),
      state: json['state'] ?? '',
      reason: json['reason'] ?? '',
      allocationTotal: (json['allocation_total'] as num?)?.toDouble(),
      allocationTaken: (json['allocation_taken'] as num?)?.toDouble(),
      allocationRemaining: (json['allocation_remaining'] as num?)?.toDouble(),
      requiresAllocation: _parseBool(json['requires_allocation']),
      requestUnit: json['request_unit'] ?? 'day',
      dateFromPeriod: json['date_from_period']?.toString(),
      dateToPeriod: json['date_to_period']?.toString(),
    );
  }

  String get daysLabel {
    final n = numberOfDays;
    return n == n.roundToDouble()
        ? '${n.toInt()}d'
        : '${n.toStringAsFixed(1)}d';
  }

  static bool _parseBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == 'yes' || s == '1';
    }
    return false;
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
      case 'cancel':
        return 'Cancelled';
      default:
        return state;
    }
  }
}
