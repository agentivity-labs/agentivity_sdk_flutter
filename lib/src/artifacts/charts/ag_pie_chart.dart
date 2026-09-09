import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../shared/color_utils.dart';
import '../shell/ag_artifact_card.dart';

/// Pie / donut chart artifact.
///
/// Agent props:
/// ```json
/// {
///   "title": "Market share",
///   "sections": [
///     { "label": "Product A", "value": 40, "color": "#3b82f6" },
///     { "label": "Product B", "value": 35, "color": "#10b981" },
///     { "label": "Product C", "value": 25, "color": "#f59e0b" }
///   ],
///   "donut": true,
///   "height": 220
/// }
/// ```
class AgPieChart extends StatefulWidget {
  const AgPieChart({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  State<AgPieChart> createState() => _AgPieChartState();
}

class _AgPieChartState extends State<AgPieChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.props['title'] as String? ?? 'Pie Chart';
    final sections = (widget.props['sections'] as List?) ?? [];
    final donut = widget.props['donut'] as bool? ?? false;
    final height = (widget.props['height'] as num?)?.toDouble() ?? 220;

    final piesections = <PieChartSectionData>[];
    for (var i = 0; i < sections.length; i++) {
      final s = sections[i] as Map<String, dynamic>;
      final color = parseColor(s['color'] as String?, paletteColorOf(context, i, cs.primary));
      final value = (s['value'] as num?)?.toDouble() ?? 0;
      final isTouched = i == _touched;

      piesections.add(PieChartSectionData(
        value: value,
        color: color,
        radius: isTouched ? 60 : 50,
        title: isTouched ? '$value%' : '',
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
      ));
    }

    return AgArtifactCard(
      title: title,
      type: donut ? 'Donut Chart' : 'Pie Chart',
      icon: Icons.pie_chart_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: PieChart(
              PieChartData(
                sections: piesections,
                centerSpaceRadius: donut ? 48 : 0,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touched = -1;
                        return;
                      }
                      _touched = response.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < sections.length; i++)
                _LegendItem(
                  color: parseColor(
                    (sections[i] as Map<String, dynamic>)['color'] as String?,
                    paletteColor(i, cs.primary),
                  ),
                  label: (sections[i] as Map<String, dynamic>)['label'] as String? ?? '',
                  value: (sections[i] as Map<String, dynamic>)['value'],
                  cs: cs,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.cs,
  });
  final Color color;
  final String label;
  final dynamic value;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label${value != null ? ' · $value%' : ''}',
          style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}
