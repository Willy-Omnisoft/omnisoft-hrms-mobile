/// Result of the face capture flow.
///
/// faceVerified currently means "selfie was captured successfully" —
/// it does NOT yet mean a real face match has been performed.
///
/// TODO: replace with real face matching/liveness SDK. When that
/// happens, faceVerified should reflect actual match against the
/// employee's enrolled template.
class FaceCaptureResult {
  final bool success;
  final bool faceVerified;
  final String? imagePath;
  final String? errorMessage;

  FaceCaptureResult({
    required this.success,
    required this.faceVerified,
    this.imagePath,
    this.errorMessage,
  });

  factory FaceCaptureResult.success(String imagePath) => FaceCaptureResult(
        success: true,
        faceVerified: true,
        imagePath: imagePath,
      );

  factory FaceCaptureResult.cancelled() =>
      FaceCaptureResult(success: false, faceVerified: false);

  factory FaceCaptureResult.error(String message) => FaceCaptureResult(
        success: false,
        faceVerified: false,
        errorMessage: message,
      );
}
