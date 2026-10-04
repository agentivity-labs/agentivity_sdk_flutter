import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';
import '../shell/ag_artifact_image.dart';

/// A grid of pictures, each with an optional caption and link. Display-only.
///
/// Agent props:
/// ```json
/// {
///   "title": "Candidates",
///   "images": [
///     {"url": "https://…", "alt": "Roomba Combo", "caption": "Roomba Combo — $499", "href": "https://shop.example/roomba"}
///   ],
///   "columns": 3,
///   "aspectRatio": "4 / 3",
///   "fit": "contain"
/// }
/// ```
/// `columns` is 1–4 (default 3), `aspectRatio` a ratio such as `"4 / 3"`, `fit` `"contain"` (whole picture, default)
/// or `"cover"` (crops). A picture that cannot be shown keeps its place with a neutral block, so captions stay aligned.
class AgImageGallery extends StatelessWidget {
  const AgImageGallery({super.key, required this.props});

  final Map<String, dynamic> props;

  static double _ratio(Object? raw) {
    if (raw is String) {
      final m = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)\s*$').firstMatch(raw);
      if (m != null) {
        final w = double.parse(m.group(1)!);
        final h = double.parse(m.group(2)!);
        if (w > 0 && h > 0) return w / h;
      }
    }
    return 4 / 3;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = props['title'] as String? ?? 'Images';
    final images = (props['images'] as List? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final requested = props['columns'] is num ? (props['columns'] as num).round() : 3;
    final columns = requested.clamp(1, 4);
    final ratio = _ratio(props['aspectRatio']);
    final fit = props['fit'] == 'cover' ? BoxFit.cover : BoxFit.contain;

    return AgArtifactCard(
      title: title,
      icon: Icons.photo_library_rounded,
      type: 'Images',
      child: LayoutBuilder(
        builder: (context, constraints) {
          // As many columns as were asked for, fewer when a picture would drop under ~140px.
          final fitting = (constraints.maxWidth / 140).floor().clamp(1, 4);
          final perRow = columns < fitting ? columns : fitting;
          const gap = 12.0;
          final cell = (constraints.maxWidth - gap * (perRow - 1)) / perRow;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: images.map((image) {
              final href = agSafeHttpUrl(image['href']);
              final caption = image['caption'] as String?;
              final alt = image['alt'] as String? ?? caption;
              Widget picture = AgArtifactImage(src: image['url'] as String?, alt: alt, aspectRatio: ratio, fit: fit);
              if (href != null) {
                picture = GestureDetector(onTap: () => AgArtifactLinks.open(context, href), child: picture);
              }
              return SizedBox(
                width: cell,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    picture,
                    if (caption != null) ...[
                      const SizedBox(height: 6),
                      Text(caption, style: TextStyle(fontSize: 11, height: 1.35, color: cs.onSurface.withValues(alpha: 0.65))),
                    ],
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
