import '../../core/http_core.dart';
import '../domain/agent_models.dart';

/// Agentic folder management (shared container for agents and teams).
///
/// Part of the lightweight [AgentivityClient].
class AgenticFoldersApi {
  AgenticFoldersApi(this._c);
  final AgentivityHttpCore _c;

  Future<AgenticFolder> createAgenticFolder({
    required String name,
    String? parentFolderId,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw ArgumentError('Folder name is required');
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/agentic/folders'),
      data: <String, dynamic>{
        'name': normalizedName,
        'parentFolderId': _c.normalizeNullableId(parentFolderId),
      },
    );
    return AgenticFolder.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<void> renameAgenticFolder({
    required String folderId,
    required String name,
  }) async {
    final normalizedFolderId = _c.requireNormalizedId(folderId, label: 'Folder id');
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw ArgumentError('Folder name is required');
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/agentic/folders/$normalizedFolderId/rename'),
      data: <String, dynamic>{'name': normalizedName},
    );
    _c.expectSuccessOrEmptyResponse(response.data, operation: 'Rename agentic folder');
  }

  Future<void> deleteAgenticFolder(String folderId) async {
    final normalizedFolderId = _c.requireNormalizedId(folderId, label: 'Folder id');
    await _c.delete<void>(AgentivityHttpCore.v1('/agentic/folders/$normalizedFolderId'));
  }

  Future<void> moveAgenticFolder({
    required String folderId,
    String? targetParentFolderId,
  }) async {
    final normalizedFolderId = _c.requireNormalizedId(folderId, label: 'Folder id');
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/agentic/folders/$normalizedFolderId/move'),
      data: <String, dynamic>{
        'targetParentFolderId': _c.normalizeNullableId(targetParentFolderId),
      },
    );
    _c.expectSuccessOrEmptyResponse(response.data, operation: 'Move agentic folder');
  }
}
