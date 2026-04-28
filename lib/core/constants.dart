/// DEV ONLY — default values for local development.
/// These will be removed or hidden behind a build flag before release.
class DevConstants {
  static const String defaultCompanyCode = 'DEMO';
  static const String defaultSaasUrl = 'http://localhost:8069';
  static const String defaultToken =
      'vTZnZiT7Dl0JBYNfwB8pV7oqqbS0gN73N3ZpiUs0nOk';
  static const double fallbackLatitude = 1.2780;
  static const double fallbackLongitude = 103.8450;

  /// DEV ONLY — when true, always use fallback coordinates
  /// instead of real GPS. Set to false for production builds.
  static const bool useDevLocation = true;
}

class AppConstants {
  static const String appName = 'Omni HR';
  static const String appVersion = '1.0.0';
  static const String apiVersion = 'v1';
}
