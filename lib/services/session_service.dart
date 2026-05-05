import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session state for the mobile app. Persists across launches.
///
/// Layout:
/// - SaaS routing (saasUrl, companyCode, clientUrl, clientDb) survives
///   logout — re-login on the same device should not require re-typing
///   the company code.
/// - Login session (accessToken, expiresAt, userLogin, userName,
///   employeeId, employeeName) is wiped on logout or when the server
///   returns invalid_session.
class SessionService extends ChangeNotifier {
  // Keys: SaaS routing (kept across logout)
  static const _keySaasUrl = 'saas_url';
  static const _keyCompanyCode = 'company_code';
  static const _keyClientUrl = 'client_url';
  static const _keyClientDb = 'client_db';

  // Keys: login session (cleared on logout)
  static const _keyAccessToken = 'access_token';
  static const _keyExpiresAt = 'expires_at';
  static const _keyUserId = 'user_id';
  static const _keyUserLogin = 'user_login';
  static const _keyUserName = 'user_name';
  static const _keyEmployeeId = 'employee_id';
  static const _keyEmployeeName = 'employee_name';

  String _saasUrl = '';
  String _companyCode = '';
  String _clientUrl = '';
  String _clientDb = '';

  String _accessToken = '';
  DateTime? _expiresAt;
  int _userId = 0;
  String _userLogin = '';
  String _userName = '';
  int _employeeId = 0;
  String _employeeName = '';

  // SaaS routing
  String get saasUrl => _saasUrl;
  String get companyCode => _companyCode;
  String get clientUrl => _clientUrl;
  String get clientDb => _clientDb;

  // Auth session
  String get accessToken => _accessToken;
  /// Back-compat alias used by existing call sites.
  String get token => _accessToken;
  DateTime? get expiresAt => _expiresAt;
  int get userId => _userId;
  String get userLogin => _userLogin;
  String get userName => _userName;
  int get employeeId => _employeeId;
  String get employeeName => _employeeName;

  bool get isLoggedIn =>
      _accessToken.isNotEmpty &&
      _clientUrl.isNotEmpty &&
      (_expiresAt == null || _expiresAt!.isAfter(DateTime.now()));

  bool get hasCompany => _clientUrl.isNotEmpty && _companyCode.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _saasUrl = prefs.getString(_keySaasUrl) ?? '';
    _companyCode = prefs.getString(_keyCompanyCode) ?? '';
    _clientUrl = prefs.getString(_keyClientUrl) ?? '';
    _clientDb = prefs.getString(_keyClientDb) ?? '';
    _accessToken = prefs.getString(_keyAccessToken) ?? '';
    final exp = prefs.getString(_keyExpiresAt);
    _expiresAt = exp != null && exp.isNotEmpty ? DateTime.tryParse(exp) : null;
    _userId = prefs.getInt(_keyUserId) ?? 0;
    _userLogin = prefs.getString(_keyUserLogin) ?? '';
    _userName = prefs.getString(_keyUserName) ?? '';
    _employeeId = prefs.getInt(_keyEmployeeId) ?? 0;
    _employeeName = prefs.getString(_keyEmployeeName) ?? '';
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

  /// Persist everything returned by /login in one call.
  Future<void> saveSession({
    required String accessToken,
    DateTime? expiresAt,
    required int userId,
    required String userLogin,
    required String userName,
    required int employeeId,
    required String employeeName,
  }) async {
    _accessToken = accessToken;
    _expiresAt = expiresAt;
    _userId = userId;
    _userLogin = userLogin;
    _userName = userName;
    _employeeId = employeeId;
    _employeeName = employeeName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyExpiresAt, expiresAt?.toIso8601String() ?? '');
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyUserLogin, userLogin);
    await prefs.setString(_keyUserName, userName);
    await prefs.setInt(_keyEmployeeId, employeeId);
    await prefs.setString(_keyEmployeeName, employeeName);
    notifyListeners();
  }

  /// Clear only the auth session keys. SaaS routing stays so re-login
  /// doesn't require re-entering the company code.
  Future<void> clearSession() async {
    _accessToken = '';
    _expiresAt = null;
    _userId = 0;
    _userLogin = '';
    _userName = '';
    _employeeId = 0;
    _employeeName = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyExpiresAt);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserLogin);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyEmployeeId);
    await prefs.remove(_keyEmployeeName);
    notifyListeners();
  }

  /// Full reset (clears SaaS routing too). Used when the user wants to
  /// switch companies entirely.
  Future<void> logout() async {
    _saasUrl = '';
    _companyCode = '';
    _clientUrl = '';
    _clientDb = '';
    await clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySaasUrl);
    await prefs.remove(_keyCompanyCode);
    await prefs.remove(_keyClientUrl);
    await prefs.remove(_keyClientDb);
    notifyListeners();
  }
}
