import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../shared/color_utils.dart';
import '../shell/ag_artifact_card.dart';

/// Line chart artifact.
///
/// Agent props:
/// ```json
/// {
///   "title": "User growth",
///   "labels": ["Jan", "Feb", "Mar", "Apr"],
///   "datasets": [
///     { "label": "Users", "data": [100, 250, 400, 600],
///       "color": "#3b82f6", "smooth": true }
///   ],
///   "height": 220
/// }
/// ```
class AgLineChart extends StatelessWidget {
  const AgLineChart({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = props['title'] as String? ?? 'Line Chart';
    final labels = (props['labels'] as List?)?.cast<String>() ?? [];
    final datasets = (props['datasets'] as List?) ?? [];
    final height = (props['height'] as num?)?.toDouble() ?? 220;

    final bars = <LineChartBarData>[];
    for (var d = 0; d < datasets.length; d++) {
      final ds = datasets[d] as Map<String, dynamic>;
      final data = (ds['data'] as List?)?.cast<num>() ?? [];
      final color = parseColor(ds['color'] as String?, paletteColorOf(context, d, cs.primary));
      final smooth = ds['smooth'] as bool? ?? true;
      final fill = ds['fill'] as bool? ?? false;

      final spots = [
        for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i].toDouble()),
      ];

      bars.add(LineChartBarData(
        spots: spots,
        color: color,
        isCurved: smooth,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: fill
            ? BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              )
            : BarAreaData(show: false),
      ));
    }

    final gridLine = FlLine(
      color: cs.outlineVariant.withValues(alpha: 0.5),
      strokeWidth: 1,
    );

    return AgArtifactCard(
      title: title,
      type: 'Line Chart',
      icon: Icons.show_chart_rounded,
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            lineBarsData: bars,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => gridLine,
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
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
