import 'package:dio/dio.dart';

/// See `streaming_request.dart`. [path] is resolved against `dio.options.baseUrl` unless it is absolute; [data] is the body
/// (a `String` sent as it is, anything else as JSON). Fails as Dio does when the server answers with an error.
Future<ResponseBody> openStreamingRequest(
  Dio dio,
  String method,
  String path, {
  Object? data,
  Map<String, dynamic> headers = const {},
  CancelToken? cancelToken,
}) async {
  final response = await dio.request<ResponseBody>(
    path,
    data: data,
    cancelToken: cancelToken,
    options: Options(method: method, responseType: ResponseType.stream, headers: headers, receiveTimeout: Duration.zero),
  );
  final body = response.data;
  if (body == null) {
    throw StateError('The stream $method $path returned no body.');
  }
  return body;
}
