import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/saas_service.dart';
import '../../services/session_service.dart';

/// Lets the user re-resolve the company (point at a different SaaS or
/// switch company codes) without going through the full
/// CompanyCodeScreen flow. Reached via the gear icon on LoginScreen.
class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  late final TextEditingController _saasUrlController;
  late final TextEditingController _codeController;
  late String _clientUrl;
  late String _clientDb;
  bool _resolving = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    final s = context.read<SessionService>();
    _saasUrlController = TextEditingController(text: s.saasUrl);
    _codeController = TextEditingController(text: s.companyCode);
    _clientUrl = s.clientUrl;
    _clientDb = s.clientDb;
  }

  @override
  void dispose() {
    _saasUrlController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final saasUrl = _saasUrlController.text.trim();
    final code = _codeController.text.trim();
    if (saasUrl.isEmpty || code.isEmpty) {
      setState(() => _error = 'Enter SaaS URL and Company Code.');
      return;
    }
    setState(() {
      _resolving = true;
      _error = null;
      _info = null;
    });
    try {
      final session = context.read<SessionService>();
      final priorClientUrl = session.clientUrl;
      final priorCompanyCode = session.companyCode;

      final saas = SaasService();
      final info = await saas.resolveCompany(saasUrl, code);

      // If company routing actually changed, drop the auth session —
      // a token issued by the old client db is meaningless on a new one.
      final changed = info.odooUrl != priorClientUrl ||
          info.companyCode != priorCompanyCode;
      await session.saveCompany(
        saasUrl: saasUrl,
        companyCode: info.companyCode,
        clientUrl: info.odooUrl,
        clientDb: info.database,
      );
      if (changed) {
        await session.clearSession();
      }

      if (!mounted) return;
      setState(() {
        _clientUrl = info.odooUrl;
        _clientDb = info.database;
        _info = changed
            ? 'Company updated. Sign in with the new company\'s credentials.'
            : 'Company refreshed.';
      });
      // Pop after a brief delay so the user sees the success state.
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _clearCompany() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear company?'),
        content: const Text(
          'This signs you out and removes the SaaS / company routing. '
          'You will be returned to the company code screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final session = context.read<SessionService>();
    await session.logout();
    // Top-level Consumer<SessionService> in main.dart will rebuild to
    // CompanyCodeScreen now that hasCompany is false. Just pop ourselves.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where the app talks to',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _saasUrlController,
                decoration: const InputDecoration(
                  labelText: 'SaaS URL',
                  prefixIcon: Icon(Icons.cloud_outlined),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Company Code',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 20),
              Text(
                'Resolved from SaaS',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              _readOnlyTile(
                  icon: Icons.public_rounded,
                  label: 'Client URL',
                  value: _clientUrl.isEmpty ? '—' : _clientUrl),
              const SizedBox(height: 8),
              _readOnlyTile(
                  icon: Icons.storage_outlined,
                  label: 'Database',
                  value: _clientDb.isEmpty ? '—' : _clientDb),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _banner(_error!, AppTheme.error, Icons.error_outline),
              ],
              if (_info != null) ...[
                const SizedBox(height: 16),
                _banner(_info!, AppTheme.primary, Icons.check_circle_outline),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _resolving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Resolve Company'),
                  onPressed: _resolving ? null : _resolve,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear Company'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: BorderSide(color: AppTheme.error),
                  ),
                  onPressed: _resolving ? null : _clearCompany,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readOnlyTile(
      {required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
