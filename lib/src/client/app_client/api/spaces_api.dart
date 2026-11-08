import '../../core/http_core.dart';
import '../domain/space_models.dart';

/// The spaces a person is in, and the one they work in: the same choice for the Studio and the Desk (the instance keeps it).
///
/// Part of [AgentivityPlatformClient].
class SpacesApi {
  SpacesApi(this._c);
  final AgentivityHttpCore _c;

  // GET /api/v1/spaces
  /// The spaces the person is in, the one they work in marked [WorkspaceSpace.isCurrent]. An instance without spaces answers
  /// with its one space, or refuses: then there is nothing to choose.
  Future<List<WorkspaceSpace>> list() async {
    final response = await _c.get<List<dynamic>>(AgentivityHttpCore.v1('/spaces'));
    return [
      for (final item in response.data ?? const [])
        if (item is Map) WorkspaceSpace.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  // PUT /api/v1/spaces/current
  /// Works in [spaceId] from now on: what is listed after shows only it.
  Future<void> choose(String spaceId) => _c.put<void>(AgentivityHttpCore.v1('/spaces/current'), data: {'spaceId': spaceId});
}
