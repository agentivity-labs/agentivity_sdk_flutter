import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';
import '../shell/ag_artifact_image.dart';

/// A list of documents to open (a PDF to approve, a report): each with its name, its type and its size. Display-only.
///
/// Agent props:
/// ```json
/// {
///   "title": "Documents",
///   "files": [
///     {"id": "3f2a…", "name": "inspection.pdf", "mimeType": "application/pdf", "sizeBytes": 1251865, "url": "/api/v1/files/3f2a…"}
///   ]
/// }
/// ```
/// `url` is an address on the web, or one of the instance's own files (`/api/v1/files/…`), read from the instance when the app
/// says where it is ([AgArtifactLinks.instanceBaseUrl]). A tap opens it; a file without an address shows its name only.
class AgFileList extends StatelessWidget {
  const AgFileList({super.key, required this.props});

  final Map<String, dynamic> props;

  static String _size(Object? bytes) {
    if (bytes is! num || bytes <= 0) return '';
    if (bytes < 1024) return '${bytes.round()} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static IconData _icon(String? mimeType, String name) {
    final type = (mimeType ?? '').toLowerCase();
    final lower = name.toLowerCase();
    if (type == 'application/pdf' || lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (type.startsWith('image/')) return Icons.image_outlined;
    if (type.contains('spreadsheet') || lower.endsWith('.xlsx') || lower.endsWith('.csv')) return Icons.table_chart_outlined;
    if (type.contains('word') || lower.endsWith('.docx')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  /// Where [raw] opens: an address on the web, or the instance's own file.
  static String? addressOf(Object? raw) {
    if (raw is! String) return null;
    return agSafeHttpUrl(raw) ?? AgArtifactLinks.instanceUrl(raw.trim());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = props['title'] as String? ?? 'Documents';
    final files = (props['files'] as List? ?? const []).whereType<Map<dynamic, dynamic>>().map((e) => Map<String, dynamic>.from(e)).toList();

    return AgArtifactCard(
      title: title,
      icon: Icons.folder_open_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final file in files)
            Builder(builder: (context) {
              final name = (file['name'] as String?)?.trim().isNotEmpty == true ? file['name'] as String : (file['id'] as String? ?? 'File');
              final address = addressOf(file['url']);
              final size = _size(file['sizeBytes']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Material(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: address == null ? null : () => AgArtifactLinks.open(context, address),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(_icon(file['mimeType'] as String?, name), size: 20, color: cs.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
                          ),
                          if (size.isNotEmpty) Text(size, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
                          if (address != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.open_in_new_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.6)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
