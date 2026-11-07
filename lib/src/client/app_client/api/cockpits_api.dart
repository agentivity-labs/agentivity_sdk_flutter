import '../../core/http_core.dart';
import '../domain/cockpit_models.dart';

/// The cockpits of Agentivity Desk as the Studio builds them: made, drafted, published, owned, ordered and deleted. Who manages the
/// cockpits does it all; an owner of a cockpit changes and publishes that one. The Desk reads them with [DeskApi.cockpit].
///
/// Part of [AgentivityPlatformClient].
class CockpitsApi {
  CockpitsApi(this._c);
  final AgentivityHttpCore _c;

  static String _path(String id, [String suffix = '']) => AgentivityHttpCore.v1('/cockpits/${Uri.encodeComponent(id)}$suffix');

  ManagedCockpit _one(dynamic data) => ManagedCockpit.fromJson(data is Map ? Map<String, dynamic>.from(data) : const {});

  /// The cockpits the caller may change: all of them for who manages them, else those they own.
  // GET /api/v1/cockpits
  Future<ManagedCockpits> list() async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/cockpits'));
    return ManagedCockpits.fromJson(response.data ?? const {});
  }

  /// A new cockpit, not published yet: the page of the Desk as it is by default.
  // POST /api/v1/cockpits
  Future<ManagedCockpit> create({required String name, String? colour}) async =>
      _one((await _c.post<dynamic>(AgentivityHttpCore.v1('/cockpits'), data: {'name': name, if (colour != null) 'colour': colour})).data);

  // GET /api/v1/cockpits/{id}
  Future<ManagedCockpit> get(String id) async => _one((await _c.get<dynamic>(_path(id))).data);

  /// Keeps the draft: the Desk still shows what is published.
  // PUT /api/v1/cockpits/{id}/draft
  Future<ManagedCockpit> saveDraft(String id, CockpitContent content) async => _one((await _c.put<dynamic>(_path(id, '/draft'), data: content.toJson())).data);

  /// The draft becomes what the Desk shows.
  // POST /api/v1/cockpits/{id}/publish
  Future<ManagedCockpit> publish(String id) async => _one((await _c.post<dynamic>(_path(id, '/publish'))).data);

  /// The draft goes back to what is published.
  // POST /api/v1/cockpits/{id}/discard
  Future<ManagedCockpit> discard(String id) async => _one((await _c.post<dynamic>(_path(id, '/discard'))).data);

  /// The Desk no longer shows the cockpit; its draft stays.
  // POST /api/v1/cockpits/{id}/unpublish
  Future<ManagedCockpit> unpublish(String id) async => _one((await _c.post<dynamic>(_path(id, '/unpublish'))).data);

  /// Who changes and publishes it besides who manages the cockpits: each by their id or their e-mail.
  // PUT /api/v1/cockpits/{id}/owners
  Future<ManagedCockpit> setOwners(String id, List<String> owners) async => _one((await _c.put<dynamic>(_path(id, '/owners'), data: {'owners': owners})).data);

  /// The cockpits in the order the Desk lists them.
  // PUT /api/v1/cockpits/order
  Future<ManagedCockpits> reorder(List<String> ids) async {
    final response = await _c.put<Map<String, dynamic>>(AgentivityHttpCore.v1('/cockpits/order'), data: {'ids': ids});
    return ManagedCockpits.fromJson(response.data ?? const {});
  }

  // DELETE /api/v1/cockpits/{id}
  Future<void> delete(String id) async {
    await _c.delete<dynamic>(_path(id));
  }
}
