import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Returns [raw] when it is safe to load as a picture coming from agent output — `http(s)` and raster
/// `data:image/` only. Anything else (`javascript:`, `file:`, a relative path, SVG data that can carry script)
/// yields `null`, which shows the placeholder instead.
String? agSafeImageUrl(Object? raw) {
  if (raw is! String) return null;
  final url = raw.trim();
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) return url;
  if (RegExp(r'^data:image/(png|jpe?g|gif|webp|avif);base64,', caseSensitive: false).hasMatch(url)) return url;
  return null;
}

/// Returns [raw] when it is an `http(s)` link, otherwise `null` — for links coming from agent output.
String? agSafeHttpUrl(Object? raw) {
  if (raw is! String) return null;
  final url = raw.trim();
  return RegExp(r'^https?://', caseSensitive: false).hasMatch(url) ? url : null;
}

/// How artifact links are opened. The SDK has no URL launcher of its own: an app that wants a tap to open the
/// browser sets [onOpen] once (e.g. with `url_launcher`). Without it a tap copies the link to the clipboard.
class AgArtifactLinks {
  AgArtifactLinks._();

  static void Function(Uri uri)? onOpen;

  static void open(BuildContext context, String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final handler = onOpen;
    if (handler != null) {
      handler(uri);
      return;
    }
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Link copied'), duration: Duration(seconds: 2)));
  }
}

/// The one way artifacts show a picture: never wider than its container, a neutral block while loading, and
/// when the address is missing, unsafe or fails to load it shows the first letter of [alt] — never a broken-image icon.
class AgArtifactImage extends StatelessWidget {
  const AgArtifactImage({
    super.key,
    this.src,
    this.alt,
    this.aspectRatio = 4 / 3,
    this.fit = BoxFit.contain,
    this.width,
    this.radius = 8,
  });

  final String? src;

  /// Accessible description. Also the source of the placeholder's initial.
  final String? alt;
  final double aspectRatio;

  /// `contain` shows the whole picture (products); `cover` crops to fill.
  final BoxFit fit;

  /// Fixed width. Without it the picture fills the width of its container.
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safe = agSafeImageUrl(src);

    Widget placeholder() {
      final initial = (alt ?? '').trim();
      return ColoredBox(
        color: cs.surfaceContainerHigh,
        child: Center(
          child: Text(
            initial.isEmpty ? '▣' : initial.substring(0, 1).toUpperCase(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    final Widget content;
    if (safe == null) {
      content = placeholder();
    } else if (safe.startsWith('data:')) {
      // Image.network cannot read a data: address — decode the embedded bytes.
      final bytes = _decodeDataImage(safe);
      content = bytes == null ? placeholder() : Image.memory(bytes, fit: fit, semanticLabel: alt, errorBuilder: (_, _, _) => placeholder());
    } else {
      content = Image.network(
        safe,
        fit: fit,
        semanticLabel: alt,
        errorBuilder: (_, _, _) => placeholder(),
        loadingBuilder: (_, child, progress) => progress == null ? child : ColoredBox(color: cs.surfaceContainerHigh),
      );
    }

    final box = Semantics(
      image: true,
      label: alt,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(aspectRatio: aspectRatio, child: content),
      ),
    );

    return width == null ? box : SizedBox(width: width, child: box);
  }
}

Uint8List? _decodeDataImage(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } on FormatException {
    return null;
  }
}
