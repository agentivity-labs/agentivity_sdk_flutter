import 'dart:convert';

import '../../../client/app_client/agentivity_client.dart';
import '../../../client/app_client/domain/file_models.dart';
import 'ag_ui_chat_input.dart';
import 'chat_models.dart';

/// The largest image a run takes, in bytes before base64.
///
/// Images travel inline in the body of the request that starts the run — there is nowhere to put a big one — so one that is too
/// large is refused by name rather than shrunk or sent and lost somewhere in the middle.
const int maxImageForARun = 8 * 1024 * 1024;

/// The images of what someone joined to their message, in the shape a run takes them: `{base64Data, mimeType}`.
///
/// Takes what the chat input holds ([AgUiInputAttachment]) and what a message carries ([ChatAttachment]) alike: only bytes can
/// be sent, so a file named by its path (meaningless on the web, and not read here) is left out — the picker only offers images
/// anyway. Throws [ImageTooLargeForARun] for an image over [maxImageForARun].
List<Map<String, String>> imagesForARun(List<Object?> attachments) {
  final images = <Map<String, String>>[];
  for (final attachment in attachments) {
    final (bytes, name, mimeType) = switch (attachment) {
      AgUiImageBytesAttachment a => (a.bytes, a.name, a.mimeType),
      ImageBytesAttachment a => (a.bytes, a.name, a.mimeType),
      _ => (null, null, null),
    };
    if (bytes == null) continue;
    if (bytes.length > maxImageForARun) throw ImageTooLargeForARun(name ?? 'image', bytes.length);
    images.add({'base64Data': base64Encode(bytes), 'mimeType': mimeType ?? 'image/png'});
  }
  return images;
}

/// An image too large to travel with a run, said with its name and its size.
class ImageTooLargeForARun implements Exception {
  ImageTooLargeForARun(this.name, this.sizeBytes, {this.most = maxImageForARun});

  final String name;
  final int sizeBytes;

  /// The largest it could have been.
  final int most;

  @override
  String toString() =>
      '"$name" is too large (${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB) — files are limited to ${most ~/ (1024 * 1024)} MB.';
}

/// The files of what someone joined to their message, as a run takes them: their ids. The photos and the documents held as bytes
/// are uploaded first (all at once), a file already uploaded ([FileAttachment]) is given by its id; a file named by its path only
/// (not read here) is left out. Throws [ImageTooLargeForARun] for a file over [FileUpload.sizeMost], before anything is sent.
Future<List<String>> filesForARun(AgentivityClient client, List<Object?> attachments) async {
  final ids = <String>[];
  final uploads = <FileUpload>[];
  for (final attachment in attachments) {
    final (bytes, name, mimeType) = switch (attachment) {
      AgUiImageBytesAttachment a => (a.bytes, a.name ?? 'photo.png', a.mimeType),
      ImageBytesAttachment a => (a.bytes, a.name ?? 'photo.png', a.mimeType),
      AgUiFileBytesAttachment a => (a.bytes, a.name ?? 'file', a.mimeType),
      FileBytesAttachment a => (a.bytes, a.name ?? 'file', a.mimeType),
      _ => (null, null, null),
    };
    if (attachment is FileAttachment) ids.add(attachment.fileId);
    if (bytes == null) continue;
    if (bytes.length > FileUpload.sizeMost) throw ImageTooLargeForARun(name!, bytes.length, most: FileUpload.sizeMost);
    uploads.add(FileUpload(name: name!, bytes: bytes, contentType: mimeType));
  }
  if (uploads.isNotEmpty) ids.addAll((await client.files.upload(uploads)).map((f) => f.id));
  return ids;
}
