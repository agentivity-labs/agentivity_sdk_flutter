import 'package:dio/dio.dart';

import 'workspace_sleep.dart';

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
  // The workspace sleeps: a stream opened again would wake it. It fails as an unreachable server does, and is tried again later.
  final asked = RequestOptions(path: path, method: method, extra: {...dio.options.extra});
  if (WorkspaceSleepGate.holdsBack(asked)) throw WorkspaceSleepGate.refusal(asked);
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
