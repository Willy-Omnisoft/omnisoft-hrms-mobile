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
  static const bool useDevLocation = false;

  /// DEV ONLY — when true, FaceRecognitionService.verifyFace returns
  /// success after a brief delay instead of running a real comparison.
  /// The UI surfaces a "DEV MODE: face recognition simulated" banner
  /// whenever this is on, so we never silently fake production logic.
  ///
  /// TODO: replace with real on-device face matching/liveness SDK.
  static const bool simulateFaceRecognition = true;

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
  static const String appVersion = '1.0.0';
  static const String apiVersion = 'v1';
}
