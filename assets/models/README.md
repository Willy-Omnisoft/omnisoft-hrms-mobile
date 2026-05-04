# On-device face recognition model

Place a TFLite face-embedding model at:

    assets/models/mobilefacenet.tflite

The filename is fixed (the engine looks for that exact path) but the
**model architecture is auto-detected**. Either of these works:

| Architecture | Input shape   | Normalization                  | Typical output |
|--------------|---------------|---------------------------------|----------------|
| MobileFaceNet| `[1,112,112,3]`| `(p - 127.5) / 128`            | 128 / 192 dim  |
| FaceNet      | `[1,160,160,3]`| Per-image standardization      | 128 / 512 dim  |

`MLKitFaceRecognitionEngine._ensureEmbedder` reads the input shape from
the loaded interpreter and picks the matching preprocessing.

## Currently shipped

A 44 MB FaceNet TFLite (input `[1,160,160,3]`, 128-d output, sourced
from `shubham0204/OnDevice-Face-Recognition-Android`, Apache-2.0
wrapper). Weights provenance: David Sandberg's FaceNet via deepface,
trained on CASIA-WebFace + VGGFace2.

## Licensing — read this before shipping commercial

The Apache-2.0 license on the wrapper repo covers code, not the
model weights. Every widely-available open face-embedding model has
training-data provenance issues (MS-Celeb-1M was retracted by
Microsoft in 2019; VGGFace2 / CASIA-WebFace are research-only by
their original terms). For internal employee attendance — where
subjects (employees) consent and faces aren't shared with third
parties — open weights are widely used. For customer-facing or
PII-sensitive deployments, switch to a commercial SDK (Megvii Face++,
Regula, Innovatrics, FaceTec) with cleanly-licensed weights.

## Threshold tuning

`DevConstants.faceMatchThreshold` controls the cosine-similarity
cutoff (default 0.70). Different models score on different scales:
- MobileFaceNet typically lands around 0.65–0.75 for the same person
- FaceNet 128-d typically lands around 0.75–0.85

If you swap the model, watch `flutter logs` during a few same-person
and different-person tests, then tune the threshold accordingly.

## To swap models later

1. Drop the new `.tflite` over `mobilefacenet.tflite` (keep the name).
2. `flutter clean && flutter pub get && flutter run -d c98c58ec`.
3. Re-enroll your face in Profile so the enrolled embedding is
   regenerated against the new model.

## If the model file is missing

The engine logs a clear "Face embedder model not found at
assets/models/mobilefacenet.tflite" message and `compare()` returns
`notImplemented` — service layer falls back to fail-closed identity
matching. Quality gates (no face / multiple faces / etc) keep
working regardless.
