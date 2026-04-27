class LeaveType {
  final int id;
  final String name;
  final bool requiresAllocation;
  final String requestUnit;
  final int color;
  final String mobileCategory;
  final bool mobileRequiresDocument;

  LeaveType({
    required this.id,
    required this.name,
    required this.requiresAllocation,
    this.requestUnit = 'day',
    this.color = 0,
    this.mobileCategory = 'other',
    this.mobileRequiresDocument = false,
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
    );
  }
}
