/// One published payslip the employee can view, sourced from
/// `POST /api/v1/omni_mobile/payslip/list`. State is always one of
/// 'done' or 'paid' — drafts and cancelled payslips are filtered
/// out server-side.
class PayslipRecord {
  final int id;
  final String name;        // e.g. "SLIP/2026/04"
  final String dateFrom;    // ISO yyyy-mm-dd
  final String dateTo;      // ISO yyyy-mm-dd
  final String state;       // 'done' | 'paid'
  final double netAmount;
  final int currencyId;
  final String currencyName;

  PayslipRecord({
    required this.id,
    required this.name,
    required this.dateFrom,
    required this.dateTo,
    required this.state,
    required this.netAmount,
    this.currencyId = 0,
    this.currencyName = '',
  });

  factory PayslipRecord.fromJson(Map<String, dynamic> json) {
    return PayslipRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      dateFrom: json['date_from']?.toString() ?? '',
      dateTo: json['date_to']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0.0,
      currencyId: (json['currency_id'] as num?)?.toInt() ?? 0,
      currencyName: json['currency_name']?.toString() ?? '',
    );
  }

  String get stateLabel {
    switch (state) {
      case 'validated':
        return 'Validated';
      case 'done':
        return 'Posted';
      case 'paid':
        return 'Paid';
      default:
        return state;
    }
  }
}
