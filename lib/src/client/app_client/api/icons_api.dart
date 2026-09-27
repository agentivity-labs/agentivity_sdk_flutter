import '../../core/http_core.dart';
import '../domain/icon_catalog_models.dart';

/// The catalog of icons a user can choose from. Generic — organised by icon set — so it serves any screen with an icon picker.
class IconsApi {
  IconsApi(this._c);
  final AgentivityHttpCore _c;

  /// The icons of a set (all sets when [type] is omitted), optionally narrowed by search text [q] (matched against the Material name).
  /// GET /api/v1/icons?type=material&q=hotel
  Future<List<IconInfo>> fetchIcons({
    String? type,
    String? q,
  }) async {
    final query = <String, dynamic>{
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };
    final response = await _c.get<List<dynamic>>(
      AgentivityHttpCore.v1('/icons'),
      queryParameters: query.isEmpty ? null : query,
    );
    return (response.data ?? const <dynamic>[])
        .whereType<Map>()
        .map((e) => IconInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}
