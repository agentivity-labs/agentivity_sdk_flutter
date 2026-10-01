import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/http_core.dart';

/// What the platform keeps of an uploaded file — the reference a workflow reads it back by.
class UploadedFile {
  const UploadedFile({required this.fileId, required this.name, required this.mimeType, required this.size});

  /// Opaque id; pass it to the workflow (a `document.extract_text` node reads the file from it).
  final String fileId;
  final String name;
  final String mimeType;
  final int size;
}

/// Hands a file to the platform for a run to read later (a CV, a contract…). The file is stored
/// server-side for a limited time and is never served back over HTTP — only the workflow that
/// receives the `fileId` can read it.
class UploadsApi {
  UploadsApi(this._c);
  final AgentivityHttpCore _c;

  /// Uploads [bytes] as [fileName] and returns its reference. Throws `ApiException` on failure
  /// (`file_too_large`, `file_required`).
  Future<UploadedFile> upload(Uint8List bytes, String fileName) async {
    final formData = FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: fileName)});
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/uploads'),
      data: formData,
      options: Options(receiveTimeout: const Duration(seconds: 60), sendTimeout: const Duration(seconds: 60)),
    );
    final data = response.data ?? const <String, dynamic>{};
    return UploadedFile(
      fileId: '${data['fileId'] ?? ''}',
      name: data['name'] is String ? data['name'] as String : fileName,
      mimeType: data['mimeType'] is String ? data['mimeType'] as String : 'application/octet-stream',
      size: data['size'] is num ? (data['size'] as num).toInt() : bytes.length,
    );
  }
}
