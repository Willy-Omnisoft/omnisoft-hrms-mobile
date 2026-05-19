import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import 'file_viewer.dart';

class PickedDocument {
  final String name;
  final String mimetype;
  final String dataB64;
  final int size;

  PickedDocument({
    required this.name,
    required this.mimetype,
    required this.dataB64,
    required this.size,
  });

  Map<String, dynamic> toApiJson() => {
        'name': name,
        'mimetype': mimetype,
        'data_b64': dataB64,
      };

  String get sizeLabel {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class DocumentPickerField extends StatelessWidget {
  final PickedDocument? picked;
  final bool required;
  final ValueChanged<PickedDocument?> onChanged;

  const DocumentPickerField({
    super.key,
    required this.picked,
    required this.onChanged,
    this.required = false,
  });

  /// Camera primary path — for paper docs the user wants to snap
  /// right now (handwritten letters, clinic stamps, etc).
  Future<void> _pickFromCamera(BuildContext context) async {
    try {
      final xfile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // ~200-500KB jpegs; same as expense receipts
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final ext = xfile.name.contains('.')
          ? xfile.name.split('.').last
          : 'jpg';
      onChanged(PickedDocument(
        name: xfile.name,
        mimetype: _guessMimetype(ext),
        dataB64: base64Encode(bytes),
        size: bytes.length,
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not capture photo: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  /// Files fallback — for medical PDFs, scanned certs already on
  /// disk, library photos (iOS Files → Photos), anything non-camera.
  Future<void> _pickFromFiles(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.single;
      if (f.bytes == null && f.path == null) return;
      final bytes = f.bytes ?? await File(f.path!).readAsBytes();
      onChanged(PickedDocument(
        name: f.name,
        mimetype: _guessMimetype(f.extension),
        dataB64: base64Encode(bytes),
        size: bytes.length,
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick file: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  String _guessMimetype(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (picked == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _pickFromCamera(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: required ? AppTheme.error : AppTheme.outline,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.camera_alt_rounded,
                      size: 18,
                      color:
                          required ? AppTheme.error : AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          required
                              ? 'Supporting document required'
                              : 'Capture supporting document',
                          style: TextStyle(
                            fontSize: 12,
                            color: required
                                ? AppTheme.error
                                : AppTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Tap to take a photo',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppTheme.outline),
                ],
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => _pickFromFiles(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'or pick from files',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      );
    }
    final p = picked!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.primary),
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 20, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(p.sizeLabel,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View',
            icon: Icon(Icons.visibility_outlined, color: AppTheme.primary),
            onPressed: () async {
              final err = await openBase64File(
                  name: p.name, dataB64: p.dataB64);
              if (err != null && context.mounted) {
                showFileViewError(context, err);
              }
            },
          ),
          IconButton(
            tooltip: 'Replace',
            icon: Icon(Icons.refresh_rounded, color: AppTheme.primary),
            onPressed: () => _pickFromCamera(context),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: Icon(Icons.close_rounded, color: AppTheme.error),
            onPressed: () => onChanged(null),
          ),
        ],
      ),
    );
  }
}
