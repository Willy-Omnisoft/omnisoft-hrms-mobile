import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/datetime_utils.dart';
import '../../core/theme.dart';
import '../../models/attendance_status.dart';
import '../../models/face_capture_result.dart';
import '../../services/device_service.dart';
import '../../services/face_recognition_service.dart';
import '../../services/location_service.dart';
import '../../services/omni_mobile_api.dart';
import '../../services/session_service.dart';
import '../face_scan/face_capture_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  AttendanceStatus? _status;
  bool _loading = true;
  String? _error;
  bool _acting = false;
  String _gpsHint = '';
  // Last outside-geofence error info — kept on screen until the next
  // successful check-in/out. null when not applicable.
  double? _lastDistance;
  double? _lastAllowedRadius;
  final _locationService = LocationService();
  final _deviceService = DeviceService();

  OmniMobileApi _api(SessionService s) => OmniMobileApi(
        baseUrl: s.clientUrl,
        db: s.clientDb,
        token: s.token,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  Future<void> refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = context.read<SessionService>();
      final status = await _api(session).getAttendanceStatus();
      if (mounted) setState(() => _status = status);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onCheckAction() async {
    if (_acting) return;
    setState(() {
      _acting = true;
      _gpsHint = 'Locating…';
    });

    // Step 1 — GPS
    final loc = await _locationService.getCurrent();
    if (!mounted) return;
    if (!loc.isReady) {
      setState(() {
        _acting = false;
        _gpsHint = 'GPS failed';
      });
      _showError(loc.friendlyMessage);
      return;
    }
    setState(() => _gpsHint = loc.isDevFallback ? 'DEV location' : 'GPS ready');

    // Step 2 — Face capture + on-device verification against the
    // employee's enrolled face. We only forward face_verified=true to
    // the server when verification actually passes.
    final faceSvc = context.read<FaceRecognitionService>();
    if (faceSvc.isEnrolled != true) {
      // Make sure status is fresh — they may have enrolled in another
      // session since the app was last opened.
      await faceSvc.refreshEnrolledStatus(context.read<SessionService>());
    }
    if (!mounted) return;
    if (faceSvc.isEnrolled != true) {
      setState(() => _acting = false);
      _showError(
          'No enrolled face. Open Profile → Enroll Face before checking in.');
      return;
    }

    final faceResult = await Navigator.of(context).push<FaceCaptureResult>(
      MaterialPageRoute(builder: (_) => const FaceCaptureScreen()),
    );
    if (!mounted) return;
    if (faceResult == null || !faceResult.success) {
      setState(() => _acting = false);
      if (faceResult?.errorMessage != null) {
        _showError(faceResult!.errorMessage!);
      }
      return;
    }

    final verify = await faceSvc.verifyFace(faceResult.imagePath!);
    if (!mounted) return;
    if (!verify.ok) {
      setState(() => _acting = false);
      _showError(verify.errorMessage ??
          'Face not recognized. Please try again.');
      return;
    }

    // Step 3 — submit attendance
    try {
      final session = context.read<SessionService>();
      final api = _api(session);
      final deviceId = await _deviceService.getDeviceId();
      final wasCheckedIn = _status?.checkedIn == true;

      if (wasCheckedIn) {
        await api.checkOut(
          latitude: loc.latitude!,
          longitude: loc.longitude!,
          faceVerified: faceResult.faceVerified,
          deviceId: deviceId,
          devLocation: DevConstants.useDevLocation,
        );
      } else {
        await api.checkIn(
          latitude: loc.latitude!,
          longitude: loc.longitude!,
          faceVerified: faceResult.faceVerified,
          deviceId: deviceId,
          devLocation: DevConstants.useDevLocation,
        );
      }

      await refresh();
      if (mounted) {
        setState(() {
          _lastDistance = null;
          _lastAllowedRadius = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasCheckedIn
                ? 'Checked out successfully!'
                : 'Checked in successfully!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (e is ApiException && e.errorCode == 'outside_geofence') {
          setState(() {
            _lastDistance = e.distanceFromOffice;
            _lastAllowedRadius = e.allowedRadius;
          });
        }
        _showError(_humanizeApiError(e));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  String _humanizeApiError(Object e) {
    final raw = e.toString();
    if (raw.contains('office_geofence_not_configured')) {
      return 'No office location is set for your employee. Ask HR to configure the work address.';
    }
    if (raw.contains('outside_geofence')) {
      return 'You are outside the allowed office location.';
    }
    if (raw.contains('face_not_verified')) {
      return 'Face verification failed. Please try again.';
    }
    if (raw.contains('mobile_not_enabled')) {
      return 'Mobile attendance is not enabled for your employee profile.';
    }
    if (raw.contains('already_checked_in')) {
      return 'You are already checked in.';
    }
    if (raw.contains('not_checked_in')) {
      return 'You are not currently checked in.';
    }
    if (raw.contains('invalid_token')) {
      return 'Your session expired. Please login again.';
    }
    return raw.replaceFirst(RegExp(r'^Exception: '), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _buildError()
            else
              _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: refresh, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final s = _status!;
    final checkedIn = s.checkedIn;
    return Column(
      children: [
        // Status card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  checkedIn
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 48,
                  color: checkedIn ? AppTheme.primary : AppTheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  checkedIn ? 'Checked In' : 'Not Checked In',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: checkedIn ? AppTheme.primary : AppTheme.outline,
                      ),
                ),
                if (s.currentCheckInTime != null) ...[
                  const SizedBox(height: 4),
                  Text('Since ${DateTimeUtils.formatLocalTime(s.currentCheckInTime!)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statChip(
                        'Hours Today', s.hoursToday.toStringAsFixed(1)),
                    if (s.lastCheckInTime != null)
                      _statChip(
                          'Last Check-in', DateTimeUtils.formatLocalTime(s.lastCheckInTime!)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Big action button
        SizedBox(
          width: 200,
          height: 200,
          child: ElevatedButton(
            onPressed: _acting ? null : _onCheckAction,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor:
                  checkedIn ? AppTheme.secondary : AppTheme.primary,
              padding: EdgeInsets.zero,
            ),
            child: _acting
                ? const CircularProgressIndicator(color: Colors.white)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        checkedIn ? Icons.logout_rounded : Icons.login_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        checkedIn ? 'Check Out' : 'Check In',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        _gpsIndicator(),
        if (DevConstants.simulateFaceRecognition) ...[
          const SizedBox(height: 8),
          _faceSimBanner(),
        ],
        if (_lastDistance != null && _lastAllowedRadius != null) ...[
          const SizedBox(height: 12),
          _geofenceInfoCard(),
        ],
      ],
    );
  }

  Widget _faceSimBanner() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.developer_mode, size: 14, color: Colors.orange),
        const SizedBox(width: 4),
        Text('DEV MODE: face recognition simulated',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                )),
      ],
    );
  }

  Widget _geofenceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_off, size: 18, color: AppTheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outside office geofence',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.error),
                ),
                const SizedBox(height: 4),
                Text(
                  'Distance: ${_lastDistance!.toStringAsFixed(0)} m  ·  '
                  'Allowed: ${_lastAllowedRadius!.toStringAsFixed(0)} m',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gpsIndicator() {
    final isDev = DevConstants.useDevLocation;
    final label = _gpsHint.isNotEmpty
        ? _gpsHint
        : (isDev ? 'DEV location active' : 'GPS Ready');
    final color = isDev
        ? Colors.orange
        : (_gpsHint == 'GPS failed' ? AppTheme.error : AppTheme.outline);
    final icon = isDev
        ? Icons.developer_mode
        : (_gpsHint == 'GPS failed'
            ? Icons.gps_off
            : (_gpsHint == 'Locating…'
                ? Icons.gps_not_fixed
                : Icons.gps_fixed));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }

  Widget _statChip(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

}
