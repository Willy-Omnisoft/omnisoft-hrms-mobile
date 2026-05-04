import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/datetime_utils.dart';
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
    final canReenroll = face.isReenrollAllowed;

    // Tri-state for the body of the card:
    //   not enrolled                 → "Enroll Face"
    //   enrolled + !canReenroll      → locked, must contact HR
    //   enrolled + canReenroll       → "Re-enroll Face" + warning
    Widget statusText;
    Widget? primaryAction;
    if (!enrolled) {
      statusText = Text(
        'No face enrolled yet. Enroll one to enable face-verified attendance.',
        style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
      );
      primaryAction = FilledButton.icon(
        icon: const Icon(Icons.face_rounded),
        label: const Text('Enroll Face'),
        onPressed: face.loading
            ? null
            : () => _openEnroll(context, face, session),
      );
    } else if (!canReenroll) {
      statusText = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Face already enrolled. Contact HR to reset face enrollment.',
            style:
                TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
          ),
          if (face.lastEnrolledAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Enrolled on '
              '${DateTimeUtils.formatLocalDate(face.lastEnrolledAt!.toIso8601String())}.',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.onSurfaceVariant),
            ),
          ],
        ],
      );
      primaryAction = FilledButton.icon(
        icon: const Icon(Icons.lock_rounded),
        label: const Text('Re-enroll Face'),
        onPressed: null, // disabled
      );
    } else {
      statusText = Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_open_rounded,
                size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'HR has allowed face re-enrollment. This will replace your current enrolled face.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
      primaryAction = FilledButton.icon(
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Re-enroll Face'),
        onPressed: face.loading
            ? null
            : () => _openEnroll(context, face, session),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  enrolled
                      ? Icons.verified_user
                      : Icons.face_retouching_off,
                  color: enrolled ? AppTheme.primary : AppTheme.outline,
                ),
                const SizedBox(width: 8),
                const Text('Face Enrollment',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (enrolled)
                  Icon(
                    canReenroll
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded,
                    size: 16,
                    color: canReenroll
                        ? AppTheme.primary
                        : AppTheme.onSurfaceVariant,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            statusText,
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
            SizedBox(width: double.infinity, child: primaryAction),
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

  Future<void> _openEnroll(BuildContext context,
      FaceRecognitionService face, SessionService session) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const FaceEnrollmentScreen(),
      ),
    );
    if (context.mounted) {
      await face.refreshEnrolledStatus(session);
    }
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
