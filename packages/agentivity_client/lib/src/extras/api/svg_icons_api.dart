import 'package:dio/dio.dart';

import '../../core/http_core.dart';

/// SVG icon fetching endpoints.
class SvgIconsApi {
  SvgIconsApi(this._c);
  final AgentivityHttpCore _c;

  Future<String?> fetchSvgFromUrl(String svgUrl) async {
    final path = svgUrl.startsWith('/') ? svgUrl : '/$svgUrl';
    try {
      final response = await _c.dio.get<String>(
        path,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Accept': 'image/svg+xml'},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<String?> fetchNodeIconSvg(String nodeType) async {
    final encoded = Uri.encodeComponent(nodeType.trim());
    try {
      final response = await _c.dio.get<String>(
        AgentivityHttpCore.v1('/metadata/nodes/$encoded/icon.svg'),
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Accept': 'image/svg+xml'},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<String?> fetchBrandIconSvg(String slug) async {
    final encoded = Uri.encodeComponent(slug.trim());
    try {
      final response = await _c.dio.get<String>(
        '/icons/brand/$encoded.svg',
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Accept': 'image/svg+xml'},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<String?> fetchEmbeddedIconSvg(String assembly, String name) async {
    final encodedAssembly = Uri.encodeComponent(assembly.trim());
    final encodedName = Uri.encodeComponent(name.trim());
    try {
      final response = await _c.dio.get<String>(
        '/icons/embedded/$encodedAssembly/$encodedName.svg',
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Accept': 'image/svg+xml'},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
