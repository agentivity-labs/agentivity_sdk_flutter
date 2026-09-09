import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ag_artifacts_theme.dart';

/// Shared card shell for all artifact widgets.
///
/// All visual properties (radius, background, border, shadow, typography)
/// are driven by [AgArtifactsThemeData] — no hardcoded values.
class AgArtifactCard extends StatelessWidget {
  const AgArtifactCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.type,
    this.copyValue,
    this.actions = const [],
    this.padding,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  /// Optional type badge shown next to the title (e.g. "Bar Chart").
  final String? type;

  /// When set, a copy icon copies this string to the clipboard.
  final String? copyValue;

  final List<Widget> actions;

  /// Per-card padding override. When `null`, [AgArtifactsThemeData.cardPadding]
  /// is used.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AgArtifactsThemeData.of(context);
    final radius = BorderRadius.circular(t.cardRadius);

    final bgColor = t.cardBackground ?? cs.surface;
    final borderColor = t.cardBorderColor ?? cs.outlineVariant;
    final badgeBg = t.badgeBackground ?? cs.primaryContainer.withValues(alpha: 0.4);
    final badgeFg = t.badgeForeground ?? cs.primary;

    // The on-surface color adapts to the card background brightness.
    final onBg = ThemeData.estimateBrightnessForColor(bgColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: t.cardBorderWidth),
        borderRadius: radius,
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 13, color: onBg.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: t.headerFontSize,
                    fontWeight: FontWeight.w600,
                    color: onBg.withValues(alpha: 0.85),
                  ),
                ),
                if (type != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      type!,
                      style: TextStyle(
                        fontSize: t.labelFontSize,
                        color: badgeFg,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                ...actions,
                if (copyValue != null)
                  _CopyButton(value: copyValue!, onBg: onBg, accent: badgeFg),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
          // ── Content ────────────────────────────────────────────────────────
          Padding(padding: padding ?? t.cardPadding, child: child),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CopyButton extends StatefulWidget {
  const _CopyButton({
    required this.value,
    required this.onBg,
    required this.accent,
  });
  final String value;
  final Color onBg;
  final Color accent;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _copy,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _copied ? Icons.check_rounded : Icons.copy_rounded,
          key: ValueKey(_copied),
          size: 13,
          color: _copied
              ? widget.accent
              : widget.onBg.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
