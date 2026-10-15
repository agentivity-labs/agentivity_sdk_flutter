import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

/// See `streaming_request.dart`. The browser's `fetch`, reading the response as it comes. [path] is resolved against
/// `dio.options.baseUrl` unless it is absolute, and Dio's own headers are sent with [headers]; [data] is the body (a
/// `String` sent as it is, anything else as JSON). Fails as Dio does when the server answers with an error.
Future<ResponseBody> openStreamingRequest(
  Dio dio,
  String method,
  String path, {
  Object? data,
  Map<String, dynamic> headers = const {},
  CancelToken? cancelToken,
}) async {
  final uri = _resolve(dio.options.baseUrl, path);
  final requestOptions = RequestOptions(path: uri.toString(), method: method, data: data);

  final sent = web.Headers();
  final all = <String, dynamic>{...dio.options.headers, ...headers};
  if (data != null && data is! String) {
    all.putIfAbsent('Content-Type', () => 'application/json');
  }
  all.forEach((name, value) {
    if (value != null) sent.append(name, value.toString());
  });

  final abort = web.AbortController();
  cancelToken?.whenCancel.then((_) => abort.abort());

  final web.Response response;
  try {
    response = await web.window
        .fetch(
          uri.toString().toJS,
          web.RequestInit(
            method: method,
            headers: sent,
            body: data == null ? null : (data is String ? data : jsonEncode(data)).toJS,
            signal: abort.signal,
          ),
        )
        .toDart;
  } catch (error) {
    if (cancelToken?.isCancelled == true) {
      throw DioException.requestCancelled(requestOptions: requestOptions, reason: cancelToken?.cancelError);
    }
    throw DioException.connectionError(requestOptions: requestOptions, reason: 'The stream $method $uri could not be opened: $error');
  }

  // What a stream is read by: its type (the browser shows a page only the headers the server lets it).
  final contentType = response.headers.get('content-type');
  final responseHeaders = <String, List<String>>{if (contentType != null) Headers.contentTypeHeader: [contentType]};

  if (!response.ok) {
    final text = (await response.text().toDart).toDart;
    throw DioException.badResponse(
      statusCode: response.status,
      requestOptions: requestOptions,
      response: Response<dynamic>(requestOptions: requestOptions, statusCode: response.status, statusMessage: response.statusText, data: text),
    );
  }

  final body = response.body;
  if (body == null) {
    throw StateError('The stream $method $uri returned no body.');
  }
  final reader = body.getReader() as web.ReadableStreamDefaultReader;

  late final StreamController<Uint8List> bytes;
  Future<void> pump() async {
    try {
      while (true) {
        final chunk = await reader.read().toDart;
        if (chunk.done) break;
        final value = chunk.value;
        if (value != null) bytes.add((value as JSUint8Array).toDart);
      }
    } catch (error, stack) {
      if (!abort.signal.aborted) bytes.addError(error, stack);
    } finally {
      await bytes.close();
    }
  }

  bytes = StreamController<Uint8List>(
    onListen: () => unawaited(pump()),
    onCancel: () => abort.abort(),
  );

  return ResponseBody(bytes.stream, response.status, headers: responseHeaders, statusMessage: response.statusText);
}

Uri _resolve(String baseUrl, String path) {
  final asGiven = Uri.parse(path);
  if (asGiven.hasScheme) return asGiven;
  if (baseUrl.isEmpty) return Uri.base.resolve(path);
  final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  return Uri.parse('$base${path.startsWith('/') ? path : '/$path'}');
}
