import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/http_core.dart';
import '../../core/streaming_request.dart';

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

    return openStreamingRequest(_c.dio, 'POST', '/chat/contexts/${Uri.encodeComponent(contextId)}/run', data: jsonEncode(body), headers: headers, cancelToken: cancelToken);
  }
}
