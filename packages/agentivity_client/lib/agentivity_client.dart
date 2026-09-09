import 'src/app_client/agentivity_client.dart';
import 'src/extras/api/ag_ui_bundles_api.dart';
import 'src/extras/api/chat_context_api.dart';
import 'src/extras/api/svg_icons_api.dart';

export 'src/app_client/agentivity_client.dart';
export 'src/app_client/api/agentic_folders_api.dart';
export 'src/app_client/api/conversations_api.dart';
export 'src/app_client/api/entities_api.dart';
export 'src/app_client/api/runs_api.dart';
export 'src/app_client/domain/agent_models.dart';
export 'src/app_client/domain/agentivity_entity.dart';
export 'src/app_client/domain/canvas_annotation_shared.dart';
export 'src/app_client/domain/chat_models.dart';
export 'src/app_client/domain/entity_models.dart';
export 'src/app_client/domain/execution_models.dart';
export 'src/app_client/domain/interaction_models.dart';
export 'src/app_client/domain/team_folder_models.dart';
export 'src/app_client/domain/workflow_annotation_palette.dart';
export 'src/app_client/domain/workflow_argument_type.dart';
export 'src/app_client/domain/workflow_models.dart';
export 'src/core/api_contract.dart';
export 'src/core/http_core.dart';
export 'src/extras/api/ag_ui_bundles_api.dart';
export 'src/extras/api/chat_context_api.dart';
export 'src/extras/api/svg_icons_api.dart';
export 'src/extras/domain/ag_ui_bundle_models.dart';

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
  }

  /// AG-UI chat channel: open a streaming run against a chat context/thread.
  late final ChatContextApi chat;

  /// AG-UI widget bundle discovery — for apps that render generative UI.
  late final AgUiBundlesApi agUiBundles;

  /// Icon assets (node icons, brand icons, embedded icons) as SVG.
  late final SvgIconsApi svgIcons;
}
