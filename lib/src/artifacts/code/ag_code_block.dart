import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';

import '../shell/ag_artifact_card.dart';
import '../theme/ag_artifacts_theme.dart';

/// Syntax-highlighted code block.
///
/// Agent props:
/// ```json
/// {
///   "title": "Authentication handler",
///   "language": "dart",
///   "code": "void main() {\n  print('Hello');\n}",
///   "maxLines": 30
/// }
/// ```
/// [language] matches flutter_highlight language names: dart, python, javascript,
/// typescript, json, yaml, bash, sql, html, css, kotlin, swift, go, rust, etc.
class AgCodeBlock extends StatelessWidget {
  const AgCodeBlock({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final artifactsTheme = AgArtifactsThemeData.of(context);

    final title = props['title'] as String? ?? 'Code';
    final language = props['language'] as String? ?? 'plaintext';
    final code = props['code']?.toString() ?? '';
    final maxLines = (props['maxLines'] as num?)?.toInt() ?? 40;
    final fontSize = artifactsTheme.codeFontSize;
    final fontFamily = artifactsTheme.codeFontFamily ?? 'monospace';

    final theme = brightness == Brightness.dark ? atomOneDarkTheme : atomOneLightTheme;

    // Background colour from the highlight theme (root style), or sensible default.
    final bgRaw = theme['root']?.backgroundColor;
    final bgColor = bgRaw ?? (brightness == Brightness.dark
        ? const Color(0xFF282c34)
        : const Color(0xFFfafafa));

    return AgArtifactCard(
      title: title,
      type: language,
      icon: Icons.code_rounded,
      copyValue: code,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(5)),
        child: Container(
          color: bgColor,
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxLines * 18.0),
              child: SingleChildScrollView(
                child: HighlightView(
                  code,
                  language: language,
                  theme: theme,
                  padding: const EdgeInsets.all(12),
                  textStyle: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: fontSize,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
