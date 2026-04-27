import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/company_info.dart';

class SaasService {
  Future<CompanyInfo> resolveCompany(String saasUrl, String companyCode) async {
    final url = Uri.parse('$saasUrl/omni_hrms/resolve_company');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'company_code': companyCode}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to resolve company');
    }
    return CompanyInfo.fromJson(data);
  }
}
