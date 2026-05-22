import 'package:agentivity_ag_ui/agentivity_ag_ui.dart';

import 'charts/ag_area_chart.dart';
import 'charts/ag_bar_chart.dart';
import 'charts/ag_line_chart.dart';
import 'charts/ag_pie_chart.dart';
import 'charts/ag_radar_chart.dart';
import 'code/ag_code_block.dart';
import 'code/ag_json_viewer.dart';
import 'data/ag_key_value.dart';
import 'data/ag_metric_card.dart';
import 'data/ag_stat_grid.dart';
import 'math/ag_latex.dart';
import 'status/ag_status_card.dart';
import 'status/ag_timeline.dart';
import 'svg/ag_svg.dart';

/// Re-export [AgUiComponentBuilder] so callers only need to import this package.
///
/// Signature: `Widget Function(BuildContext context, Map<String, dynamic> props)`
export 'package:agentivity_ag_ui/agentivity_ag_ui.dart'
    show AgUiComponentBuilder;

/// Returns the built-in type → builder map, following the Flutter
/// [AgUiComponentBuilder] convention (context + props).
///
/// Use [AgArtifactsBundle.registry] to get a ready-to-use [AgUiWidgetRegistry]
/// instead of wiring this map manually.
Map<String, AgUiComponentBuilder> buildArtifactsRegistry() {
  return {
    // Charts
    'BarChart':   (context, p) => AgBarChart(props: p),
    'LineChart':  (context, p) => AgLineChart(props: p),
    'PieChart':   (context, p) => AgPieChart(props: p),
    'AreaChart':  (context, p) => AgAreaChart(props: p),
    'RadarChart': (context, p) => AgRadarChart(props: p),

    // Data
    'MetricCard': (context, p) => AgMetricCard(props: p),
    'StatGrid':   (context, p) => AgStatGrid(props: p),
    'KeyValue':   (context, p) => AgKeyValue(props: p),

    // Code
    'CodeBlock':  (context, p) => AgCodeBlock(props: p),
    'JsonViewer': (context, p) => AgJsonViewer(props: p),

    // Status
    'StatusCard': (context, p) => AgStatusCard(props: p),
    'Timeline':   (context, p) => AgTimeline(props: p),

    // Math
    'Latex':      (context, p) => AgLatex(props: p),

    // SVG
    'Svg':        (context, p) => AgSvg(props: p),
  };
}
