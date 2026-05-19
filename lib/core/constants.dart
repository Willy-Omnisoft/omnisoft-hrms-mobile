import 'package:package_info_plus/package_info_plus.dart';

/// DEV ONLY — default values for local development.
/// These will be removed or hidden behind a build flag before release.
class DevConstants {
  static const String defaultCompanyCode = 'DEMO';
  // Override at run time:
  //   flutter run --dart-define=SAAS_URL=http://192.168.1.17:8069
  // Default is localhost so iOS simulator + macOS desktop builds keep working.
  static const String defaultSaasUrl = String.fromEnvironment(
    'SAAS_URL',
    defaultValue: 'http://192.168.1.17:8069',
  );
  /// Pre-fill on the login screen so devs don't have to retype each
  /// hot-restart. Empty in production builds is fine.
  static const String defaultLogin = 'test@demo.com';

  static const double fallbackLatitude = 1.2780;
  static const double fallbackLongitude = 103.8450;

  /// DEV ONLY — when true, always use fallback coordinates
  /// instead of real GPS. Set to false for production builds.
  static const bool useDevLocation = false;

  /// DEV ONLY — when false, the receipt attachment requirement on
  /// expense submission is bypassed: the form marks the receipt as
  /// optional, the Submit button enables without a photo, and the
  /// connector accepts the request via the `_dev_skip_receipt: true`
  /// body flag. Same posture as useDevLocation. Set back to true for
  /// production builds.
  static const bool requireReceiptOnExpense = true;

  /// When true, the expense create screen exposes a "Scan receipt"
  /// button (Qwen2.5-VL via self-hosted Ollama on the LAN). Set to
  /// false to hide the button if the OCR backend is unavailable.
  static const bool enableOcrScan = true;

  /// When true, FaceRecognitionService.verifyFace returns success after
  /// a brief delay instead of running real on-device identity matching.
  /// The UI surfaces a "DEV MODE: face recognition simulated" banner
  /// whenever this is on, so we never silently fake production logic.
  ///
  /// Now FALSE: a real face-embedding model is bundled at
  /// assets/models/mobilefacenet.tflite. The engine auto-detects whether
  /// it's MobileFaceNet (112x112, [-1,1] norm) or FaceNet (160x160, per-
  /// image standardization) from the loaded input shape.
  static const bool simulateFaceRecognition = false;

  /// Cosine-similarity threshold for treating two face embeddings as
  /// the same person. Sensible defaults for MobileFaceNet sit
  /// between 0.65 and 0.75; tune once a real embedding model is wired
  /// up. Has no effect while a real embedding engine isn't loaded.
  static const double faceMatchThreshold = 0.70;

  /// Minimum side length (px) of the detected face's bounding box,
  /// relative to the shorter side of the captured image. Rejects
  /// selfies where the face is too small / far for a confident match.
  static const double faceMinSizeFraction = 0.20;
}

class AppConstants {
  static const String appName = 'Omni HR';
  static const String apiVersion = 'v1';

  /// Live app version, populated at startup from pubspec.yaml via
  /// package_info_plus. pubspec.yaml is the single source of truth —
  /// DO NOT hardcode here.
  static String _appVersion = '0.0.0';
  static String get appVersion => _appVersion;

  /// Call once from main() before runApp(). Reads the version baked
  /// into the build at compile-time, so subsequent reads are instant
  /// and synchronous.
  static Future<void> initAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (_) {
      // Stay on the '0.0.0' sentinel — better than crashing startup
      // over a cosmetic field. The sentinel is recognisable in logs.
    }
  }
}
