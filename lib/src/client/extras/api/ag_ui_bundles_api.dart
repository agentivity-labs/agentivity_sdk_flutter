import '../../core/http_core.dart';
import '../domain/ag_ui_bundle_models.dart';

/// AG-UI widget bundle endpoints.
class AgUiBundlesApi {
  AgUiBundlesApi(this._c);
  final AgentivityHttpCore _c;

  Future<List<AgUiBundleSummary>> fetchAgUiBundles() async {
    final response = await _c.get<List<dynamic>>(AgentivityHttpCore.v1('/ag-ui/bundles'));
    final data = response.data ?? const <dynamic>[];
    return data.whereType<Object>().map((e) {
      final map = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      return AgUiBundleSummary.fromJson(map);
    }).toList(growable: false);
  }

  Future<AgUiBundleDetail> fetchAgUiBundle(String bundleId) async {
    final normalizedId = _c.requireNormalizedId(bundleId, label: 'Bundle id');
    final response = await _c.get<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/ag-ui/bundles/$normalizedId'),
    );
    return AgUiBundleDetail.fromJson(response.data ?? const <String, dynamic>{});
  }
}
