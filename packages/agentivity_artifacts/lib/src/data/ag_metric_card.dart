import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';
import '../theme/ag_artifacts_theme.dart';

/// Single KPI metric card.
///
/// Agent props:
/// ```json
/// {
///   "title": "ARR",
///   "value": "€ 1.2M",
///   "delta": "+18%",
///   "trend": "up",
///   "subtitle": "vs last quarter"
/// }
/// ```
/// [trend] can be "up", "down" or "flat".
class AgMetricCard extends StatelessWidget {
  const AgMetricCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AgArtifactsThemeData.of(context);
    final title = props['title'] as String? ?? 'Metric';
    final value = props['value']?.toString() ?? '—';
    final delta = props['delta'] as String?;
    final trend = props['trend'] as String?; // up | down | flat
    final subtitle = props['subtitle'] as String?;

    Color trendColor = cs.onSurface.withValues(alpha: 0.5);
    IconData trendIcon = Icons.remove_rounded;
    if (trend == 'up') {
      trendColor = const Color(0xFF10b981);
      trendIcon = Icons.arrow_upward_rounded;
    } else if (trend == 'down') {
      trendColor = const Color(0xFFef4444);
      trendIcon = Icons.arrow_downward_rounded;
    }

    return AgArtifactCard(
      title: title,
      icon: Icons.speed_rounded,
      type: 'Metric',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: t.valueFontSize,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          if (delta != null || subtitle != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (delta != null) ...[
                  Icon(trendIcon, size: 13, color: trendColor),
                  const SizedBox(width: 3),
                  Text(
                    delta,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: trendColor,
                    ),
                  ),
                  if (subtitle != null) const SizedBox(width: 6),
                ],
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
