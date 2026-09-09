import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../shared/color_utils.dart';
import '../shell/ag_artifact_card.dart';

/// Area (filled line) chart artifact.
///
/// Same props as LineChart but fill defaults to true.
///
/// Agent props:
/// ```json
/// {
///   "title": "Daily active users",
///   "labels": ["Mon", "Tue", "Wed", "Thu", "Fri"],
///   "datasets": [
///     { "label": "DAU", "data": [200, 340, 280, 500, 420], "color": "#8b5cf6" }
///   ],
///   "height": 200
/// }
/// ```
class AgAreaChart extends StatelessWidget {
  const AgAreaChart({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = props['title'] as String? ?? 'Area Chart';
    final labels = (props['labels'] as List?)?.cast<String>() ?? [];
    final datasets = (props['datasets'] as List?) ?? [];
    final height = (props['height'] as num?)?.toDouble() ?? 200;

    final bars = <LineChartBarData>[];
    for (var d = 0; d < datasets.length; d++) {
      final ds = datasets[d] as Map<String, dynamic>;
      final data = (ds['data'] as List?)?.cast<num>() ?? [];
      final color = parseColor(ds['color'] as String?, paletteColorOf(context, d, cs.primary));

      bars.add(LineChartBarData(
        spots: [
          for (var i = 0; i < data.length; i++)
            FlSpot(i.toDouble(), data[i].toDouble()),
        ],
        color: color,
        isCurved: true,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.25),
              color.withValues(alpha: 0.02),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ));
    }

    final gridLine = FlLine(
      color: cs.outlineVariant.withValues(alpha: 0.5),
      strokeWidth: 1,
    );

    return AgArtifactCard(
      title: title,
      type: 'Area Chart',
      icon: Icons.area_chart_rounded,
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
