import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import 'omni_mobile_api.dart';
import 'session_service.dart';

/// On-device face verification.
///
/// The reference (enrolled) face is fetched from Odoo once and cached
/// locally as a JPEG so verification can run without network. Live
/// selfies captured at check-in/out are compared against this cached
/// reference.
///
/// TODO: replace simulate path with a real on-device face matching /
/// liveness SDK. While `DevConstants.simulateFaceRecognition` is
/// true, `verifyFace` returns success after a brief delay and the UI
/// MUST display a "DEV MODE: face recognition simulated" banner —
/// never silently fake this in production.
class FaceRecognitionService extends ChangeNotifier {
  static const _cachedFilename = 'enrolled_face.jpg';

  bool? _enrolled;
  String? _localFacePath;
  bool _loading = false;

  /// True if we know there's an enrolled face server-side. null until
  /// `refreshEnrolledStatus` runs at least once.
  bool? get isEnrolled => _enrolled;
  String? get localFacePath => _localFacePath;
  bool get loading => _loading;
  bool get isSimulated => DevConstants.simulateFaceRecognition;

  Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cachedFilename');
  }

  /// Fetch enrollment state from the server. Caches the bytes locally
  /// when an image is present. Safe to call repeatedly.
  Future<void> refreshEnrolledStatus(SessionService session) async {
    if (_loading || !session.isLoggedIn) return;
    _loading = true;
    try {
      final api = _api(session);
      final res = await api.getEnrolledFace();
      final faceB64 = (res['face_image_base64'] ?? '').toString();
      if (faceB64.isNotEmpty) {
        final bytes = base64Decode(faceB64);
        final file = await _cacheFile();
        await file.writeAsBytes(bytes, flush: true);
        _localFacePath = file.path;
        _enrolled = true;
      } else {
        await _wipeLocalCache();
        _enrolled = false;
      }
      notifyListeners();
    } catch (_) {
      // Leave previous state; UI can still try verify against cache.
    } finally {
      _loading = false;
    }
  }

  /// Upload a captured selfie to Odoo as the enrolled reference.
  /// Caches it locally on success.
  Future<void> enrollFace(SessionService session, String imagePath) async {
    final api = _api(session);
    final bytes = await File(imagePath).readAsBytes();
    final b64 = base64Encode(bytes);
    final filename = imagePath.split('/').last;
    await api.enrollFace(faceImageBase64: b64, filename: filename);
    final file = await _cacheFile();
    await file.writeAsBytes(bytes, flush: true);
    _localFacePath = file.path;
    _enrolled = true;
    notifyListeners();
  }

  /// Wipe both server and local copies.
  Future<void> clearEnrolledFace(SessionService session) async {
    final api = _api(session);
    await api.clearEnrolledFace();
    await _wipeLocalCache();
    _enrolled = false;
    notifyListeners();
  }

  /// Wipe only the local cache (server enrollment stays intact). Used
  /// from the Profile screen "Clear local face cache" action.
  Future<void> clearLocalCache() async {
    await _wipeLocalCache();
    notifyListeners();
  }

  Future<void> _wipeLocalCache() async {
    try {
      final file = await _cacheFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
    _localFacePath = null;
  }

  /// Compare a freshly-captured selfie against the enrolled reference.
  ///
  /// Returns a [FaceVerifyResult]:
  ///   - ok=true   when match passes the threshold (or simulate is on)
  ///   - ok=false  when verification can be performed but the faces
  ///               don't match
  ///   - ok=false + isError=true when something prevented verification
  ///               (no enrolled face, no SDK wired up, IO error, …)
  Future<FaceVerifyResult> verifyFace(String liveImagePath) async {
    if (_enrolled != true || _localFacePath == null) {
      return FaceVerifyResult.notEnrolled();
    }

    if (DevConstants.simulateFaceRecognition) {
      // Brief delay so the UI can show "verifying…" feedback.
      await Future.delayed(const Duration(milliseconds: 600));
      return FaceVerifyResult.success(score: 1.0, simulated: true);
    }

    // TODO: integrate real face matching/liveness SDK here.
    // Plug in the SDK's compare(referencePath, livePath) -> score
    // and threshold accordingly. Until then we explicitly fail
    // closed in production builds rather than silently passing.
    return FaceVerifyResult.error(
      'No face matching SDK is wired up. Disable simulateFaceRecognition '
      'only after the SDK integration is in place.',
    );
  }

  OmniMobileApi _api(SessionService s) => OmniMobileApi(
        baseUrl: s.clientUrl,
        db: s.clientDb,
        token: s.token,
      );
}

class FaceVerifyResult {
  final bool ok;
  final bool isError;
  final bool simulated;
  final double? score;
  final String? errorMessage;

  FaceVerifyResult({
    required this.ok,
    this.isError = false,
    this.simulated = false,
    this.score,
    this.errorMessage,
  });

  factory FaceVerifyResult.success({double? score, bool simulated = false}) =>
      FaceVerifyResult(ok: true, score: score, simulated: simulated);

  factory FaceVerifyResult.mismatch(double score) =>
      FaceVerifyResult(ok: false, score: score);

  factory FaceVerifyResult.notEnrolled() => FaceVerifyResult(
        ok: false,
        isError: true,
        errorMessage: 'No enrolled face yet. Enroll one in Profile.',
      );

  factory FaceVerifyResult.error(String message) => FaceVerifyResult(
        ok: false,
        isError: true,
        errorMessage: message,
      );
}
