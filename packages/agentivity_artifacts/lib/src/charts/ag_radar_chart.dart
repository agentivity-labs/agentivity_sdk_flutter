import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../shared/color_utils.dart';
import '../shell/ag_artifact_card.dart';

/// Radar / spider chart artifact.
///
/// Agent props:
/// ```json
/// {
///   "title": "Performance Radar",
///   "labels": ["Speed", "Quality", "Cost", "UX", "Security"],
///   "datasets": [
///     { "label": "Model A", "data": [4.2, 3.8, 2.5, 4.0, 4.5] },
///     { "label": "Model B", "data": [3.0, 4.5, 3.8, 3.2, 3.9] }
///   ],
///   "max": 5.0,
///   "height": 260
/// }
/// ```
class AgRadarChart extends StatelessWidget {
  const AgRadarChart({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = props['title'] as String? ?? 'Radar Chart';
    final labels = (props['labels'] as List?)?.cast<String>() ?? [];
    final datasets = (props['datasets'] as List?) ?? [];
    final height = (props['height'] as num?)?.toDouble() ?? 260;

    final dataSets = <RadarDataSet>[];
    for (var d = 0; d < datasets.length; d++) {
      final ds = datasets[d] as Map<String, dynamic>;
      final data = (ds['data'] as List?)?.cast<num>() ?? [];
      final color = parseColor(
        ds['color'] as String?,
        paletteColorOf(context, d, cs.primary),
      );
      dataSets.add(RadarDataSet(
        dataEntries: data.map((v) => RadarEntry(value: v.toDouble())).toList(),
        fillColor: color.withValues(alpha: 0.18),
        borderColor: color,
        borderWidth: 2,
        entryRadius: 3,
      ));
    }

    final gridColor = cs.outlineVariant.withValues(alpha: 0.4);
    final labelColor = cs.onSurface.withValues(alpha: 0.65);

    // Legend (when multiple datasets)
    Widget? legend;
    if (datasets.length > 1) {
      legend = Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var d = 0; d < datasets.length; d++) ...[
              if (d > 0) const SizedBox(width: 16),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: parseColor(
                    (datasets[d] as Map<String, dynamic>)['color'] as String?,
                    paletteColorOf(context, d, cs.primary),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                (datasets[d] as Map<String, dynamic>)['label'] as String? ??
                    'Series ${d + 1}',
                style: TextStyle(fontSize: 11, color: labelColor),
              ),
            ],
          ],
        ),
      );
    }

    return AgArtifactCard(
      title: title,
      type: 'Radar',
      icon: Icons.radar_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: RadarChart(
              RadarChartData(
                dataSets: dataSets,
                radarBackgroundColor: Colors.transparent,
                radarShape: RadarShape.polygon,
                gridBorderData: BorderSide(color: gridColor, width: 1),
                radarBorderData:
                    BorderSide(color: gridColor.withValues(alpha: 0.6)),
                tickBorderData:
                    BorderSide(color: gridColor.withValues(alpha: 0.3)),
                ticksTextStyle: TextStyle(
                  fontSize: 8,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
                titleTextStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
                titlePositionPercentageOffset: 0.12,
                tickCount: 4,
                getTitle: (index, angle) {
                  if (index >= labels.length) {
                    return const RadarChartTitle(text: '');
                  }
                  return RadarChartTitle(text: labels[index], angle: 0);
                },
              ),
            ),
          ),
          if (legend != null) legend,
        ],
      ),
    );
  }
}
