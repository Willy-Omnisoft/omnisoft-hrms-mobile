import 'package:geolocator/geolocator.dart';
import '../core/constants.dart';
import '../models/location_result.dart';

/// Location service for attendance.
///
/// In dev mode (`DevConstants.useDevLocation = true`) returns the
/// hard-coded fallback coords without touching the OS — handy for the
/// iOS simulator.
///
/// In production it requests permission, handles all denied/blocked
/// states explicitly, and times out if it can't get a fix.
class LocationService {
  static const _timeout = Duration(seconds: 12);

  /// One-shot location request. Resolves to a LocationResult — never
  /// throws. The caller inspects `status` and `friendlyMessage`.
  Future<LocationResult> getCurrent() async {
    if (DevConstants.useDevLocation) {
      return LocationResult.ready(
        latitude: DevConstants.fallbackLatitude,
        longitude: DevConstants.fallbackLongitude,
        accuracy: 5.0,
        isDevFallback: true,
      );
    }

    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        return LocationResult.failure(
          LocationStatus.serviceDisabled,
          'Location services are off on this device.',
        );
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        return LocationResult.failure(
          LocationStatus.permissionDenied,
          'Location permission was denied.',
        );
      }
      if (perm == LocationPermission.deniedForever) {
        return LocationResult.failure(
          LocationStatus.permissionDeniedForever,
          'Location permission was permanently denied.',
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _timeout,
        ),
      );
      return LocationResult.ready(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
      );
    } on TimeoutException catch (_) {
      return LocationResult.failure(
        LocationStatus.timedOut,
        'Location request timed out.',
      );
    } catch (e) {
      return LocationResult.failure(LocationStatus.unknown, e.toString());
    }
  }
}

class TimeoutException implements Exception {}
