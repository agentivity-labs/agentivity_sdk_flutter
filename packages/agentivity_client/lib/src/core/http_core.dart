import 'package:dio/dio.dart';

import 'api_contract.dart';

/// Internal HTTP transport shared by all [*Api] components.
///
/// Exposed publicly so sub-classes and sibling [*Api] objects can reach it,
/// but callers outside this package should never depend on it directly.
class AgentivityHttpCore {
  AgentivityHttpCore({Dio? dio, required String baseUrl}) : _dio = dio ?? Dio(_buildOptions(baseUrl));

  static const String _apiV1 = '/api/v1';

  static BaseOptions _buildOptions(String baseUrl) {
    final normalized = _normalizeBaseUrl(baseUrl);
    return BaseOptions(
      baseUrl: normalized,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
    );
  }

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  final Dio _dio;

  /// Direct access to the underlying [Dio] instance — required for streaming
  /// responses that bypass the normal JSON response pipeline.
  Dio get dio => _dio;

  static String v1(String path) => '$_apiV1$path';

  // ---------------------------------------------------------------------------
  // HTTP verbs
  // ---------------------------------------------------------------------------

  Future<Response<T>> guardRequest<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      throwIfApiFailurePayload(response.data, httpStatus: response.statusCode);
      return response;
    } on DioException catch (error, stackTrace) {
      final apiError = ApiException.fromDio(error);
      debugLogApiIssue(
        apiError,
        operation: '${error.requestOptions.method} ${error.requestOptions.path}',
        stackTrace: stackTrace,
      );
      throw apiError;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      guardRequest(
        () => _dio.get<T>(path, queryParameters: queryParameters, options: options, cancelToken: cancelToken),
      );

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      guardRequest(
        () => _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken),
      );

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      guardRequest(
        () => _dio.put<T>(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken),
      );

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      guardRequest(
        () => _dio.patch<T>(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken),
      );

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      guardRequest(
        () => _dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken),
      );

  // ---------------------------------------------------------------------------
  // Shared utilities
  // ---------------------------------------------------------------------------

  String requireNormalizedId(String value, {required String label}) {
    final normalized = value.trim();
    if (normalized.isEmpty) throw ArgumentError('$label is required');
    return normalized;
  }

  String? normalizeNullableId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  String normalizeRunId(String runId) {
    final trimmed = runId.trim();
    if (trimmed.isEmpty) throw ArgumentError('Run id is required');
    return trimmed;
  }

  void expectSuccessOrEmptyResponse(
    Map<String, dynamic>? data, {
    required String operation,
  }) {
    if (data == null || data.isEmpty) return;
    if (data['success'] == true) return;
    throw StateError('$operation did not report success.');
  }

  List<Map<String, dynamic>> extractCollectionObjects(
    dynamic payload, {
    List<String> collectionKeys = const <String>['items', 'data', 'results'],
    List<String> itemKeys = const <String>[],
  }) {
    final collection = _extractCollectionPayload(payload, preferredKeys: collectionKeys);
    return collection.map((item) => extractObject(item, preferredKeys: itemKeys)).toList(growable: false);
  }

  List<dynamic> _extractCollectionPayload(
    dynamic payload, {
    required List<String> preferredKeys,
  }) {
    if (payload is List) return payload;
    if (payload is Map<String, dynamic>) {
      for (final key in preferredKeys) {
        final candidate = payload[key];
        if (candidate is List) return candidate;
      }
      return const <dynamic>[];
    }
    if (payload is Map) {
      return _extractCollectionPayload(
        Map<String, dynamic>.from(payload),
        preferredKeys: preferredKeys,
      );
    }
    return const <dynamic>[];
  }

  Map<String, dynamic> extractObject(
    dynamic payload, {
    List<String> preferredKeys = const <String>['data', 'result'],
  }) {
    if (payload is Map<String, dynamic>) {
      for (final key in preferredKeys) {
        final candidate = payload[key];
        if (candidate is Map<String, dynamic>) return candidate;
        if (candidate is Map) return Map<String, dynamic>.from(candidate);
      }
      return payload;
    }
    if (payload is Map) {
      return extractObject(Map<String, dynamic>.from(payload), preferredKeys: preferredKeys);
    }
    throw StateError('Unsupported object payload: ${payload.runtimeType}');
  }

  int? parseVersion(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    throw StateError('Unsupported version payload: ${value.runtimeType}');
  }

  String encodeConfigPath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) throw ArgumentError('Config path is required');
    final segments = normalized.split('/').where((s) => s.isNotEmpty);
    return segments.map(Uri.encodeComponent).join('/');
  }
}
