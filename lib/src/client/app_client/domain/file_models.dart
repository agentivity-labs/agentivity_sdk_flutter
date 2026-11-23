import 'package:flutter/foundation.dart';

/// A file of the workspace, the one file type of the platform: what a person uploads, an image or a sound made by a step, a
/// document a workflow produces. It names the file (its [id], the [area] that keeps it), never carries its bytes: read them with
/// `client.files.bytes(id)`, or open them with a link (`client.files.link(id)`). A file that is not the workspace's (an address
/// on the web) has no [area] and says its [url].
@immutable
class FileRef {
  const FileRef({
    required this.id,
    this.area,
    this.name,
    this.mimeType,
    this.sizeBytes,
    this.width,
    this.height,
    this.url,
    this.executionId,
  });

  final String id;

  /// Where the workspace keeps it: `files` (produced), `uploads`, `images`, `audio`; null for a file that is not ours.
  final String? area;

  /// The name of the file, as a person sees it.
  final String? name;
  final String? mimeType;
  final int? sizeBytes;
  final int? width;
  final int? height;

  /// A public http(s) address, for a file that is not ours.
  final String? url;

  /// The execution that produced or received it, when there is one.
  final String? executionId;

  /// Whether the file is an image.
  bool get isImage => (mimeType ?? '').toLowerCase().startsWith('image/');

  /// A file as the platform says it (snake_case, like the steps of a workflow carry it).
  factory FileRef.fromJson(Map<String, dynamic> json) {
    String? text(String key) => json[key] is String && (json[key] as String).isNotEmpty ? json[key] as String : null;
    int? number(String key) => json[key] is num ? (json[key] as num).toInt() : null;
    return FileRef(
      id: '${json['id'] ?? json['fileId'] ?? ''}',
      area: text('area'),
      name: text('name') ?? text('file_name'),
      mimeType: text('mime_type') ?? text('mimeType'),
      sizeBytes: number('size_bytes') ?? number('size'),
      width: number('width'),
      height: number('height'),
      url: text('url'),
      executionId: text('execution_id'),
    );
  }

  /// The file as a workflow input takes it.
  Map<String, dynamic> toJson() => {
        'id': id,
        if (area != null) 'area': area,
        if (name != null) 'name': name,
        if (mimeType != null) 'mime_type': mimeType,
        if (sizeBytes != null) 'size_bytes': sizeBytes,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (url != null) 'url': url,
        if (executionId != null) 'execution_id': executionId,
      };

  @override
  bool operator ==(Object other) => other is FileRef && other.id == id && other.area == area && other.url == url;

  @override
  int get hashCode => Object.hash(id, area, url);

  @override
  String toString() => 'FileRef($id, ${name ?? '-'}, ${mimeType ?? '-'})';
}

/// A file to upload: its name, its bytes and, when known, its type. 25 MB at most each, 20 in one upload (by default).
@immutable
class FileUpload {
  const FileUpload({required this.name, required this.bytes, this.contentType});

  static const sizeMost = 25 * 1024 * 1024;
  static const perUploadMost = 20;

  final String name;
  final Uint8List bytes;
  final String? contentType;
}

/// A link that opens a file without signing in, until [expiresAt]: for an e-mail, for whoever approves.
@immutable
class FileLink {
  const FileLink({required this.path, required this.url, required this.expiresAt});

  /// The address on the instance (`/api/v1/files/{id}/content?token=…`).
  final String path;

  /// The full address, as the instance was called.
  final String url;
  final DateTime expiresAt;

  factory FileLink.fromJson(Map<String, dynamic> json) => FileLink(
        path: '${json['path'] ?? ''}',
        url: '${json['url'] ?? json['path'] ?? ''}',
        expiresAt: DateTime.tryParse('${json['expiresAt'] ?? ''}')?.toUtc() ?? DateTime.now().toUtc(),
      );
}
