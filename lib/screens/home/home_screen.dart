import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/attendance_status.dart';
import '../../services/omni_mobile_api.dart';
import '../../services/session_service.dart';
import '../face_scan/face_scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AttendanceStatus? _status;
  bool _loading = true;
  String? _error;
  bool _acting = false;

  OmniMobileApi _api(SessionService s) => OmniMobileApi(
        baseUrl: s.clientUrl,
        db: s.clientDb,
        token: s.token,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
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

  Future<Position?> _getPosition() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }

  Future<void> _onCheckAction() async {
    // Navigate to face scan placeholder, then perform action
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FaceScanScreen()),
    );
    if (result != true || !mounted) return;

    setState(() => _acting = true);
    try {
      final session = context.read<SessionService>();
      final api = _api(session);
      double lat;
      double lng;
      if (DevConstants.useDevLocation) {
        lat = DevConstants.fallbackLatitude;
        lng = DevConstants.fallbackLongitude;
      } else {
        final pos = await _getPosition();
        lat = pos?.latitude ?? DevConstants.fallbackLatitude;
        lng = pos?.longitude ?? DevConstants.fallbackLongitude;
      }

      if (_status?.checkedIn == true) {
        await api.checkOut(
            latitude: lat, longitude: lng, deviceId: 'flutter-app');
      } else {
        await api.checkIn(
            latitude: lat, longitude: lng, deviceId: 'flutter-app');
      }
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_status?.checkedIn == true
                ? 'Checked in successfully!'
                : 'Checked out successfully!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: RefreshIndicator(
        onRefresh: _refresh,
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
            ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
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
                  Text('Since ${_formatTime(s.currentCheckInTime!)}',
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
                          'Last Check-in', _formatTime(s.lastCheckInTime!)),
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
        // GPS indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              DevConstants.useDevLocation
                  ? Icons.developer_mode
                  : Icons.gps_fixed,
              size: 16,
              color: DevConstants.useDevLocation
                  ? Colors.orange
                  : AppTheme.outline,
            ),
            const SizedBox(width: 4),
            Text(
              DevConstants.useDevLocation
                  ? 'DEV location active'
                  : 'GPS Ready',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DevConstants.useDevLocation
                        ? Colors.orange
                        : AppTheme.outline,
                  ),
            ),
          ],
        ),
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

  String _formatTime(String dt) {
    try {
      final parsed = DateTime.parse(dt);
      final local = parsed.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dt;
    }
  }
}
