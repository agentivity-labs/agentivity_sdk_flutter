import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/http_core.dart';
import '../domain/file_models.dart';

/// The files of the workspace: upload several at once, read one back, make a link that opens one for a time. A person reads back
/// the files they uploaded and those of the executions they may see; a link opens its file for anyone, until it expires.
class FilesApi {
  FilesApi(this._c);
  final AgentivityHttpCore _c;

  /// Uploads [files] in one request and returns them as the workspace keeps them, in the same order. Throws `ApiException` on
  /// failure (`file_too_large`, `too_many_files`, `file_required`).
  Future<List<FileRef>> upload(List<FileUpload> files) async {
    if (files.isEmpty) return const [];
    final formData = FormData();
    for (final file in files) {
      formData.files.add(MapEntry(
        'files',
        MultipartFile.fromBytes(file.bytes, filename: file.name, contentType: file.contentType == null ? null : DioMediaType.parse(file.contentType!)),
      ));
    }
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/uploads'),
      data: formData,
      options: Options(receiveTimeout: AgentivityHttpCore.wakeWait, sendTimeout: const Duration(minutes: 5)),
    );
    final kept = response.data?['files'];
    return kept is List ? [for (final f in kept.whereType<Map>()) FileRef.fromJson(Map<String, dynamic>.from(f))] : const [];
  }

  /// The bytes of the file [id]. Throws `ApiException` when it is not there (`file_not_found`) or not the caller's to read
  /// (`file_not_yours`).
  Future<Uint8List> bytes(String id) async {
    final response = await _c.get<List<int>>(
      AgentivityHttpCore.v1('/files/${Uri.encodeComponent(id)}'),
      options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(minutes: 5)),
      dataBody: true,
    );
    final data = response.data;
    return data is Uint8List ? data : Uint8List.fromList(data ?? const []);
  }

  /// A link that opens the file [id] without signing in for [minutes] (60 by default, 7 days at most).
  Future<FileLink> link(String id, {int minutes = 60}) async {
    final response = await _c.get<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/files/${Uri.encodeComponent(id)}/link'),
      queryParameters: {'minutes': minutes},
    );
    return FileLink.fromJson(response.data ?? const <String, dynamic>{});
  }
}
