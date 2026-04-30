class LeaveRecord {
  final int id;
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

  LeaveRecord({
    required this.id,
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
      allocationTotal: (json['allocation_total'] as num?)?.toDouble(),
      allocationTaken: (json['allocation_taken'] as num?)?.toDouble(),
      allocationRemaining: (json['allocation_remaining'] as num?)?.toDouble(),
      requiresAllocation: _parseBool(json['requires_allocation']),
    );
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
      default:
        return state;
    }
  }
}
