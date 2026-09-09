import 'package:flutter/material.dart';

import '../theme/ag_artifacts_theme.dart';

/// Parses a hex color string (#RRGGBB or #AARRGGBB) or returns [fallback].
Color parseColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.parse(cleaned.length == 6 ? 'FF$cleaned' : cleaned,
        radix: 16);
    return Color(value);
  } catch (_) {
    return fallback;
  }
}

/// Default palette used when no [AgArtifactsTheme] is in scope and the agent
/// doesn't specify colors.
const List<String> kDefaultPalette = [
  '#3b82f6', '#10b981', '#f59e0b', '#ef4444',
  '#8b5cf6', '#06b6d4', '#ec4899', '#84cc16',
];

/// Returns the [index]-th colour from [kDefaultPalette], parsed as a [Color].
Color paletteColor(int index, Color fallback) =>
    parseColor(kDefaultPalette[index % kDefaultPalette.length], fallback);

/// Returns the [index]-th colour from the effective palette, reading
/// [AgArtifactsTheme] from [context] first, then falling back to
/// [kDefaultPalette] and finally to [fallback].
Color paletteColorOf(BuildContext context, int index, Color fallback) {
  final palette = AgArtifactsThemeData.of(context).effectivePalette();
  return parseColor(palette[index % palette.length], fallback);
}
