import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/session_service.dart';
import '../company_code/company_code_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(context, 'Company Code', session.companyCode),
                  const Divider(height: 24),
                  _row(context, 'Client URL', session.clientUrl),
                  const Divider(height: 24),
                  _row(context, 'Database', session.clientDb),
                  const Divider(height: 24),
                  _row(
                    context,
                    'Token',
                    session.token.isNotEmpty
                        ? '${session.token.substring(0, 8)}...'
                        : '—',
                  ),
                  const Divider(height: 24),
                  _row(context, 'App Version', AppConstants.appVersion),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            onPressed: () async {
              await session.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const CompanyCodeScreen()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.onSurfaceVariant, fontSize: 14)),
        Flexible(
          child: Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
