import 'package:flutter/material.dart';

import 'ag_artifacts_theme.dart';

/// Pre-built [AgArtifactsThemeData] presets.
///
/// Each preset is a `const` value — use it directly or customise with
/// [AgArtifactsThemeData.copyWith]:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData.light(useMaterial3: true).copyWith(
///     extensions: [AgArtifactsThemes.glacier],          // or
///     extensions: [AgArtifactsThemes.glacier.copyWith(cardRadius: 4)],
///   ),
///   darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
///     extensions: [AgArtifactsThemes.noir],
///   ),
/// )
/// ```
abstract class AgArtifactsThemes {
  AgArtifactsThemes._();

  // ── Light ─────────────────────────────────────────────────────────────────

  /// **Neutral** — Built-in defaults. Follows the Material 3 color scheme.
  /// Use when you want artifacts to blend into any app without configuration.
  static const AgArtifactsThemeData neutral = AgArtifactsThemeData();

  /// **Glacier** — Ultra-clean SaaS. Soft shadows, generous radius, cool
  /// blue-to-purple palette. Vercel / Linear / Stripe aesthetic.
  static const AgArtifactsThemeData glacier = AgArtifactsThemeData(
    chartPalette: [
      '#0ea5e9', '#6366f1', '#10b981',
      '#f59e0b', '#ef4444', '#8b5cf6',
      '#06b6d4', '#ec4899',
    ],
    cardRadius: 12.0,
    cardShadow: [
      BoxShadow(
        color: Color(0x0C000000),
        blurRadius: 16,
        offset: Offset(0, 4),
        spreadRadius: -2,
      ),
    ],
    labelFontSize: 10.0,
  );

  /// **Brutalist** — Neo-brutalism. Zero radius, thick black border, hard
  /// offset shadow. Charts look like Bauhaus posters. Polarising and
  /// impossible to ignore.
  static const AgArtifactsThemeData brutalist = AgArtifactsThemeData(
    chartPalette: [
      '#ff5f1f', '#1400ff', '#00d492',
      '#ff0099', '#ffd100', '#7928ca',
      '#00b4d8', '#f72585',
    ],
    cardRadius: 0,
    cardBorderColor: Color(0xFF000000),
    cardBorderWidth: 2.5,
    cardShadow: [
      BoxShadow(
        color: Color(0xFF000000),
        blurRadius: 0,
        offset: Offset(5, 5),
      ),
    ],
    badgeBackground: Color(0xFF000000),
    badgeForeground: Color(0xFFffd100),
    labelFontSize: 9.5,
    headerFontSize: 11.5,
  );

  /// **Paper** — Editorial warmth. Ivory background, desaturated ink palette.
  /// The Economist / Notion doc / Jupyter notebook aesthetic.
  static const AgArtifactsThemeData paper = AgArtifactsThemeData(
    chartPalette: [
      '#c2410c', '#0369a1', '#15803d',
      '#7e22ce', '#b45309', '#0f766e',
      '#be185d', '#1e40af',
    ],
    cardRadius: 2.0,
    cardBackground: Color(0xFFfaf7f2),
    cardBorderColor: Color(0xFFd9d0c0),
    cardBorderWidth: 1.0,
    badgeBackground: Color(0xFFf0e8d8),
    badgeForeground: Color(0xFF78350f),
    labelFontSize: 9.5,
  );

  /// **Candy** — Consumer-friendly. Rounded corners, soft shadows, vivid
  /// purple-pink-teal palette. Loom / Framer / Raycast vibes.
  static const AgArtifactsThemeData candy = AgArtifactsThemeData(
    chartPalette: [
      '#8b5cf6', '#ec4899', '#06b6d4',
      '#10b981', '#f59e0b', '#6366f1',
      '#f97316', '#14b8a6',
    ],
    cardRadius: 16.0,
    cardShadow: [
      BoxShadow(
        color: Color(0x1A8b5cf6),
        blurRadius: 20,
        offset: Offset(0, 6),
        spreadRadius: -2,
      ),
    ],
    badgeBackground: Color(0xFFede9fe),
    badgeForeground: Color(0xFF7c3aed),
    labelFontSize: 10.0,
  );

  // ── Dark ──────────────────────────────────────────────────────────────────

  /// **Noir** — Premium financial dark. Near-black card, gold palette. The
  /// Bloomberg Terminal / Apple Pro Display aesthetic. Every metric looks
  /// important.
  static const AgArtifactsThemeData noir = AgArtifactsThemeData(
    chartPalette: [
      '#f59e0b', '#d97706', '#fbbf24',
      '#e5e7eb', '#9ca3af', '#6b7280',
      '#fde68a', '#b45309',
    ],
    cardRadius: 3.0,
    cardBackground: Color(0xFF0a0a0a),
    cardBorderColor: Color(0xFF222222),
    cardBorderWidth: 1.0,
    cardShadow: [
      BoxShadow(color: Color(0xFF000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
    badgeBackground: Color(0xFF1a1a1a),
    badgeForeground: Color(0xFFd97706),
    labelFontSize: 9.5,
    headerFontSize: 11.5,
    valueFontSize: 26.0,
  );

  /// **Aurora** — Dark with a full-spectrum palette. Each dataset shimmers
  /// from teal to violet to rose. The "wow" demo theme — screenshottable.
  static const AgArtifactsThemeData aurora = AgArtifactsThemeData(
    chartPalette: [
      '#06b6d4', '#3b82f6', '#8b5cf6',
      '#ec4899', '#f59e0b', '#10b981',
      '#f97316', '#0ea5e9',
    ],
    cardRadius: 8.0,
    cardBackground: Color(0xFF0d1117),
    cardBorderColor: Color(0xFF21262d),
    cardShadow: [
      BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 6)),
    ],
    badgeBackground: Color(0xFF161b22),
    badgeForeground: Color(0xFF58a6ff),
  );

  /// **Velvet** — Deep purple luxury dark. Violet-to-gold palette, subtle
  /// purple glow. Linear / Raycast / Vercel dark mode aesthetic.
  static const AgArtifactsThemeData velvet = AgArtifactsThemeData(
    chartPalette: [
      '#7c3aed', '#a78bfa', '#c4b5fd',
      '#fbbf24', '#34d399', '#f472b6',
      '#38bdf8', '#fb923c',
    ],
    cardRadius: 10.0,
    cardBackground: Color(0xFF0f0722),
    cardBorderColor: Color(0xFF2d1b6b),
    cardShadow: [
      BoxShadow(color: Color(0x667c3aed), blurRadius: 24, offset: Offset(0, 8)),
    ],
    badgeBackground: Color(0xFF1e0f4e),
    badgeForeground: Color(0xFFa78bfa),
  );

  /// **Ember** — Warm dark. Fire-orange palette with an amber glow. Great for
  /// ops dashboards, alerting, real-time monitoring.
  static const AgArtifactsThemeData ember = AgArtifactsThemeData(
    chartPalette: [
      '#ff6b35', '#f7931e', '#ffd23f',
      '#ee4266', '#06d6a0', '#f77f00',
      '#fcbf49', '#ef233c',
    ],
    cardRadius: 5.0,
    cardBackground: Color(0xFF1c0f07),
    cardBorderColor: Color(0xFF3d1f0a),
    cardShadow: [
      BoxShadow(color: Color(0x4Dff6b35), blurRadius: 16, offset: Offset(0, 6)),
    ],
    badgeBackground: Color(0xFF3d1f0a),
    badgeForeground: Color(0xFFf7931e),
  );

  /// **Terminal** — Dev / hacker aesthetic. GitHub dark background, green
  /// phosphor accents, zero border radius. Every chart reads like a matrix
  /// output.
  static const AgArtifactsThemeData terminal = AgArtifactsThemeData(
    chartPalette: [
      '#39d353', '#58a6ff', '#f78166',
      '#ffa657', '#d2a8ff', '#56d364',
      '#79c0ff', '#ffa198',
    ],
    cardRadius: 0,
    cardBackground: Color(0xFF0d1117),
    cardBorderColor: Color(0xFF30363d),
    cardBorderWidth: 1.0,
    cardShadow: [],
    badgeBackground: Color(0xFF161b22),
    badgeForeground: Color(0xFF39d353),
    codeFontFamily: 'monospace',
    codeFontSize: 11.5,
    labelFontSize: 9.5,
    headerFontSize: 11.0,
  );

  // ── Official ──────────────────────────────────────────────────────────────

  /// **Agentivity** — alias for [agentivityLight]. Kept for backward compat.
  static const AgArtifactsThemeData agentivity = agentivityLight;

  /// **Agentivity Light** — Official Agentivity Studio theme, light surface.
  /// Iris `#8B61FF` primary palette, compact 5 px radius, studio font sizing.
  static const AgArtifactsThemeData agentivityLight = AgArtifactsThemeData(
    chartPalette: [
      '#8B61FF', '#10b981', '#f59e0b',
      '#ef4444', '#06b6d4', '#ec4899',
      '#84cc16', '#f97316',
    ],
    cardRadius: 5.0,
    cardShadow: [
      BoxShadow(
        color: Color(0x0D000000),
        blurRadius: 6,
        offset: Offset(0, 2),
        spreadRadius: 0,
      ),
    ],
    badgeBackground: Color(0xFFF0ECFF),
    badgeForeground: Color(0xFF6B3FE0),
    labelFontSize: 9.5,
    headerFontSize: 11.0,
  );

  /// **Agentivity Dark** — Official Agentivity Studio theme, dark surface.
  /// Same iris `#8B61FF` palette on a `#161616`-family dark background.
  static const AgArtifactsThemeData agentivityDark = AgArtifactsThemeData(
    chartPalette: [
      '#8B61FF', '#10b981', '#f59e0b',
      '#ef4444', '#06b6d4', '#ec4899',
      '#84cc16', '#f97316',
    ],
    cardRadius: 5.0,
    cardBackground: Color(0xFF1E1E1E),
    cardBorderColor: Color(0xFF2A2A2A),
    cardShadow: [
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 8,
        offset: Offset(0, 2),
        spreadRadius: 0,
      ),
    ],
    badgeBackground: Color(0xFF2D2040),
    badgeForeground: Color(0xFF8B61FF),
    labelFontSize: 9.5,
    headerFontSize: 11.0,
  );

  // ── Catalogue ─────────────────────────────────────────────────────────────

  /// All available themes keyed by display name.
  static const Map<String, AgArtifactsThemeData> all = {
    'Neutral':          neutral,
    'Glacier':          glacier,
    'Brutalist':        brutalist,
    'Paper':            paper,
    'Candy':            candy,
    'Noir':             noir,
    'Aurora':           aurora,
    'Velvet':           velvet,
    'Ember':            ember,
    'Terminal':         terminal,
    'Agentivity':       agentivity,
    'Agentivity Light': agentivityLight,
    'Agentivity Dark':  agentivityDark,
  };

  /// Recommended [Brightness] for each theme.
  static const Map<String, Brightness> suggestedBrightness = {
    'Neutral':          Brightness.light,
    'Glacier':          Brightness.light,
    'Brutalist':        Brightness.light,
    'Paper':            Brightness.light,
    'Candy':            Brightness.light,
    'Noir':             Brightness.dark,
    'Aurora':           Brightness.dark,
    'Velvet':           Brightness.dark,
    'Ember':            Brightness.dark,
    'Terminal':         Brightness.dark,
    'Agentivity':       Brightness.light,
    'Agentivity Light': Brightness.light,
    'Agentivity Dark':  Brightness.dark,
  };

  /// Returns the recommended [ThemeData] (light or dark, Material 3)
  /// for the preset with the given [name].
  ///
  /// ```dart
  /// MaterialApp(
  ///   theme: AgArtifactsThemes.themeDataFor('Glacier'),
  ///   darkTheme: AgArtifactsThemes.themeDataFor('Noir'),
  /// )
  /// ```
  static ThemeData themeDataFor(String name) {
    final ext = all[name] ?? neutral;
    final brightness = suggestedBrightness[name] ?? Brightness.light;
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    return base.copyWith(extensions: [ext]);
  }
}
