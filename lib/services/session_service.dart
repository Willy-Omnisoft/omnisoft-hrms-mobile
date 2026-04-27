import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService extends ChangeNotifier {
  static const _keySaasUrl = 'saas_url';
  static const _keyCompanyCode = 'company_code';
  static const _keyClientUrl = 'client_url';
  static const _keyClientDb = 'client_db';
  static const _keyToken = 'token';

  String _saasUrl = '';
  String _companyCode = '';
  String _clientUrl = '';
  String _clientDb = '';
  String _token = '';

  String get saasUrl => _saasUrl;
  String get companyCode => _companyCode;
  String get clientUrl => _clientUrl;
  String get clientDb => _clientDb;
  String get token => _token;
  bool get isLoggedIn => _token.isNotEmpty && _clientUrl.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _saasUrl = prefs.getString(_keySaasUrl) ?? '';
    _companyCode = prefs.getString(_keyCompanyCode) ?? '';
    _clientUrl = prefs.getString(_keyClientUrl) ?? '';
    _clientDb = prefs.getString(_keyClientDb) ?? '';
    _token = prefs.getString(_keyToken) ?? '';
    notifyListeners();
  }

  Future<void> saveCompany({
    required String saasUrl,
    required String companyCode,
    required String clientUrl,
    String clientDb = '',
  }) async {
    _saasUrl = saasUrl;
    _companyCode = companyCode;
    _clientUrl = clientUrl;
    _clientDb = clientDb;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySaasUrl, saasUrl);
    await prefs.setString(_keyCompanyCode, companyCode);
    await prefs.setString(_keyClientUrl, clientUrl);
    await prefs.setString(_keyClientDb, clientDb);
    notifyListeners();
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = '';
    _clientUrl = '';
    _clientDb = '';
    _companyCode = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
