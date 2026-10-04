import 'package:dio/dio.dart';

import '../core/connection_monitor.dart';
import '../core/http_core.dart';
import 'api/entities_api.dart';
import 'api/runs_api.dart';
import 'api/conversations_api.dart';
import 'api/agentic_folders_api.dart';
import 'api/data_tables_api.dart';
import 'api/icons_api.dart';

export '../core/connection_monitor.dart';
export '../core/http_core.dart';
export 'api/entities_api.dart';
export 'api/runs_api.dart';
export 'api/conversations_api.dart';
export 'api/agentic_folders_api.dart';
export 'api/data_tables_api.dart';
export 'api/icons_api.dart';

/// Lightweight Agentivity client intended for publication on pub.dev.
///
/// Covers discovery, run lifecycle, HIL, and conversation history — everything
/// needed to build an agentive application on top of an Agentivity backend
/// without depending on Studio-only management features.
///
/// ## Usage
/// ```dart
/// final client = AgentivityClient(baseUrl: 'https://my-backend.example.com');
/// final entities = await client.entities.fetchEntities(kind: 'agent');
/// final run = await client.runs.startRun(entityId: entities.first.id, input: 'Hello');
/// ```
class AgentivityClient {
  AgentivityClient({Dio? dio, required String baseUrl}) : this._(dio, baseUrl, ConnectionMonitor());

  AgentivityClient._(Dio? dio, String baseUrl, this.connection) : _http = AgentivityHttpCore(dio: dio, baseUrl: baseUrl, monitor: connection) {
    connection.probe = _http.probe;
    entities = EntitiesApi(_http);
    runs = RunsApi(_http);
    conversations = ConversationsApi(_http);
    agenticFolders = AgenticFoldersApi(_http);
    dataTables = DataTablesApi(_http);
    icons = IconsApi(_http);
  }

  final AgentivityHttpCore _http;

  /// Whether the server can be reached, and when the next attempt is — what [AgUiConnectionNotice] shows.
  final ConnectionMonitor connection;

  /// Exposes the underlying HTTP core for Studio sub-classes to initialize
  /// their additional [*Api] components using the same transport.
  AgentivityHttpCore get http => _http;

  /// Entity discovery: list and browse agents, teams, and workflows.
  late final EntitiesApi entities;

  /// The catalog of icons a user can choose from (any icon picker reads it).
  late final IconsApi icons;

  /// Run lifecycle: start runs, manage HIL, send interactions, open SSE streams.
  late final RunsApi runs;

  /// Conversation history: execution threads and messages.
  late final ConversationsApi conversations;

  /// Agentic folder management: create, rename, move, and delete folders.
  late final AgenticFoldersApi agenticFolders;

  /// Shared Data Table rows — read what a Team's workflow wrote, or write back
  /// where the app owns the data. Schema/folders/versions are Studio-only.
  late final DataTablesApi dataTables;
}
