import 'package:flutter/material.dart';

import '../shared/color_utils.dart';
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
    fontFamily: 'monospace',
    codeFontFamily: 'monospace',
    codeFontSize: 11.5,
    labelFontSize: 9.5,
    headerFontSize: 11.0,
  );

  // ── Riviera showcase set ─────────────────────────────────────────────────
  // Ported from `agentivity_sdk_showcase_tripagency/src/theme/themes.ts` — same five curated
  // looks, kept to what this Dart theme extension can actually carry: card shape/color, badge
  // color, chart palette, code font. The showcase's app-chrome tokens (ink/paper, pill/bubble
  // radius, the hero gradient, and a *display* font per theme) have no home here — this class has
  // no general fontFamily field (only codeFontFamily), unlike its React counterpart
  // (ArtifactsThemeData.fontFamily) — so Techno and Ledger arrive with matching colors/radius but
  // without their shared JetBrains Mono display face; only their code blocks pick it up. Adding a
  // display-font field is a real, separate API change (it would need threading through every
  // artifact widget's Text/RichText, not just this file) — flagged, not silently done here.

  /// **Light** — clean neutral default, indigo accent. Pairs with [dark] below (same accent
  /// family and radius, inverted surfaces).
  static const AgArtifactsThemeData light = AgArtifactsThemeData(
    chartPalette: [
      '#4F46E5', '#E4483D', '#10B981',
      '#F59E0B', '#06B6D4', '#EC4899',
      '#8B5CF6', '#14161A',
    ],
    cardRadius: 12.0,
    cardBackground: Color(0xFFFFFFFF),
    cardBorderColor: Color(0xFFE4E6EA),
    cardBorderWidth: 1.0,
    cardShadow: [
      BoxShadow(
        color: Color(0x24141614),
        blurRadius: 20,
        offset: Offset(0, 8),
        spreadRadius: -10,
      ),
    ],
    badgeBackground: Color(0xFFEEF0FF),
    badgeForeground: Color(0xFF4F46E5),
    fontFamily: 'Karla',
    labelFontSize: 10.0,
    headerFontSize: 12.5,
  );

  /// **Dark** — [light]'s exact pair: same indigo accent family and radius, inverted surfaces.
  /// The standard dark default, not the showy one — see [techno] for that.
  static const AgArtifactsThemeData dark = AgArtifactsThemeData(
    chartPalette: [
      '#818CF8', '#F87171', '#34D399',
      '#FBBF24', '#38BDF8', '#F472B6',
      '#A78BFA', '#F2F3F5',
    ],
    cardRadius: 12.0,
    cardBackground: Color(0xFF1A1C20),
    cardBorderColor: Color(0xFF2A2D33),
    cardBorderWidth: 1.0,
    cardShadow: [
      BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 10)),
    ],
    badgeBackground: Color(0xFF23263A),
    badgeForeground: Color(0xFFA5B4FC),
    fontFamily: 'Karla',
    labelFontSize: 10.0,
    headerFontSize: 12.5,
  );

  /// **Riviera** — this SDK's original showcase identity. Light, editorial: warm off-white
  /// surfaces, a gold accent, generous rounded corners.
  static const AgArtifactsThemeData riviera = AgArtifactsThemeData(
    chartPalette: [
      '#E3A94F', '#F1633B', '#4E7D5E',
      '#3C6E82', '#C97F49', '#6B6270',
      '#A6572F', '#171A1D',
    ],
    cardRadius: 16.0,
    cardBackground: Color(0xFFFFFFFF),
    cardBorderColor: Color(0xFFEDEBE5),
    cardBorderWidth: 1.5,
    cardShadow: [
      BoxShadow(color: Color(0x2E171A1D), blurRadius: 24, offset: Offset(0, 10), spreadRadius: -12),
    ],
    badgeBackground: Color(0xFFFDF7EC),
    badgeForeground: Color(0xFF171A1D),
    fontFamily: 'Karla',
  );

  /// **Techno** — modern and vibrant, kept in check: one cool accent duo (violet + teal), not
  /// several competing neons, tighter corners than [riviera]/[light]/[dark].
  static const AgArtifactsThemeData techno = AgArtifactsThemeData(
    chartPalette: [
      '#7C7CFF', '#34D5C4', '#F5A623',
      '#FF6F91', '#5EEAD4', '#C7C4FF',
      '#4ADE80', '#E8EAED',
    ],
    cardRadius: 5.0,
    cardBackground: Color(0xFF16181C),
    cardBorderColor: Color(0xFF262A31),
    cardShadow: [
      BoxShadow(color: Color(0x8C000000), blurRadius: 26, offset: Offset(0, 10)),
    ],
    badgeBackground: Color(0xFF201C3E),
    badgeForeground: Color(0xFF7C7CFF),
    fontFamily: 'JetBrains Mono',
    codeFontFamily: 'JetBrains Mono',
  );

  /// **Ledger** — the odd one out on purpose: sharp-cornered, print/boarding-pass counterpoint to
  /// the other four's rounding. Warm paper white, a burnt-orange "ink stamp" accent.
  static const AgArtifactsThemeData ledger = AgArtifactsThemeData(
    chartPalette: [
      '#B34700', '#B3261E', '#3A5A40',
      '#1A1A18', '#8C8C82', '#6B4F2A',
      '#D8D6CC', '#5A5A52',
    ],
    cardRadius: 3.0,
    cardBackground: Color(0xFFFAF9F5),
    cardBorderColor: Color(0xFFD8D6CC),
    cardBorderWidth: 1.0,
    cardShadow: [
      BoxShadow(color: Color(0x331A1A18), blurRadius: 16, offset: Offset(0, 6), spreadRadius: -10),
    ],
    badgeBackground: Color(0xFFF1EFE6),
    badgeForeground: Color(0xFFB34700),
    fontFamily: 'JetBrains Mono',
    labelFontSize: 9.5,
    headerFontSize: 11.5,
    valueFontSize: 26.0,
    codeFontFamily: 'JetBrains Mono',
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
    'Light':            light,
    'Dark':             dark,
    'Riviera':          riviera,
    'Techno':           techno,
    'Ledger':           ledger,
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
    'Light':            Brightness.light,
    'Dark':             Brightness.dark,
    'Riviera':          Brightness.light,
    'Techno':           Brightness.dark,
    'Ledger':           Brightness.light,
  };

  /// Returns the recommended [ThemeData] (light or dark, Material 3)
  /// for the preset with the given [name].
  ///
  /// Unlike a plain `ThemeData.light()/.dark().copyWith(extensions: [ext])`, this also seeds a
  /// matching [ColorScheme] from the preset's own accent (`badgeForeground`, or its first
  /// `chartPalette` entry) via [ColorScheme.fromSeed] — Material 3's own harmonious-palette
  /// algorithm, not a hand-picked scheme per preset. Without this, every preset's card/badge
  /// looked distinct but every *ambient* Material color (a button, a selection highlight,
  /// anything a widget outside `agentivity_artifacts` pulls from `Theme.of(context).colorScheme`)
  /// stayed the same generic Material purple regardless of which of these presets was active —
  /// confirmed: this was the actual reason two very different-looking React themes (e.g. Techno's
  /// violet vs. Ledger's burnt orange) rendered with identical button/accent colors in Flutter.
  /// [fontFamily] is applied the same way — see that field's own doc for why a direct
  /// `ThemeExtension` registration needs the same two lines to match.
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
    final seed = ext.badgeForeground ??
        (ext.chartPalette?.isNotEmpty == true
            ? parseColor(ext.chartPalette!.first, base.colorScheme.primary)
            : null);
    final colorScheme = seed == null
        ? base.colorScheme
        : ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final textTheme = ext.fontFamily == null
        ? base.textTheme
        : base.textTheme.apply(fontFamily: ext.fontFamily);
    return base.copyWith(
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: [ext],
    );
  }
}
