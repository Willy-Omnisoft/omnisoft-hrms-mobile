class CompanyInfo {
  final String companyCode;
  final String name;
  final String odooUrl;
  final Map<String, bool> features;
  final String minimumAppVersion;

  CompanyInfo({
    required this.companyCode,
    required this.name,
    required this.odooUrl,
    required this.features,
    this.minimumAppVersion = '',
  });

  factory CompanyInfo.fromJson(Map<String, dynamic> json) {
    final client = json['client'] as Map<String, dynamic>;
    final features = (client['features'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v == true)) ??
        {};
    return CompanyInfo(
      companyCode: client['company_code'] ?? '',
      name: client['name'] ?? '',
      odooUrl: client['odoo_url'] ?? '',
      features: features,
      minimumAppVersion: client['minimum_app_version'] ?? '',
    );
  }
}
