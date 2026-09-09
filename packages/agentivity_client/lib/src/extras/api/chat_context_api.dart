import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/http_core.dart';

/// Chat context run (AG-UI stream over a chat context).
class ChatContextApi {
  ChatContextApi(this._c);
  final AgentivityHttpCore _c;

  Future<ResponseBody> openChatRun({
    required String contextId,
    required String threadId,
    String? runId,
    required List<Map<String, dynamic>> messages,
    CancelToken? cancelToken,
  }) async {
    final headers = <String, dynamic>{
      Headers.acceptHeader: 'text/event-stream',
      Headers.contentTypeHeader: 'application/json; charset=utf-8',
      'Cache-Control': 'no-cache',
    };
    final body = <String, dynamic>{
      'threadId': threadId,
      'messages': messages,
    };
    if (runId != null) body['runId'] = runId;

    final response = await _c.dio.post<ResponseBody>(
      '/chat/contexts/${Uri.encodeComponent(contextId)}/run',
      data: jsonEncode(body),
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        receiveTimeout: Duration.zero,
      ),
    );
    final responseBody = response.data;
    if (responseBody == null) {
      throw StateError('Chat run stream returned no body for context $contextId.');
    }
    return responseBody;
  }
}
