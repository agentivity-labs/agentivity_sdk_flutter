import '../../core/http_core.dart';
import '../domain/agent_models.dart';
import '../domain/entity_models.dart';
import '../domain/team_folder_models.dart';
import '../domain/workflow_models.dart';

/// Discovery endpoints for agents, teams, and workflows.
///
/// Part of the lightweight [AgentivityClient] — no write operations.
class EntitiesApi {
  EntitiesApi(this._c);
  final AgentivityHttpCore _c;

  // ---------------------------------------------------------------------------
  // Entity catalog
  // GET /api/v1/entities?kind=agent|team|WorkflowEntity
  // ---------------------------------------------------------------------------

  Future<List<EntityUnit>> fetchEntities({String? kind}) async {
    final queryParameters = <String, dynamic>{
      if (kind != null && kind.trim().isNotEmpty) 'kind': kind.trim(),
    };
    final response = await _c.get<List<dynamic>>(
      AgentivityHttpCore.v1('/entities'),
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final data = response.data ?? const <dynamic>[];
    return data.whereType<Object>().map((e) {
      final map = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      return EntityUnit.fromJson(map);
    }).toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Agentic browse (read-only discovery)
  // GET /api/v1/agentic/browse
  // ---------------------------------------------------------------------------

  Future<AgenticBrowseLevel> fetchAgenticBrowseLevel({String? folderId}) async {
    final normalizedFolderId = _c.normalizeNullableId(folderId);
    final response = await _c.get<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/agentic/browse'),
      queryParameters: <String, dynamic>{
        if (normalizedFolderId != null) 'folderId': normalizedFolderId,
      },
    );
    final payload = response.data ?? const <String, dynamic>{};
    final currentPayload = payload['current'];
    final foldersPayload = payload['folders'];
    final itemsPayload = payload['items'];

    final current = currentPayload is Map<String, dynamic>
        ? AgenticBrowseCurrent.fromJson(currentPayload)
        : currentPayload is Map
            ? AgenticBrowseCurrent.fromJson(Map<String, dynamic>.from(currentPayload))
            : const AgenticBrowseCurrent(folderId: null, name: null, isRoot: true);

    AgenticFolder folderFromJson(Object? e) {
      final raw = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      return AgenticFolder.fromJson(raw);
    }

    final folders = (foldersPayload is List ? foldersPayload : const <dynamic>[]).whereType<Object>().map(folderFromJson).toList(growable: false);

    final items = (itemsPayload is List ? itemsPayload : const <dynamic>[])
        .whereType<Object>()
        .map((e) => CatalogBrowseItem.fromJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
            ))
        .toList(growable: false);

    return AgenticBrowseLevel(current: current, folders: folders, items: items);
  }

  // ---------------------------------------------------------------------------
  // Direct listing endpoints
  // ---------------------------------------------------------------------------

  Future<List<AgentSummary>> fetchAgentsList({String? folderId}) async {
    final response = await _c.get<dynamic>(
      AgentivityHttpCore.v1('/agentic/agents'),
      queryParameters: folderId != null ? <String, dynamic>{'folderId': folderId.trim()} : null,
    );
    final raw = response.data;
    final items = raw is List ? raw : (raw is Map ? raw['items'] as List<dynamic>? ?? const <dynamic>[] : const <dynamic>[]);
    return items
        .whereType<Object>()
        .map((e) => AgentSummary.fromJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
            ))
        .toList(growable: false);
  }

  Future<List<Team>> fetchTeamsList({String? folderId}) async {
    final response = await _c.get<dynamic>(
      AgentivityHttpCore.v1('/agentic/teams'),
      queryParameters: folderId != null ? <String, dynamic>{'folderId': folderId.trim()} : null,
    );
    final raw = response.data;
    final items = raw is List ? raw : (raw is Map ? raw['items'] as List<dynamic>? ?? const <dynamic>[] : const <dynamic>[]);
    return items
        .whereType<Object>()
        .map((e) => Team.fromJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
            ))
        .toList(growable: false);
  }

  Future<List<WorkflowEntity>> fetchWorkflows() async {
    final response = await _c.get<List<dynamic>>(AgentivityHttpCore.v1('/workflows'));
    final data = response.data ?? const <dynamic>[];
    final result = <WorkflowEntity>[];
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        result.add(WorkflowEntity.fromJson(item));
      } else if (item is Map) {
        result.add(WorkflowEntity.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return result;
  }

  Future<WorkflowEntity> fetchWorkflow(String id) async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/workflows/$id'));
    final data = response.data ?? const <String, dynamic>{};
    return WorkflowEntity.fromJson(data, fallbackId: id);
  }
}
