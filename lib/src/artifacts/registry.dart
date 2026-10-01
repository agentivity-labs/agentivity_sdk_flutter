import '../ag_ui/tools/ag_ui_widget_registry.dart';

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
import 'interaction/ag_choice_card.dart';
import 'interaction/ag_confirm_card.dart';
import 'interaction/ag_date_picker_card.dart';
import 'interaction/ag_question_form.dart';
import 'interaction/ag_rating_card.dart';
import 'interaction/ag_summary_card.dart';
import 'interaction/ag_source_input.dart';
import 'math/ag_latex.dart';
import 'status/ag_status_card.dart';
import 'status/ag_timeline.dart';
import 'svg/ag_svg.dart';

/// Re-export [AgUiComponentBuilder] so callers only need to import this package.
///
/// Signature: `Widget Function(BuildContext context, Map<String, dynamic> props)`
export '../ag_ui/tools/ag_ui_widget_registry.dart' show AgUiComponentBuilder;

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

    // Interaction
    'QuestionForm':   (context, p) => AgQuestionForm(props: p),
    'ChoiceCard':     (context, p) => AgChoiceCard(props: p),
    'ConfirmCard':    (context, p) => AgConfirmCard(props: p),
    'RatingCard':     (context, p) => AgRatingCard(props: p),
    'DatePickerCard': (context, p) => AgDatePickerCard(props: p),
    'SummaryCard':    (context, p) => AgSummaryCard(props: p),
    'SourceInput':    (context, p) => AgSourceInput(props: p),
  };
}
