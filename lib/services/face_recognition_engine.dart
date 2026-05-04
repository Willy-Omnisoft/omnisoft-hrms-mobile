import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
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
  static const _modelAsset = 'assets/models/mobilefacenet.tflite';
  static const _modelInputSize = 112;

  late FaceDetector _detector;
  Interpreter? _embedder;
  bool _initialized = false;
  bool _embedderTried = false; // avoid spamming load attempts

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

  /// Lazily load the embedding model. Returns null when missing — the
  /// caller fails closed cleanly, no crash.
  Future<Interpreter?> _ensureEmbedder() async {
    if (_embedder != null) return _embedder;
    if (_embedderTried) return null;
    _embedderTried = true;
    try {
      _embedder = await Interpreter.fromAsset(_modelAsset);
      final inShape = _embedder!.getInputTensor(0).shape;
      final outShape = _embedder!.getOutputTensor(0).shape;
      debugPrint(
          'MobileFaceNet loaded — input=$inShape output=$outShape');
      return _embedder;
    } catch (e) {
      debugPrint(
          'MobileFaceNet model not found at $_modelAsset (or load '
          'failed): $e — falling back to fail-closed identity match');
      return null;
    }
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
      debugPrint('ML Kit faces=0 result=noFace');
      return FaceQualityResult.fail(FaceQualityIssue.noFace);
    }
    if (faces.length > 1) {
      debugPrint(
          'ML Kit faces=${faces.length} result=multipleFaces');
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
        debugPrint(
            'ML Kit faces=1 box=${boxFraction.toStringAsFixed(2)} '
            'result=faceTooSmall');
        return FaceQualityResult.fail(FaceQualityIssue.faceTooSmall);
      }
    }

    final leftOpen = face.leftEyeOpenProbability;
    final rightOpen = face.rightEyeOpenProbability;
    if (leftOpen != null && rightOpen != null) {
      // Average eye-open probability — more robust than AND/OR since
      // both eyes are usually affected similarly by squint / lashes.
      // <0.5 means "more likely closed than open".
      final avgOpen = (leftOpen + rightOpen) / 2.0;
      if (avgOpen < 0.5) {
        debugPrint(
          'ML Kit faces=1 box=${boxFraction?.toStringAsFixed(2)} '
          'leftEye=${leftOpen.toStringAsFixed(2)} '
          'rightEye=${rightOpen.toStringAsFixed(2)} result=eyesClosed',
        );
        return FaceQualityResult.fail(FaceQualityIssue.eyesClosed);
      }
    }

    debugPrint(
      'ML Kit faces=1 box=${boxFraction?.toStringAsFixed(2)} '
      'leftEye=${leftOpen?.toStringAsFixed(2) ?? "null"} '
      'rightEye=${rightOpen?.toStringAsFixed(2) ?? "null"} result=ok',
    );
    return FaceQualityResult.ok(
      boxFraction: boxFraction,
      leftEye: leftOpen,
      rightEye: rightOpen,
    );
  }

  @override
  Future<List<double>?> extractEmbedding(String imagePath) async {
    await initialize();
    final embedder = await _ensureEmbedder();
    if (embedder == null) return null;

    // Detect the face so we can crop tightly. Embedding quality
    // collapses if we feed the whole frame (background dominates).
    final input = InputImage.fromFilePath(imagePath);
    final faces = await _detector.processImage(input);
    if (faces.length != 1) return null;

    final raw = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(raw);
    if (decoded == null) return null;

    // ML Kit's bounding box is in the original image's coordinate
    // space. Inflate by 20% so we keep some hair / chin context
    // (face-recognition models like MobileFaceNet are trained on
    // slightly-padded crops, not tight chin-to-eyebrow boxes).
    final box = faces.first.boundingBox;
    final pad = 0.2;
    final cx = box.center.dx;
    final cy = box.center.dy;
    final half = math.max(box.width, box.height) * (0.5 + pad);
    final x = (cx - half).round().clamp(0, decoded.width - 1);
    final y = (cy - half).round().clamp(0, decoded.height - 1);
    final w = (half * 2).round().clamp(1, decoded.width - x);
    final h = (half * 2).round().clamp(1, decoded.height - y);

    final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    final resized = img.copyResize(cropped,
        width: _modelInputSize, height: _modelInputSize);

    // Build [1, 112, 112, 3] float32 tensor with [-1, 1] normalization.
    final inTensor = List.generate(
      1,
      (_) => List.generate(
        _modelInputSize,
        (yy) => List.generate(
          _modelInputSize,
          (xx) {
            final p = resized.getPixel(xx, yy);
            return [
              (p.r - 127.5) / 128.0,
              (p.g - 127.5) / 128.0,
              (p.b - 127.5) / 128.0,
            ];
          },
        ),
      ),
    );

    // Output shape varies by model variant (128/192/512). Read it
    // from the loaded interpreter rather than hard-coding.
    final outShape = embedder.getOutputTensor(0).shape;
    final outDim = outShape.reduce((a, b) => a * b);
    final outTensor = List.generate(
      outShape[0],
      (_) => List.filled(outDim ~/ outShape[0], 0.0),
    );

    embedder.run(inTensor, outTensor);

    // L2-normalize so cosine similarity is just a dot product.
    final flat = (outTensor[0] as List).cast<double>();
    final norm = math.sqrt(flat.fold<double>(0, (s, v) => s + v * v));
    if (norm == 0) return null;
    return flat.map((v) => v / norm).toList(growable: false);
  }

  @override
  Future<FaceCompareResult> compare(
    String enrolledImagePath,
    String liveImagePath,
  ) async {
    final enrolled = await extractEmbedding(enrolledImagePath);
    if (enrolled == null) {
      // Either the model is missing or the enrolled image no longer
      // contains a recognisable face. Fail closed.
      return FaceCompareResult.notImplemented();
    }
    final live = await extractEmbedding(liveImagePath);
    if (live == null) {
      // Live image has no face / multiple faces — quality gate
      // should have caught this, but be defensive.
      return FaceCompareResult.mismatch(0.0);
    }

    // Cosine similarity = dot product on unit vectors.
    var dot = 0.0;
    for (var i = 0; i < enrolled.length && i < live.length; i++) {
      dot += enrolled[i] * live[i];
    }
    final score = dot.clamp(-1.0, 1.0);
    debugPrint('MobileFaceNet cosine=${score.toStringAsFixed(3)} '
        'threshold=${DevConstants.faceMatchThreshold}');
    if (score >= DevConstants.faceMatchThreshold) {
      return FaceCompareResult.match(score);
    }
    return FaceCompareResult.mismatch(score);
  }

  @override
  Future<void> dispose() async {
    if (_initialized) {
      await _detector.close();
      _initialized = false;
    }
    _embedder?.close();
    _embedder = null;
    _embedderTried = false;
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
