import 'dart:convert';
import 'dart:typed_data';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatController _controller() => ChatController.fromStream(events: const Stream<AgUiEvent>.empty());

AgUiEvent _event(Map<String, dynamic> json) => AgUiEvent.fromJson(json);

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.status, this.body);
  final int status;
  final Object body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: ['application/json']});

  @override
  void close({bool force = false}) {}
}

RunsApi _runsApi(int status, Object body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/'))..httpClientAdapter = _JsonAdapter(status, body);
  return RunsApi(AgentivityHttpCore(dio: dio, baseUrl: 'https://api.example.com'));
}

void main() {
  group('a run that ends on an error', () {
    test('is kept by the controller with its code, until the next run or a dismissal', () {
      final c = _controller();
      c.feedEvent(_event({'type': 'RUN_ERROR', 'message': 'Needs Analyst: out of credit.', 'code': 'llm_billing'}));

      expect(c.runError?.message, 'Needs Analyst: out of credit.');
      expect(c.runError?.code, 'llm_billing');

      c.feedEvent(_event({'type': 'RUN_STARTED', 'runId': 'r2'}));
      expect(c.runError, isNull);

      c.feedEvent(_event({'type': 'RUN_ERROR', 'message': 'boom'}));
      c.dismissRunError();
      expect(c.runError, isNull);
    });

    test('is cleared with the conversation', () {
      final c = _controller();
      c.feedEvent(_event({'type': 'RUN_ERROR', 'message': 'boom'}));
      c.clear();
      expect(c.runError, isNull);
    });

    test('shows the member whose step failed as failed, not done', () {
      final c = _controller();
      c.feedEvent(_event({'type': 'STEP_STARTED', 'stepName': 'a', 'memberEntityId': 'm1', 'displayName': 'Needs Analyst'}));
      c.feedEvent(_event({'type': 'STEP_FINISHED', 'stepName': 'a', 'memberEntityId': 'm1', 'displayName': 'Needs Analyst', 'error': 'out of credit'}));
      c.feedEvent(_event({'type': 'STEP_STARTED', 'stepName': 'b', 'memberEntityId': 'm2'}));
      c.feedEvent(_event({'type': 'STEP_FINISHED', 'stepName': 'b', 'memberEntityId': 'm2'}));

      expect(c.memberStatuses['m1'], TeamMemberStatus.failed);
      expect(c.memberStatuses['m2'], TeamMemberStatus.done);
    });
  });

  group('the error notice', () {
    testWidgets('words an account out of credit for the end user, and keeps what the provider said', (tester) async {
      final c = _controller();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: AgUiChatDiscussion(controller: c, threadId: 't1'))));
      expect(find.byType(AgUiChatRunError), findsNothing);

      c.feedEvent(_event({'type': 'RUN_ERROR', 'message': 'Needs Analyst: refused. (Anthropic says: Your credit balance is too low)', 'code': 'llm_billing'}));
      await tester.pump();

      expect(find.text('The AI service is out of credit'), findsOneWidget);
      expect(find.textContaining('Add credit to the AI provider account'), findsOneWidget);
      expect(find.textContaining('Your credit balance is too low'), findsOneWidget);
    });

    testWidgets('can be dismissed', (tester) async {
      final c = _controller();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: AgUiChatDiscussion(controller: c, threadId: 't1'))));
      c.feedEvent(_event({'type': 'RUN_ERROR', 'message': 'boom'}));
      await tester.pump();
      expect(find.text('Something went wrong'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();
      expect(find.byType(AgUiChatRunError), findsNothing);
    });

    test('has a headline for each code the platform reports, and a plain one for the rest', () {
      expect(agUiDescribeRunError(const AgUiRunError(message: '', code: 'llm_auth')).title, 'The AI service rejected its API key');
      expect(agUiDescribeRunError(const AgUiRunError(message: '', code: 'llm_rate_limited')).title, 'The AI service is busy');
      expect(agUiDescribeRunError(const AgUiRunError(message: '', code: 'llm_unavailable')).title, 'The AI service is unavailable');
      expect(agUiDescribeRunError(const AgUiRunError(message: '', code: 'tool_call_failed')).title, 'Something went wrong');
      expect(agUiDescribeRunError(const AgUiRunError(message: '')).title, 'Something went wrong');
    });
  });

  group('RunsApi.fetchExecutionStatuses', () {
    test('reads the statuses of a run that failed — the inspector says "Failed" as data, it is not a failed request', () async {
      final statuses = await _runsApi(200, {
        'runId': 'r1',
        'status': 'Failed',
        'steps': [
          {'id': 'm1', 'name': 'Needs Analyst', 'kind': 'Agent', 'status': 'Failed', 'agentTopologyPositionId': 'needs', 'memberEntityId': null},
        ],
      }).fetchExecutionStatuses('e1');

      expect(statuses, isNotNull);
      expect(statuses!.executionState, 'failed');
    });

    test('still reports an unreachable status as null', () async {
      expect(await _runsApi(500, {'message': 'boom'}).fetchExecutionStatuses('e1'), isNull);
    });
  });
}
