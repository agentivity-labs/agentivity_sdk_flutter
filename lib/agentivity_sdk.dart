/// agentivity_sdk — the Flutter/Dart SDK for building applications against
/// the Agentivity platform.
///
/// Three things, one package:
/// - **AG-UI protocol client** — SSE streaming, chat/forms/assistant panels, run controllers.
/// - **Artifact widgets** — renderable generative-UI content (charts, code, interaction cards, ...).
/// - **Platform API client** — read, execute, and watch history for agents/teams/workflows/chat.
///
/// ## Quick start
///
/// ```dart
/// import 'package:agentivity_sdk/agentivity_sdk.dart';
///
/// final client = AgentivityPlatformClient(baseUrl: 'https://my-backend.example.com');
/// final agents = await client.entities.fetchEntities(kind: 'agent');
///
/// AgUiChatDiscussion(
///   controller: ChatController(chatContextApi: client.chat, entityId: agents.first.id),
///   widgetRegistry: AgArtifactsBundle.registry(),
/// );
/// ```
///
/// **Scope**: read, execute, and watch history. Creating or editing workflows, agents, teams, or
/// credentials is an Agentivity Studio (admin) concern and deliberately not exposed here.
library agentivity_sdk;

// ── AG-UI: json helpers ─────────────────────────────────────────────────────
export 'src/ag_ui/shared/json_helpers.dart';
export 'src/util/retry.dart';

// ── AG-UI: theme ─────────────────────────────────────────────────────────────
export 'src/ag_ui/theme/ag_theme_data.dart';
export 'src/ag_ui/theme/ag_accent_colors.dart';

// ── AG-UI: protocol ──────────────────────────────────────────────────────────
export 'src/ag_ui/protocol/ag_ui_sse_channel.dart';
export 'src/ag_ui/protocol/ag_ui_protocol.dart';
export 'src/ag_ui/protocol/ag_ui_run_stream.dart';
export 'src/ag_ui/protocol/platform_stream.dart';
export 'src/ag_ui/protocol/ag_ui_state_controller.dart';
export 'src/ag_ui/protocol/api_contract.dart'
    hide ApiException, userFacingErrorMessage, debugLogApiIssue, throwIfApiFailurePayload, apiHttpStatus;
export 'src/ag_ui/protocol/run_agent_input.dart';

// ── AG-UI: tools ─────────────────────────────────────────────────────────────
export 'src/ag_ui/tools/ag_ui_frontend_tool.dart';
export 'src/ag_ui/tools/ag_ui_widget_registry.dart';

// ── AG-UI: widgets ───────────────────────────────────────────────────────────
export 'src/ag_ui/widgets/ag_ui_markdown_body.dart';
export 'src/ag_ui/widgets/ag_ui_connection_status_banner.dart';

// ── AG-UI: panels — chat ─────────────────────────────────────────────────────
export 'src/ag_ui/panels/chat/chat_models.dart';
export 'src/ag_ui/panels/chat/chat_controller.dart';
export 'src/ag_ui/panels/chat/i_chat_provider.dart';
export 'src/ag_ui/panels/chat/chat_theme.dart';
export 'src/ag_ui/panels/chat/ag_ui_chat_input.dart';
export 'src/ag_ui/panels/chat/ag_ui_chat_discussion.dart';
export 'src/ag_ui/panels/chat/member_avatar.dart';
export 'src/ag_ui/panels/chat/run_error.dart';
export 'src/ag_ui/panels/chat/connection_notice.dart';
export 'src/ag_ui/panels/chat/team_appearance.dart';
export 'src/ag_ui/panels/chat/team_topology.dart';
export 'src/icons/icon_ref.dart';
export 'src/ag_ui/panels/chat/team_views.dart';
export 'src/ag_ui/panels/chat/workflow_graph_layout.dart' show WorkflowLayout, layoutWorkflowGraph;
export 'src/ag_ui/panels/chat/workflow_views.dart';
export 'src/ag_ui/panels/chat/execution_statuses_controller.dart';

// ── AG-UI: panels — assistant ────────────────────────────────────────────────
export 'src/ag_ui/panels/assistant/assistant_models.dart';
export 'src/ag_ui/panels/assistant/assistant_controller.dart';
export 'src/ag_ui/panels/assistant/i_assistant_provider.dart';
export 'src/ag_ui/panels/assistant/assistant_theme.dart';
export 'src/ag_ui/panels/assistant/ag_ui_assistant_panel.dart';

// ── AG-UI: panels — forms ─────────────────────────────────────────────────────
export 'src/ag_ui/panels/forms/form_models.dart';
export 'src/ag_ui/panels/forms/form_controller.dart';
export 'src/ag_ui/panels/forms/i_form_provider.dart';
export 'src/ag_ui/panels/forms/form_theme.dart';
export 'src/ag_ui/panels/forms/ag_ui_form_panel.dart';

// ── AG-UI: agent ──────────────────────────────────────────────────────────────
export 'src/ag_ui/agent/agent_run_models.dart' hide AgentEntity, AgentEntityPort;
export 'src/ag_ui/agent/agent_run_controller.dart';
export 'src/ag_ui/agent/i_agent_run_provider.dart';
export 'src/ag_ui/agent/ag_ui_run_status.dart';
export 'src/ag_ui/agent/ag_ui_generative_controller.dart';
export 'src/ag_ui/agent/ag_ui_generative_view.dart';
export 'src/ag_ui/agent/ag_ui_run_lifecycle_controller.dart';
export 'src/ag_ui/agent/ag_ui_activity_controller.dart';
export 'src/ag_ui/agent/ag_ui_context_registry.dart';
export 'src/ag_ui/agent/ag_ui_platform_run_controller.dart';

// ── AG-UI: connectors — pre-built backends ───────────────────────────────────
export 'src/ag_ui/connectors/ag_ui_generic_connector.dart';
export 'src/ag_ui/connectors/agentivity_connector.dart';
export 'src/ag_ui/connectors/agentivity_platform_connector.dart';
export 'src/ag_ui/connectors/agentivity_run_stream.dart';
export 'src/ag_ui/connectors/agentivity_signals.dart';
export 'src/ag_ui/connectors/lang_graph_connector.dart';

// ── Artifacts: theme ──────────────────────────────────────────────────────────
export 'src/artifacts/theme/ag_artifacts_theme.dart';
export 'src/artifacts/theme/ag_artifacts_themes.dart';

// ── Artifacts: shell ──────────────────────────────────────────────────────────
export 'src/artifacts/shell/ag_artifact_card.dart';
export 'src/artifacts/shell/ag_artifact_viewer.dart';

// ── Artifacts: charts ─────────────────────────────────────────────────────────
export 'src/artifacts/charts/ag_bar_chart.dart';
export 'src/artifacts/charts/ag_line_chart.dart';
export 'src/artifacts/charts/ag_pie_chart.dart';
export 'src/artifacts/charts/ag_area_chart.dart';
export 'src/artifacts/charts/ag_radar_chart.dart';

// ── Artifacts: data ───────────────────────────────────────────────────────────
export 'src/artifacts/data/ag_metric_card.dart';
export 'src/artifacts/data/ag_stat_grid.dart';
export 'src/artifacts/data/ag_key_value.dart';

// ── Artifacts: code ───────────────────────────────────────────────────────────
export 'src/artifacts/code/ag_code_block.dart';
export 'src/artifacts/code/ag_json_viewer.dart';

// ── Artifacts: interaction ────────────────────────────────────────────────────
export 'src/artifacts/interaction/ag_choice_card.dart';
export 'src/artifacts/interaction/ag_confirm_card.dart';
export 'src/artifacts/interaction/ag_date_picker_card.dart';
export 'src/artifacts/interaction/ag_question_form.dart';
export 'src/artifacts/interaction/ag_rating_card.dart';
export 'src/artifacts/interaction/ag_summary_card.dart';
export 'src/artifacts/interaction/ag_source_input.dart';
export 'src/artifacts/media/ag_image_gallery.dart';
export 'src/artifacts/shell/ag_artifact_image.dart';

// ── Artifacts: status ─────────────────────────────────────────────────────────
export 'src/artifacts/status/ag_status_card.dart';
export 'src/artifacts/status/ag_timeline.dart';

// ── Artifacts: math & SVG ──────────────────────────────────────────────────────
export 'src/artifacts/math/ag_latex.dart';
export 'src/artifacts/svg/ag_svg.dart';

// ── Artifacts: registry + AG-UI bundle ─────────────────────────────────────────
export 'src/artifacts/registry.dart';
export 'src/artifacts/ag_ui/ag_artifacts_bundle.dart';

// ── Client: platform API client ────────────────────────────────────────────────
export 'src/client/app_client/agentivity_client.dart';
export 'src/client/app_client/api/agentic_folders_api.dart';
export 'src/client/app_client/api/conversations_api.dart';
export 'src/client/app_client/api/entities_api.dart';
export 'src/client/app_client/api/runs_api.dart';
export 'src/client/app_client/api/voice_api.dart';
export 'src/client/app_client/api/uploads_api.dart';
export 'src/client/app_client/domain/agent_models.dart';
export 'src/client/app_client/domain/agentivity_entity.dart';
export 'src/client/app_client/domain/canvas_annotation_shared.dart';
export 'src/client/app_client/domain/chat_models.dart';
export 'src/client/app_client/domain/entity_models.dart';
export 'src/client/app_client/domain/execution_models.dart';
export 'src/client/app_client/domain/interaction_models.dart';
export 'src/client/app_client/domain/team_definition_models.dart';
export 'src/client/app_client/domain/icon_catalog_models.dart';
export 'src/client/app_client/domain/team_folder_models.dart';
export 'src/client/app_client/domain/workflow_annotation_palette.dart';
export 'src/client/app_client/domain/workflow_argument_type.dart';
export 'src/client/app_client/domain/workflow_models.dart';
export 'src/client/app_client/domain/workflow_graph_models.dart';
export 'src/client/app_client/domain/execution_status_models.dart';
export 'src/client/core/api_contract.dart';
export 'src/client/core/http_core.dart';
export 'src/client/extras/api/ag_ui_bundles_api.dart';
export 'src/client/extras/api/chat_context_api.dart';
export 'src/client/extras/api/svg_icons_api.dart';
export 'src/client/extras/domain/ag_ui_bundle_models.dart';

import 'src/client/app_client/agentivity_client.dart';
import 'src/client/app_client/api/uploads_api.dart';
import 'src/client/app_client/api/voice_api.dart';
import 'src/client/extras/api/ag_ui_bundles_api.dart';
import 'src/client/extras/api/chat_context_api.dart';
import 'src/client/extras/api/svg_icons_api.dart';

/// The full Agentivity platform client: everything in [AgentivityClient]
/// (entities, generic run lifecycle, HIL, conversations, folders) plus the
/// AG-UI chat channel, AG-UI widget bundle discovery, and icon assets.
///
/// **Scope**: read, execute, and watch history. Creating or editing
/// workflows, agents, teams, or credentials is a Studio (admin) concern and
/// deliberately not exposed here — see the package description.
///
/// ## Usage
/// ```dart
/// final client = AgentivityPlatformClient(baseUrl: 'https://my-backend.example.com');
/// final agents = await client.entities.fetchEntities(kind: 'agent');
/// final run = await client.runs.startExecution(entityId: agents.first.id, input: 'Hello');
/// ```
class AgentivityPlatformClient extends AgentivityClient {
  AgentivityPlatformClient({super.dio, required super.baseUrl}) {
    chat = ChatContextApi(http);
    agUiBundles = AgUiBundlesApi(http);
    svgIcons = SvgIconsApi(http);
    voice = VoiceApi(http);
    uploads = UploadsApi(http);
  }

  /// AG-UI chat channel: open a streaming run against a chat context/thread.
  late final ChatContextApi chat;

  /// AG-UI widget bundle discovery — for apps that render generative UI.
  late final AgUiBundlesApi agUiBundles;

  /// Icon assets (node icons, brand icons, embedded icons) as SVG.
  late final SvgIconsApi svgIcons;

  /// Server-side voice transcription for chat dictation.
  late final VoiceApi voice;

  /// File uploads: hand a run a document (a CV, a contract…) it can read later by id.
  late final UploadsApi uploads;
}
