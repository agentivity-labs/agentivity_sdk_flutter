/// agentivity_artifacts — Flutter widgets for AI agent artifacts.
///
/// Drop-in widgets for rendering charts, metrics, code, JSON, math and SVG
/// produced by AI agents via the AG-UI protocol.
///
/// ## Quick start (with agentivity_ag_ui)
///
/// ```dart
/// import 'package:agentivity_artifacts/agentivity_artifacts.dart';
///
/// AgUiGenerativeView(
///   controller: AgUiGenerativeController(
///     events: channel.events,
///     widgetRegistry: AgArtifactsBundle.registry(
///       extra: {'MyCard': (context, props) => MyCard(props: props)},
///     ),
///   ),
///   registry: AgArtifactsBundle.registry(),
/// )
/// ```
///
/// ## Theming
///
/// Wrap your app (or any subtree) with [AgArtifactsTheme] to control
/// chart colours, card radius, code font, and more:
///
/// ```dart
/// AgArtifactsTheme(
///   data: AgArtifactsThemeData(
///     chartPalette: ['#6366f1', '#10b981', '#f59e0b'],
///     cardRadius: 8,
///   ),
///   child: MaterialApp(...),
/// )
/// ```
library agentivity_artifacts;

// Theme
export 'src/theme/ag_artifacts_theme.dart';
export 'src/theme/ag_artifacts_themes.dart';

// Shell
export 'src/shell/ag_artifact_card.dart';
export 'src/shell/ag_artifact_viewer.dart';

// Charts
export 'src/charts/ag_bar_chart.dart';
export 'src/charts/ag_line_chart.dart';
export 'src/charts/ag_pie_chart.dart';
export 'src/charts/ag_area_chart.dart';
export 'src/charts/ag_radar_chart.dart';

// Data
export 'src/data/ag_metric_card.dart';
export 'src/data/ag_stat_grid.dart';
export 'src/data/ag_key_value.dart';

// Code
export 'src/code/ag_code_block.dart';
export 'src/code/ag_json_viewer.dart';

// Status
export 'src/status/ag_status_card.dart';
export 'src/status/ag_timeline.dart';

// Math & SVG
export 'src/math/ag_latex.dart';
export 'src/svg/ag_svg.dart';

// Registry + AG-UI bundle
export 'src/registry.dart';
export 'src/ag_ui/ag_artifacts_bundle.dart';
