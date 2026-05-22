import 'package:agentivity_ag_ui/agentivity_ag_ui.dart';

import '../registry.dart';

/// One-line integration between [agentivity_artifacts] and [agentivity_ag_ui].
///
/// Call [AgArtifactsBundle.registry] to get an [AgUiWidgetRegistry] with all
/// 13 built-in artifact widgets pre-registered. Pass it directly to
/// [AgUiGenerativeController] or [AgUiGenerativeView]:
///
/// ```dart
/// AgUiGenerativeView(
///   controller: AgUiGenerativeController(
///     events: channel.events,
///     widgetRegistry: AgArtifactsBundle.registry(),
///   ),
///   registry: AgArtifactsBundle.registry(),
/// )
/// ```
///
/// ### Adding custom components
///
/// ```dart
/// final registry = AgArtifactsBundle.registry(
///   extra: {
///     'OrderCard': (context, props) => OrderCard(
///       orderId: props['id'] as String,
///       currency: Localizations.localeOf(context).countryCode ?? 'EUR',
///     ),
///   },
/// );
/// ```
///
/// Custom entries in [extra] **override** built-in entries when keys collide,
/// so you can replace any default widget with your own implementation.
class AgArtifactsBundle {
  AgArtifactsBundle._();

  /// Builds an [AgUiWidgetRegistry] containing all built-in artifact widgets.
  ///
  /// - [extra]: additional or override component builders merged on top.
  static AgUiWidgetRegistry registry({
    Map<String, AgUiComponentBuilder> extra = const {},
  }) {
    return AgUiWidgetRegistry({
      ...buildArtifactsRegistry(),
      ...extra,
    });
  }
}
