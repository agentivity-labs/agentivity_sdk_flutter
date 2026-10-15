@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the SDK asks the platform when a person answers a question or writes in the conversation of an execution.
/// An application only knows its execution: it names the question it answers, never a run.
void main() {
  late HttpServer server;
  late List<_Call> calls;
  late String baseUrl;

  setUp(() async {
    calls = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      final body = raw.isEmpty ? null : jsonDecode(raw);
      calls.add(_Call(request.method, request.uri.path, body));
      final path = request.uri.path;
      Object? reply;
      if (request.method == 'POST' && path == '/api/v1/executions') {
        reply = {'executionId': 'exec-1', 'runId': 'run-1', 'streamId': 'stream-1', 'streamUrl': '/api/v1/streams/stream-1/events', 'entityId': 'team-1', 'entityKind': 'team', 'state': 'active'};
      } else if (path.endsWith('/respond')) {
        reply = {'executionId': 'exec-1', 'runId': 'run-of-the-question', 'requestId': 'question-2', 'threadId': 'thread-1', 'messageId': 'message-9', 'state': 'resumed'};
      } else if (request.method == 'POST' && path.endsWith('/messages')) {
        reply = {'executionId': 'exec-1', 'threadId': 'thread-1', 'messageId': 'message-10'};
      } else if (request.method == 'GET' && path == '/api/v1/executions/exec-1/threads') {
        reply = [
          {'threadId': 'thread-0', 'title': 'Side', 'isDefault': false, 'status': 'Active', 'createdAt': '2026-10-15T10:00:00Z'},
          {'threadId': 'thread-1', 'title': 'Main', 'isDefault': true, 'status': 'Active', 'createdAt': '2026-10-15T10:00:00Z'},
        ];
      } else if (request.method == 'GET' && path == '/api/v1/executions/exec-1/threads/thread-1/messages') {
        reply = [
          {'messageId': 'message-1', 'threadId': 'thread-1', 'authorType': 'User', 'text': 'Hello', 'createdAt': '2026-10-15T10:00:00Z'},
        ];
      }
      request.response.statusCode = reply == null ? 404 : 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(reply == null ? '{}' : jsonEncode(reply));
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  group('the client', () {
    test('answers a question of the execution by naming it', () async {
      final client = AgentivityPlatformClient(baseUrl: baseUrl);

      final result = await client.runs.submitHilResponse(executionId: 'exec-1', requestId: 'question-2', response: 'Blue', source: 'widget');

      expect(calls.single.method, 'POST');
      expect(calls.single.path, '/api/v1/executions/exec-1/respond');
      expect(calls.single.body, {'requestId': 'question-2', 'response': 'Blue', 'source': 'widget'});
      expect(result.runId, 'run-of-the-question');
      expect(result.threadId, 'thread-1');
      expect(result.state, 'resumed');
    });

    test('writes a message in a conversation of the execution', () async {
      final client = AgentivityPlatformClient(baseUrl: baseUrl);

      final written = await client.conversations.postMessage(executionId: 'exec-1', threadId: 'thread-1', text: 'Hello', authorName: 'Ann');

      expect(calls.single.method, 'POST');
      expect(calls.single.path, '/api/v1/executions/exec-1/threads/thread-1/messages');
      expect(calls.single.body, {'text': 'Hello', 'authorName': 'Ann'});
      expect(written.messageId, 'message-10');
    });
  });

  group('the AG-UI connector', () {
    test('starts an execution, and follows the stream the platform gives', () async {
      final connector = AgentivityPlatformConnector(baseUrl: baseUrl, authToken: 'token');

      final handle = await connector.startRun('team-1', 'Plan a trip');

      expect(calls.single.method, 'POST');
      expect(calls.single.path, '/api/v1/executions');
      expect(calls.single.body, containsPair('entityId', 'team-1'));
      expect(handle.executionId, 'exec-1');
      expect(handle.streamUrl, '/api/v1/streams/stream-1/events');
    });

    test('answers a question of the execution by naming it', () async {
      final connector = AgentivityPlatformConnector(baseUrl: baseUrl, authToken: 'token');

      await connector.respond('exec-1', requestId: 'question-2', responseText: 'Blue');

      expect(calls.single.path, '/api/v1/executions/exec-1/respond');
      expect(calls.single.body, {'requestId': 'question-2', 'response': 'Blue'});
    });

    test('writes a message in the main conversation of the execution when none is named', () async {
      final connector = AgentivityPlatformConnector(baseUrl: baseUrl, authToken: 'token');

      await connector.sendMessage('exec-1', 'Hello');

      expect(calls.map((c) => '${c.method} ${c.path}'), ['GET /api/v1/executions/exec-1/threads', 'POST /api/v1/executions/exec-1/threads/thread-1/messages']);
      expect(calls.last.body, {'text': 'Hello'});
    });

    test('reads the conversations of the execution', () async {
      final connector = AgentivityPlatformConnector(baseUrl: baseUrl, authToken: 'token');

      final threads = await connector.listThreads('exec-1');
      final messages = await connector.listMessages('exec-1', 'thread-1');

      expect(threads.map((t) => t.threadId), ['thread-0', 'thread-1']);
      expect(messages.single.text, 'Hello');
    });
  });
}

class _Call {
  _Call(this.method, this.path, this.body);
  final String method;
  final String path;
  final Object? body;
}
