import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/face_recognition_service.dart';
import '../../services/session_service.dart';
import '../company_code/company_code_screen.dart';
import '../face_scan/face_enrollment_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final face = context.watch<FaceRecognitionService>();
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
          const SizedBox(height: 16),
          _faceCard(context, face, session),
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

  Widget _faceCard(BuildContext context, FaceRecognitionService face,
      SessionService session) {
    final enrolled = face.isEnrolled == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  enrolled ? Icons.verified_user : Icons.face_retouching_off,
                  color: enrolled ? AppTheme.primary : AppTheme.outline,
                ),
                const SizedBox(width: 8),
                const Text('Face Enrollment',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              enrolled
                  ? 'Your face is enrolled. The mobile app verifies you on every check-in/out.'
                  : 'No face enrolled yet. Enroll one to enable face-verified attendance.',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.onSurfaceVariant),
            ),
            if (DevConstants.simulateFaceRecognition) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.developer_mode,
                      size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'DEV MODE: face recognition simulated',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: Icon(enrolled
                        ? Icons.refresh_rounded
                        : Icons.face_rounded),
                    label: Text(enrolled ? 'Re-enroll Face' : 'Enroll Face'),
                    onPressed: face.loading
                        ? null
                        : () async {
                            await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const FaceEnrollmentScreen(),
                              ),
                            );
                            if (context.mounted) {
                              await face.refreshEnrolledStatus(session);
                            }
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Clear local face cache'),
              onPressed: face.loading
                  ? null
                  : () async {
                      await face.clearLocalCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Local face cache cleared')),
                        );
                        await face.refreshEnrolledStatus(session);
                      }
                    },
            ),
          ],
        ),
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
