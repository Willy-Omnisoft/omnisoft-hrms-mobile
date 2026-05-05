import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/device_service.dart';
import '../../services/omni_mobile_api.dart';
import '../../services/session_service.dart';
import '../home/home_shell.dart';

/// Email/password login. Reached after CompanyCodeScreen has resolved
/// the SaaS routing (clientUrl + clientDb). On success, calls
/// /api/v1/omni_mobile/login and persists the access token + user/
/// employee details to SessionService. The top-level Consumer in
/// OmniHrApp then renders HomeShell.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginController =
      TextEditingController(text: DevConstants.defaultLogin);
  final _passwordController = TextEditingController();
  final _deviceService = DeviceService();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final loginText = _loginController.text.trim();
    final password = _passwordController.text;
    if (loginText.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = context.read<SessionService>();
      final api = OmniMobileApi(
        baseUrl: session.clientUrl,
        db: session.clientDb,
        token: '', // login has no auth header
      );
      final deviceId = await _deviceService.getDeviceId();
      final res = await api.login(
        login: loginText,
        password: password,
        deviceId: deviceId,
        appVersion: AppConstants.appVersion,
      );
      final user = res['user'] as Map<String, dynamic>? ?? {};
      final employee = res['employee'] as Map<String, dynamic>? ?? {};
      final expiresAtStr = res['expires_at']?.toString() ?? '';
      await session.saveSession(
        accessToken: res['access_token']?.toString() ?? '',
        expiresAt: expiresAtStr.isNotEmpty
            ? DateTime.tryParse(expiresAtStr)
            : null,
        userId: (user['id'] as num?)?.toInt() ?? 0,
        userLogin: user['login']?.toString() ?? '',
        userName: user['name']?.toString() ?? '',
        employeeId: (employee['id'] as num?)?.toInt() ?? 0,
        employeeName: employee['name']?.toString() ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (_) => false,
      );
    } on ApiException catch (e) {
      setState(() => _error = _humanize(e));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _humanize(ApiException e) {
    switch (e.errorCode) {
      case 'invalid_credentials':
        return 'Invalid email or password.';
      case 'missing_credentials':
        return 'Enter your email and password.';
      case 'no_employee_linked':
        return 'No employee record is linked to that user.';
      case 'mobile_not_enabled':
        return 'Mobile access is not enabled for this employee. Ask HR to enable it.';
      case 'rate_limit_exceeded':
        return 'Too many login attempts. Try again in a few minutes.';
      default:
        return e.errorCode.isEmpty ? 'Login failed.' : e.errorCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Allow user to switch company code.
            Navigator.of(context).maybePop();
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.companyCode.isNotEmpty
                      ? '${session.companyCode}  ·  ${session.clientUrl}'
                      : '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _loginController,
                  decoration: const InputDecoration(
                    labelText: 'Email or login',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.password_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: AppTheme.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                                color: AppTheme.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _login,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
