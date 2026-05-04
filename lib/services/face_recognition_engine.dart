import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../core/constants.dart';

// =====================================================================
// Engine interface
// =====================================================================

/// Pluggable on-device face engine. Two implementations live below:
///
///   SimulatedFaceRecognitionEngine — dev-only, always-passes path
///       behind DevConstants.simulateFaceRecognition. Quality checks
///       still run so the user sees real "no face / multiple faces"
///       errors during development.
///
///   MLKitFaceRecognitionEngine — production scaffold.
///       Quality (face count, size, eyes-open) uses Google ML Kit
///       Face Detection — REAL on-device, no licensing concerns.
///       Identity matching (extractEmbedding / compare) is intentionally
///       NOT IMPLEMENTED here: ML Kit detects faces but does not produce
///       embeddings. A separate task adds a TFLite face embedding model
///       (e.g. MobileFaceNet) plus the alignment preprocessing pipeline.
///       Until then, compare() returns implemented=false and the service
///       layer fails closed in production.
///
/// Why ML Kit alone isn't recognition:
///   ML Kit Face Detection returns bounding boxes + landmarks +
///   classifications (smiling probability, eye-open probability). It
///   does NOT return a person identity vector. Two photos of two
///   different people both produce a "face detected" — that is not
///   matching. We use ML Kit only for quality gating.
abstract class FaceRecognitionEngine {
  String get name;
  bool get isProduction;

  Future<void> initialize();

  /// Quality validation only. Real on whatever engine is active.
  Future<FaceQualityResult> checkQuality(String imagePath);

  /// Returns a unit-length embedding vector for the face in [imagePath],
  /// or null when the engine doesn't implement embeddings yet.
  Future<List<double>?> extractEmbedding(String imagePath);

  /// Compare two face images. Returns implemented=false when the
  /// engine does not yet do identity matching.
  Future<FaceCompareResult> compare(
    String enrolledImagePath,
    String liveImagePath,
  );

  Future<void> dispose();
}

// =====================================================================
// Result types
// =====================================================================

enum FaceQualityIssue {
  noFace,
  multipleFaces,
  faceTooSmall,
  eyesClosed,
  imageReadFailed,
}

class FaceQualityResult {
  final bool ok;
  final FaceQualityIssue? issue;
  final double? boundingBoxFraction;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;

  FaceQualityResult({
    required this.ok,
    this.issue,
    this.boundingBoxFraction,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
  });

  factory FaceQualityResult.ok({
    double? boxFraction,
    double? leftEye,
    double? rightEye,
  }) =>
      FaceQualityResult(
        ok: true,
        boundingBoxFraction: boxFraction,
        leftEyeOpenProbability: leftEye,
        rightEyeOpenProbability: rightEye,
      );

  factory FaceQualityResult.fail(FaceQualityIssue issue) =>
      FaceQualityResult(ok: false, issue: issue);

  String get friendlyMessage {
    switch (issue) {
      case FaceQualityIssue.noFace:
        return 'No face detected. Please retake.';
      case FaceQualityIssue.multipleFaces:
        return 'Multiple faces detected. Please retake alone.';
      case FaceQualityIssue.faceTooSmall:
        return 'Move closer to the camera.';
      case FaceQualityIssue.eyesClosed:
        return 'Please look at the camera with eyes open.';
      case FaceQualityIssue.imageReadFailed:
        return 'Could not read the captured image.';
      case null:
        return 'Quality check passed.';
    }
  }
}

class FaceCompareResult {
  /// True only when identity matching ran AND passed the threshold.
  final bool ok;

  /// False when the engine doesn't implement identity matching yet.
  /// In that case the service layer fails closed in production.
  final bool implemented;

  /// Cosine similarity in [0..1] when implemented. Higher = more
  /// similar. Compare against DevConstants.faceMatchThreshold.
  final double? score;

  /// Why compare failed — only set when ok=false. Passed back to UI.
  final String? reason;

  FaceCompareResult({
    required this.ok,
    required this.implemented,
    this.score,
    this.reason,
  });

  factory FaceCompareResult.match(double score) =>
      FaceCompareResult(ok: true, implemented: true, score: score);

  factory FaceCompareResult.mismatch(double score) => FaceCompareResult(
        ok: false,
        implemented: true,
        score: score,
        reason: 'Face not recognized. Please try again.',
      );

  factory FaceCompareResult.notImplemented() => FaceCompareResult(
        ok: false,
        implemented: false,
        reason:
            'On-device identity matching is not yet wired up. Disable '
            'simulateFaceRecognition only after the TFLite face '
            'embedding model is integrated.',
      );
}

// =====================================================================
// Simulated engine — dev-only
// =====================================================================

class SimulatedFaceRecognitionEngine implements FaceRecognitionEngine {
  @override
  String get name => 'simulated';
  @override
  bool get isProduction => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<FaceQualityResult> checkQuality(String imagePath) async {
    // Even in simulate mode we still want SOME sanity, so we read the
    // file and confirm it exists.
    final f = File(imagePath);
    if (!await f.exists()) {
      return FaceQualityResult.fail(FaceQualityIssue.imageReadFailed);
    }
    return FaceQualityResult.ok();
  }

  @override
  Future<List<double>?> extractEmbedding(String imagePath) async => null;

  @override
  Future<FaceCompareResult> compare(
    String enrolledImagePath,
    String liveImagePath,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return FaceCompareResult.match(1.0);
  }

  @override
  Future<void> dispose() async {}
}

// =====================================================================
// Production scaffold — ML Kit quality + fail-closed identity matching
// =====================================================================

class MLKitFaceRecognitionEngine implements FaceRecognitionEngine {
  late FaceDetector _detector;
  bool _initialized = false;

  @override
  String get name => 'mlkit_face_quality';
  @override
  bool get isProduction => true;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // smiling / eyes-open probabilities
        enableLandmarks: false,
        enableContours: false,
        enableTracking: false,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _initialized = true;
  }

  @override
  Future<FaceQualityResult> checkQuality(String imagePath) async {
    await initialize();
    final f = File(imagePath);
    if (!await f.exists()) {
      return FaceQualityResult.fail(FaceQualityIssue.imageReadFailed);
    }

    final input = InputImage.fromFilePath(imagePath);
    final faces = await _detector.processImage(input);

    if (faces.isEmpty) {
      return FaceQualityResult.fail(FaceQualityIssue.noFace);
    }
    if (faces.length > 1) {
      return FaceQualityResult.fail(FaceQualityIssue.multipleFaces);
    }

    final face = faces.first;
    // Bounding box width as a fraction of the image short side. We
    // don't have the image dimensions from ML Kit directly; pull them
    // from the file.
    final bytes = await f.readAsBytes();
    final shortSide = await _imageShortSide(bytes);
    double? boxFraction;
    if (shortSide != null && shortSide > 0) {
      final w = face.boundingBox.width.abs();
      boxFraction = w / shortSide;
      if (boxFraction < DevConstants.faceMinSizeFraction) {
        return FaceQualityResult.fail(FaceQualityIssue.faceTooSmall);
      }
    }

    final leftOpen = face.leftEyeOpenProbability;
    final rightOpen = face.rightEyeOpenProbability;
    if (leftOpen != null && rightOpen != null) {
      // Both probabilities below 0.4 → almost certainly closed.
      if (leftOpen < 0.4 && rightOpen < 0.4) {
        return FaceQualityResult.fail(FaceQualityIssue.eyesClosed);
      }
    }

    return FaceQualityResult.ok(
      boxFraction: boxFraction,
      leftEye: leftOpen,
      rightEye: rightOpen,
    );
  }

  @override
  Future<List<double>?> extractEmbedding(String imagePath) async {
    // TODO: integrate a TFLite face embedding model (e.g.
    // MobileFaceNet) and return a 128/192/512-d unit vector here.
    // Steps:
    //   1. Detect + crop the face region (ML Kit gives the box already).
    //   2. Resize to the model's input size (typically 112x112).
    //   3. Normalize (range [-1,1] for MobileFaceNet).
    //   4. Run TFLite inference, L2-normalize the output.
    return null;
  }

  @override
  Future<FaceCompareResult> compare(
    String enrolledImagePath,
    String liveImagePath,
  ) async {
    // Quality is verified separately by the service layer before
    // calling this. The actual identity match awaits TFLite
    // integration; until then we fail closed.
    return FaceCompareResult.notImplemented();
  }

  @override
  Future<void> dispose() async {
    if (_initialized) {
      await _detector.close();
      _initialized = false;
    }
  }
}

/// Best-effort decode the image's short side from raw bytes for
/// proportional bounding-box checks. Avoids pulling in a heavy image
/// decoding dep — relies on Flutter's built-in instantiateImageCodec.
Future<int?> _imageShortSide(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width;
    final h = frame.image.height;
    frame.image.dispose();
    return w < h ? w : h;
  } catch (_) {
    return null;
  }
}
