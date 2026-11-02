import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatController chat() => ChatController.fromStream(events: const Stream.empty(), contextId: 'x');

  Widget host(ChatController c, {VoidCallback? onNew}) => MaterialApp(home: Scaffold(body: AgUiChatDiscussion(controller: c, autoLoad: false, onNewConversation: onNew)));

  test('reads the end of a job from the stream', () {
    final e = AgUiEvent.fromJson({'type': 'RUN_FINISHED', 'runId': 'r', 'outcome': 'success', 'jobFinished': true});
    expect((e as RunFinishedEvent).jobFinished, isTrue);
  });

  testWidgets('offers what comes next only once a job is finished, not after a turn', (tester) async {
    final c = chat();
    await tester.pumpWidget(host(c, onNew: () {}));

    c.feedEvent(AgUiEvent.fromJson({'type': 'RUN_STARTED', 'runId': 'r1'}));
    c.feedEvent(AgUiEvent.fromJson({'type': 'RUN_FINISHED', 'runId': 'r1', 'outcome': 'success'}));
    await tester.pump();
    expect(find.text('Start another'), findsNothing);

    c.feedEvent(AgUiEvent.fromJson({'type': 'RUN_STARTED', 'runId': 'r2'}));
    c.feedEvent(AgUiEvent.fromJson({'type': 'RUN_FINISHED', 'runId': 'r2', 'outcome': 'success', 'jobFinished': true}));
    await tester.pump();
    expect(find.text('Start another'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Start another'), findsNothing);
  });

  testWidgets('a conversation that has ended offers a new one, and only a yes starts it', (tester) async {
    final c = chat();
    var started = 0;
    await tester.pumpWidget(host(c, onNew: () => started++));

    expect(c.noteSendRefused(const ApiException(payload: ApiErrorPayload(code: 'execution_ended'))), isTrue);
    await tester.pump();

    expect(find.text('This conversation has ended. Start a new one?'), findsOneWidget);
    expect(started, 0);
    await tester.tap(find.text('Start a new one'));
    expect(started, 1);
  });

  test('a message during a turn keeps its text, any other failure does not concern it', () {
    final c = chat();
    expect(c.noteSendRefused(const ApiException(payload: ApiErrorPayload(code: 'execution_busy'))), isTrue);
    expect(c.conversationEnded, isFalse);
    expect(c.noteSendRefused(StateError('boom')), isFalse);
  });

  test('follows the stream the platform gives: a conversation that goes on takes it up from where it stood', () {
    final started = SessionStartedResponse.fromJson({'executionId': 'e', 'streamId': 's', 'runId': 'r', 'state': 'active', 'streamUrl': '/api/v1/streams/s/events?after=17'});
    expect(started.streamUrl, '/api/v1/streams/s/events?after=17');
  });

  test('a new run of a conversation starts its team afresh', () {
    final c = chat();
    c.feedEvent(AgUiEvent.fromJson({'type': 'RUN_STARTED', 'runId': 'r1'}));
    c.feedEvent(AgUiEvent.fromJson({'type': 'STEP_STARTED', 'stepName': 's', 'memberEntityId': 'a', 'activity': 'Picking your exercises'}));
    expect(c.memberActivities['a'], 'Picking your exercises');
    c.feedEvent(AgUiEvent.fromJson({'type': 'RUN_STARTED', 'runId': 'r2'}));
    expect(c.memberStatuses, isEmpty);
    expect(c.memberActivities, isEmpty);
  });
}
