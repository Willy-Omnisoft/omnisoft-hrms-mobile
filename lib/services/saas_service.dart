import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/company_info.dart';

class SaasService {
  Future<CompanyInfo> resolveCompany(String saasUrl, String companyCode) async {
    final parsed = Uri.tryParse(saasUrl);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      throw Exception('Invalid SaaS URL.');
    }
    // Cloud Odoo serves only HTTPS; a 301 redirect downgrades POST→GET in
    // most HTTP clients, which then hits a 405 HTML page that fails to parse
    // as JSON. Reject http:// for non-loopback hosts up front with a clear
    // message instead of letting it fail downstream.
    final isLoopback = parsed.host == 'localhost' ||
        parsed.host == '127.0.0.1' ||
        parsed.host.startsWith('192.168.') ||
        parsed.host.startsWith('10.');
    if (parsed.scheme == 'http' && !isLoopback) {
      throw Exception('SaaS URL must use HTTPS for cloud deployments.');
    }

    final url = Uri.parse('$saasUrl/omni_hrms/resolve_company');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'company_code': companyCode}),
    );

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw Exception(
        'SaaS returned a non-JSON response (HTTP ${response.statusCode}). '
        'Check the SaaS URL and that the omni_hrms_saas module is installed.',
      );
    }
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to resolve company');
    }
    return CompanyInfo.fromJson(data);
  }
}
