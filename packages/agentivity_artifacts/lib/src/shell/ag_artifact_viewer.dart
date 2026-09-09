import 'package:flutter/material.dart';

import '../charts/ag_area_chart.dart';
import '../charts/ag_bar_chart.dart';
import '../charts/ag_line_chart.dart';
import '../charts/ag_pie_chart.dart';
import '../code/ag_code_block.dart';
import '../code/ag_json_viewer.dart';
import '../data/ag_key_value.dart';
import '../data/ag_metric_card.dart';
import '../data/ag_stat_grid.dart';
import '../math/ag_latex.dart';
import '../status/ag_status_card.dart';
import '../status/ag_timeline.dart';
import '../svg/ag_svg.dart';

/// Auto-routing artifact viewer.
///
/// Resolves [type] to the correct widget and passes [props] to it.
/// Use this in an [AgUiWidgetRegistry] to handle all artifact types at once.
///
/// ```dart
/// AgUiWidgetRegistry({
///   'Artifact': (props) => AgArtifactViewer(
///     type: props['type'] as String,
///     props: props,
///   ),
/// })
/// ```
class AgArtifactViewer extends StatelessWidget {
  const AgArtifactViewer({
    super.key,
    required this.type,
    required this.props,
  });

  final String type;
  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      'BarChart'    => AgBarChart(props: props),
      'LineChart'   => AgLineChart(props: props),
      'PieChart'    => AgPieChart(props: props),
      'AreaChart'   => AgAreaChart(props: props),
      'MetricCard'  => AgMetricCard(props: props),
      'StatGrid'    => AgStatGrid(props: props),
      'KeyValue'    => AgKeyValue(props: props),
      'CodeBlock'   => AgCodeBlock(props: props),
      'JsonViewer'  => AgJsonViewer(props: props),
      'StatusCard'  => AgStatusCard(props: props),
      'Timeline'    => AgTimeline(props: props),
      'Latex'       => AgLatex(props: props),
      'Svg'         => AgSvg(props: props),
      _             => _UnknownArtifact(type: type),
    };
  }
}

class _UnknownArtifact extends StatelessWidget {
  const _UnknownArtifact({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Unknown artifact type: $type',
        style: TextStyle(fontSize: 11, color: cs.error),
      ),
    );
  }
}
