class LeaveType {
  final int id;
  final String name;
  final bool requiresAllocation;
  final String requestUnit;
  final int color;
  final String mobileCategory;
  final bool mobileRequiresDocument;

  // Balance fields — null when requiresAllocation is false (the
  // type is "unlimited"). When requiresAllocation is true these
  // reflect this employee's current allocation/usage from Odoo's
  // hr.leave.type computed fields.
  final double? maxLeaves;
  final double? leavesTaken;
  final double? virtualRemainingLeaves;

  LeaveType({
    required this.id,
    required this.name,
    required this.requiresAllocation,
    this.requestUnit = 'day',
    this.color = 0,
    this.mobileCategory = 'other',
    this.mobileRequiresDocument = false,
    this.maxLeaves,
    this.leavesTaken,
    this.virtualRemainingLeaves,
  });

  factory LeaveType.fromJson(Map<String, dynamic> json) {
    return LeaveType(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      requiresAllocation: json['requires_allocation'] == true,
      requestUnit: json['request_unit'] ?? 'day',
      color: json['color'] ?? 0,
      mobileCategory: json['mobile_category'] ?? 'other',
      mobileRequiresDocument: json['mobile_requires_document'] == true,
      maxLeaves: _toDouble(json['max_leaves']),
      leavesTaken: _toDouble(json['leaves_taken']),
      virtualRemainingLeaves: _toDouble(json['virtual_remaining_leaves']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
