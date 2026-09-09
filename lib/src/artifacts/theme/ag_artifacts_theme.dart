import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

import '../shared/color_utils.dart';

/// Styling configuration for all [agentivity_artifacts] widgets.
///
/// Registered as a Flutter [ThemeExtension] inside [MaterialApp] — no wrapper
/// widget needed. Every artifact widget reads it automatically via
/// [AgArtifactsThemeData.of].
///
/// ## Design tokens
///
/// Two scale multipliers are forwarded from the kit-level
/// [AgKitPreferencesController] (when used with `agentivity_kit`), or can
/// be set directly for standalone use:
///
/// | Field          | Default | Effect                                    |
/// |----------------|---------|-------------------------------------------|
/// | [fontScale]    | 1.0     | Scales all font-size helpers.             |
/// | [spacingScale] | 1.0     | Scales [effectiveCardPadding].            |
///
/// Use the `effective*` getters in widget code so every rendering decision
/// respects the user's scale preference:
///
/// ```dart
/// final theme = AgArtifactsThemeData.of(context);
/// Text('Label', style: TextStyle(fontSize: theme.effectiveLabelFontSize));
/// ```
///
/// ## Setup
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData.light(useMaterial3: true).copyWith(
///     extensions: [AgArtifactsThemes.glacier],
///   ),
///   darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
///     extensions: [AgArtifactsThemes.noir],
///   ),
/// )
/// ```
class AgArtifactsThemeData extends ThemeExtension<AgArtifactsThemeData> {
  const AgArtifactsThemeData({
    // ── Charts ───────────────────────────────────────────────────────────────
    this.chartPalette,

    // ── Card shell ───────────────────────────────────────────────────────────
    this.cardRadius = 5.0,
    this.cardPadding = const EdgeInsets.all(12),
    this.cardBackground,
    this.cardBorderColor,
    this.cardBorderWidth = 1.0,
    this.cardShadow = const [],

    // ── Badge (type label in the card header) ────────────────────────────────
    this.badgeBackground,
    this.badgeForeground,

    // ── Typography ───────────────────────────────────────────────────────────
    this.labelFontSize = 10.0,
    this.headerFontSize = 12.0,
    this.valueFontSize = 28.0,
    this.codeFontFamily,
    this.codeFontSize = 12.0,

    // ── Scale tokens (propagated by AgKitPreferencesController) ─────────────
    this.fontScale = 1.0,
    this.spacingScale = 1.0,
  });

  // ── Charts ─────────────────────────────────────────────────────────────────

  /// Ordered hex color list for chart datasets.
  /// When `null`, [kDefaultPalette] is used.
  final List<String>? chartPalette;

  // ── Card shell ─────────────────────────────────────────────────────────────

  /// Corner radius applied to every [AgArtifactCard]. Default: 5.
  final double cardRadius;

  /// Inner padding of the content area. Default: `EdgeInsets.all(12)`.
  final EdgeInsetsGeometry cardPadding;

  /// Card background color. When `null`, the Material `surface` color is used.
  final Color? cardBackground;

  /// Card border color. When `null`, `colorScheme.outlineVariant` is used.
  final Color? cardBorderColor;

  /// Card border stroke width. Default: 1.
  final double cardBorderWidth;

  /// Shadows applied to each card.
  final List<BoxShadow> cardShadow;

  // ── Badge ──────────────────────────────────────────────────────────────────

  /// Background of the type badge chip in the card header.
  final Color? badgeBackground;

  /// Text color of the type badge chip.
  final Color? badgeForeground;

  // ── Typography ─────────────────────────────────────────────────────────────

  /// Base font size for axis labels, legend dots, subtitles. Default: 10.
  final double labelFontSize;

  /// Base font size for the card header title. Default: 12.
  final double headerFontSize;

  /// Base font size for the main value in metric cards. Default: 28.
  final double valueFontSize;

  /// Font family for code blocks. `null` → system monospace.
  final String? codeFontFamily;

  /// Base font size for code block source text. Default: 12.
  final double codeFontSize;

  // ── Scale tokens ────────────────────────────────────────────────────────────

  /// Font-size multiplier (1.0 = original). Propagated from
  /// `AgKitPreferencesController.fontScale` when using `agentivity_kit`.
  final double fontScale;

  /// Spacing multiplier (1.0 = original). Propagated from
  /// `AgKitPreferencesController.spacingScale` when using `agentivity_kit`.
  final double spacingScale;

  // ── Computed helpers ────────────────────────────────────────────────────────

  /// Axis-label / legend font size, scaled by [fontScale].
  double get effectiveLabelFontSize => labelFontSize * fontScale;

  /// Card-header title font size, scaled by [fontScale].
  double get effectiveHeaderFontSize => headerFontSize * fontScale;

  /// Metric card value font size, scaled by [fontScale].
  double get effectiveValueFontSize => valueFontSize * fontScale;

  /// Code-block font size, scaled by [fontScale].
  double get effectiveCodeFontSize => codeFontSize * fontScale;

  /// Card inner padding, scaled by [spacingScale].
  EdgeInsetsGeometry get effectiveCardPadding {
    final p = cardPadding;
    if (p is EdgeInsets) {
      return EdgeInsets.fromLTRB(
        p.left * spacingScale,
        p.top * spacingScale,
        p.right * spacingScale,
        p.bottom * spacingScale,
      );
    }
    return p; // non-EdgeInsets variants returned unchanged
  }

  // ── Static helpers ──────────────────────────────────────────────────────────

  /// Returns the nearest [AgArtifactsThemeData] from the [MaterialApp] theme
  /// extensions, or the built-in defaults when none is registered.
  static AgArtifactsThemeData of(BuildContext context) =>
      Theme.of(context).extension<AgArtifactsThemeData>() ??
      const AgArtifactsThemeData();

  /// The chart palette, falling back to [kDefaultPalette] when unset.
  List<String> effectivePalette() => chartPalette ?? kDefaultPalette;

  // ── ThemeExtension ─────────────────────────────────────────────────────────

  @override
  AgArtifactsThemeData copyWith({
    List<String>? chartPalette,
    double? cardRadius,
    EdgeInsetsGeometry? cardPadding,
    Color? cardBackground,
    Color? cardBorderColor,
    double? cardBorderWidth,
    List<BoxShadow>? cardShadow,
    Color? badgeBackground,
    Color? badgeForeground,
    double? labelFontSize,
    double? headerFontSize,
    double? valueFontSize,
    String? codeFontFamily,
    double? codeFontSize,
    double? fontScale,
    double? spacingScale,
  }) =>
      AgArtifactsThemeData(
        chartPalette: chartPalette ?? this.chartPalette,
        cardRadius: cardRadius ?? this.cardRadius,
        cardPadding: cardPadding ?? this.cardPadding,
        cardBackground: cardBackground ?? this.cardBackground,
        cardBorderColor: cardBorderColor ?? this.cardBorderColor,
        cardBorderWidth: cardBorderWidth ?? this.cardBorderWidth,
        cardShadow: cardShadow ?? this.cardShadow,
        badgeBackground: badgeBackground ?? this.badgeBackground,
        badgeForeground: badgeForeground ?? this.badgeForeground,
        labelFontSize: labelFontSize ?? this.labelFontSize,
        headerFontSize: headerFontSize ?? this.headerFontSize,
        valueFontSize: valueFontSize ?? this.valueFontSize,
        codeFontFamily: codeFontFamily ?? this.codeFontFamily,
        codeFontSize: codeFontSize ?? this.codeFontSize,
        fontScale: fontScale ?? this.fontScale,
        spacingScale: spacingScale ?? this.spacingScale,
      );

  @override
  AgArtifactsThemeData lerp(AgArtifactsThemeData other, double t) =>
      AgArtifactsThemeData(
        chartPalette: t < 0.5 ? chartPalette : other.chartPalette,
        cardRadius: lerpDouble(cardRadius, other.cardRadius, t) ?? cardRadius,
        cardPadding:
            EdgeInsetsGeometry.lerp(cardPadding, other.cardPadding, t) ??
                cardPadding,
        cardBackground:
            Color.lerp(cardBackground, other.cardBackground, t),
        cardBorderColor:
            Color.lerp(cardBorderColor, other.cardBorderColor, t),
        cardBorderWidth:
            lerpDouble(cardBorderWidth, other.cardBorderWidth, t) ??
                cardBorderWidth,
        cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
        badgeBackground:
            Color.lerp(badgeBackground, other.badgeBackground, t),
        badgeForeground:
            Color.lerp(badgeForeground, other.badgeForeground, t),
        labelFontSize:
            lerpDouble(labelFontSize, other.labelFontSize, t) ?? labelFontSize,
        headerFontSize:
            lerpDouble(headerFontSize, other.headerFontSize, t) ??
                headerFontSize,
        valueFontSize:
            lerpDouble(valueFontSize, other.valueFontSize, t) ?? valueFontSize,
        codeFontFamily: t < 0.5 ? codeFontFamily : other.codeFontFamily,
        codeFontSize:
            lerpDouble(codeFontSize, other.codeFontSize, t) ?? codeFontSize,
        fontScale: lerpDouble(fontScale, other.fontScale, t) ?? fontScale,
        spacingScale:
            lerpDouble(spacingScale, other.spacingScale, t) ?? spacingScale,
      );
}
