import 'dart:convert';

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
  ImageTooLargeForARun(this.name, this.sizeBytes);

  final String name;
  final int sizeBytes;

  @override
  String toString() =>
      '"$name" is too large (${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB) — images are limited to ${maxImageForARun ~/ (1024 * 1024)} MB.';
}
