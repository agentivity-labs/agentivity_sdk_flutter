import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../shell/ag_artifact_card.dart';

/// SVG image renderer via flutter_svg.
///
/// Agent props:
/// ```json
/// {
///   "title": "Architecture diagram",
///   "svg": "<svg xmlns='http://www.w3.org/2000/svg' ...>...</svg>",
///   "height": 300,
///   "fit": "contain"
/// }
/// ```
/// [svg] — raw SVG markup string (full `<svg>` element).
/// [height] — card content height in logical pixels (default: 300).
/// [fit] — BoxFit name: "contain" (default), "cover", "fill", "fitWidth", "fitHeight".
class AgSvg extends StatelessWidget {
  const AgSvg({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final title = props['title'] as String? ?? 'SVG';
    final svg = props['svg']?.toString() ?? '<svg xmlns="http://www.w3.org/2000/svg"/>';
    final height = (props['height'] as num?)?.toDouble() ?? 300.0;
    final fitName = props['fit'] as String? ?? 'contain';

    final fit = _parseFit(fitName);

    return AgArtifactCard(
      title: title,
      type: 'SVG',
      icon: Icons.image_rounded,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: SvgPicture.string(
          svg,
          fit: fit,
          placeholderBuilder: (_) => const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }

  BoxFit _parseFit(String name) => switch (name) {
        'cover'     => BoxFit.cover,
        'fill'      => BoxFit.fill,
        'fitWidth'  => BoxFit.fitWidth,
        'fitHeight' => BoxFit.fitHeight,
        'none'      => BoxFit.none,
        _            => BoxFit.contain,
      };
}
