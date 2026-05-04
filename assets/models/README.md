# On-device face recognition model

The Flutter app expects a MobileFaceNet TFLite model at:

    assets/models/mobilefacenet.tflite

## Required model spec

- Architecture: MobileFaceNet (or any 112×112 face embedding model)
- Input shape:  `[1, 112, 112, 3]`, RGB, float32
- Input range:  pixels normalized to `[-1, 1]` via `(p - 127.5) / 128`
- Output shape: `[1, N]` where N is 128, 192, or 512 (typical for
  MobileFaceNet variants)
- Output:       face embedding (will be L2-normalized after inference)

## Where to get one

Several open-source MobileFaceNet TFLite models are available. Pick
one whose license matches your needs and **review the training data**
(many face-recognition models are trained on MS-Celeb-1M which has
licensing concerns).

Examples (verify each license yourself):
- https://github.com/estebanuri/face_recognition (Apache 2.0)
- https://github.com/sirius-ai/MobileFaceNet_TF
- https://github.com/MX1A8/Face_Recognition_Flutter

## After dropping the .tflite here

1. Run `flutter pub get`.
2. Flip `DevConstants.simulateFaceRecognition` to `false` in
   `lib/core/constants.dart`.
3. Hot-restart (or full rebuild on Android — the model is bundled at
   install time).
4. Re-enroll your face in the Profile tab so the enrolled embedding
   is regenerated against the new model.

## If the model file is missing

The engine logs `MobileFaceNet model not found` on first use and
falls through to fail-closed identity matching. Quality gates (no
face / multiple faces / etc) keep working regardless.
