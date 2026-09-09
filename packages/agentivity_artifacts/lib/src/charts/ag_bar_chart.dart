import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../shared/color_utils.dart';
import '../shell/ag_artifact_card.dart';

/// Bar chart artifact.
///
/// Agent props:
/// ```json
/// {
///   "title": "Revenue by quarter",
///   "labels": ["Q1", "Q2", "Q3", "Q4"],
///   "datasets": [
///     { "label": "2024", "data": [120, 145, 98, 210], "color": "#3b82f6" }
///   ],
///   "yLabel": "USD (k)",
///   "horizontal": false,
///   "height": 220
/// }
/// ```
class AgBarChart extends StatelessWidget {
  const AgBarChart({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = props['title'] as String? ?? 'Bar Chart';
    final labels = (props['labels'] as List?)?.cast<String>() ?? [];
    final datasets = (props['datasets'] as List?) ?? [];
    final height = (props['height'] as num?)?.toDouble() ?? 220;

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < labels.length; i++) {
      final rods = <BarChartRodData>[];
      for (var d = 0; d < datasets.length; d++) {
        final ds = datasets[d] as Map<String, dynamic>;
        final data = (ds['data'] as List?)?.cast<num>() ?? [];
        final color = parseColor(ds['color'] as String?, paletteColorOf(context, d, cs.primary));
        if (i < data.length) {
          rods.add(BarChartRodData(
            toY: data[i].toDouble(),
            color: color,
            width: datasets.length > 1 ? 10 : 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ));
        }
      }
      groups.add(BarChartGroupData(x: i, barRods: rods, barsSpace: 4));
    }

    final gridLine = FlLine(
      color: cs.outlineVariant.withValues(alpha: 0.5),
      strokeWidth: 1,
    );

    return AgArtifactCard(
      title: title,
      type: 'Bar Chart',
      icon: Icons.bar_chart_rounded,
      child: SizedBox(
        height: height,
        child: BarChart(
          BarChartData(
            barGroups: groups,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => gridLine,
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) =>
                    cs.surfaceContainerHighest,
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (v, m) => Text(
                    m.formattedValue,
                    style: TextStyle(
                      fontSize: 9,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
          ),
        ),
      ),
    );
  }
}
