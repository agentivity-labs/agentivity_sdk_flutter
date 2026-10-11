import 'dart:async';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

AgUiEvent _event(Map<String, dynamic> json) => AgUiEvent.fromJson(json);

const _started = {'type': 'RUN_STARTED', 'threadId': 't1', 'runId': 'r1'};
const _finished = {'type': 'RUN_FINISHED', 'threadId': 't1', 'runId': 'r1'};

/// Lets the delay before the indicator shows go by.
Future<void> _wait(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('AgUiChatActivityIndicator', () {
    testWidgets('shows nothing when nothing is going on', (tester) async {
      await tester.pumpWidget(_host(const AgUiChatActivityIndicator(activity: null)));
      await _wait(tester);
      expect(find.text('Thinking…'), findsNothing);
    });

    testWidgets('waits for its delay, so a quick answer shows nothing at all', (tester) async {
      await tester.pumpWidget(_host(const AgUiChatActivityIndicator(activity: AgUiChatActivity())));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Thinking…'), findsNothing);

      // The answer came before the delay was over.
      await tester.pumpWidget(_host(const AgUiChatActivityIndicator(activity: null)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Thinking…'), findsNothing);
    });

    testWidgets('shows after the delay and goes at once when the work is over', (tester) async {
      await tester.pumpWidget(_host(const AgUiChatActivityIndicator(activity: AgUiChatActivity())));
      await _wait(tester);
      expect(find.text('Thinking…'), findsOneWidget);

      await tester.pumpWidget(_host(const AgUiChatActivityIndicator(activity: null)));
      await tester.pump();
      expect(find.text('Thinking…'), findsNothing);
    });

    testWidgets('says what the app says, else who is at work, else that it is thinking', (tester) async {
      await tester.pumpWidget(_host(const AgUiChatActivityIndicator(activity: AgUiChatActivity(label: 'Reading your files', memberName: 'Writer'))));
      await _wait(tester);
      expect(find.text('Reading your files'), findsOneWidget);

      // What is said changes without the indicator going away and waiting again.
      await tester.pumpWidget(_host(const AgUiChatActivityIndicator(activity: AgUiChatActivity(memberName: 'Writer'))));
      await tester.pump();
      expect(find.text('Writer is working on it…'), findsOneWidget);
    });

    testWidgets('its wording, its mark and its whole drawing can be replaced', (tester) async {
      await tester.pumpWidget(_host(AgUiChatActivityIndicator(
        activity: const AgUiChatActivity(stepName: 'fetch'),
        style: AgUiChatActivityStyle(animation: AgUiChatActivityAnimation.spin, icon: Icons.autorenew, delay: Duration.zero, label: (a) => 'Step ${a.stepName}'),
      )));
      await tester.pump();
      expect(find.text('Step fetch'), findsOneWidget);
      expect(find.byIcon(Icons.autorenew), findsOneWidget);

      await tester.pumpWidget(_host(AgUiChatActivityIndicator(
        activity: const AgUiChatActivity(),
        style: const AgUiChatActivityStyle(delay: Duration.zero),
        builder: (context, activity) => const Text('my own'),
      )));
      await tester.pump();
      expect(find.text('my own'), findsOneWidget);
      expect(find.text('Thinking…'), findsNothing);
    });

    testWidgets('every animation draws, and less motion asked of the system gives a still mark', (tester) async {
      for (final animation in AgUiChatActivityAnimation.values) {
        await tester.pumpWidget(_host(AgUiChatActivityIndicator(key: ValueKey(animation), activity: const AgUiChatActivity(), style: AgUiChatActivityStyle(animation: animation, delay: Duration.zero))));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '$animation');
        expect(find.text('Thinking…'), findsOneWidget);
      }

      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(body: AgUiChatActivityIndicator(activity: AgUiChatActivity(), style: AgUiChatActivityStyle(delay: Duration.zero))),
        ),
      ));
      await tester.pump();
      // Nothing left to animate: the test would not settle otherwise.
      await tester.pumpAndSettle();
      expect(find.text('Thinking…'), findsOneWidget);
    });
  });

  group('AgUiChatDiscussion activity', () {
    late StreamController<AgUiEvent> events;
    late ChatController controller;

    setUp(() {
      events = StreamController<AgUiEvent>.broadcast();
      controller = ChatController.fromStream(events: events.stream, contextId: 'ctx1');
    });

    tearDown(() {
      controller.dispose();
      events.close();
    });

    Future<void> pumpChat(WidgetTester tester, {bool show = true, bool? running, String? label}) =>
        tester.pumpWidget(_host(AgUiChatDiscussion(controller: controller, autoLoad: false, showActivityIndicator: show, running: running, activityLabel: label)));

    testWidgets('is off unless asked for', (tester) async {
      await pumpChat(tester, show: false);
      controller.feedEvent(_event(_started));
      await _wait(tester);
      expect(find.byType(AgUiChatActivityIndicator), findsNothing);
      expect(find.text('Thinking…'), findsNothing);
    });

    testWidgets('shows while the run works and goes when it finishes', (tester) async {
      await pumpChat(tester);
      await _wait(tester);
      expect(find.text('Thinking…'), findsNothing);

      controller.feedEvent(_event(_started));
      await _wait(tester);
      expect(find.text('Thinking…'), findsOneWidget);

      controller.feedEvent(_event(_finished));
      await tester.pump();
      expect(find.text('Thinking…'), findsNothing);
    });

    testWidgets('goes when the run fails', (tester) async {
      await pumpChat(tester);
      controller.feedEvent(_event(_started));
      await _wait(tester);
      expect(find.text('Thinking…'), findsOneWidget);

      controller.feedEvent(_event({'type': 'RUN_ERROR', 'message': 'out of credit'}));
      await tester.pump();
      expect(find.text('Thinking…'), findsNothing);
    });

    testWidgets('goes when the stream ends without saying the run is over', (tester) async {
      await pumpChat(tester);
      events.add(_event(_started));
      await _wait(tester);
      expect(find.text('Thinking…'), findsOneWidget);

      await events.close();
      await tester.pump();
      expect(controller.isAwaitingResponse, isFalse);
      expect(find.text('Thinking…'), findsNothing);
    });

    testWidgets('goes when the run stops to ask something', (tester) async {
      await pumpChat(tester);
      controller.feedEvent(_event(_started));
      await _wait(tester);
      expect(find.text('Thinking…'), findsOneWidget);

      controller.feedEvent(_event({
        'type': 'RUN_FINISHED',
        'threadId': 't1',
        'runId': 'r1',
        'outcome': 'interrupt',
        'interrupts': [
          {'id': 'gate1', 'reason': 'chat_hil_gate', 'message': 'Which one?', 'metadata': {'threadId': 't1'}},
        ],
      }));
      await tester.pump();
      expect(find.text('Thinking…'), findsNothing);
    });

    testWidgets('follows what the app says of the run, and says the app\'s own words', (tester) async {
      await pumpChat(tester, running: true, label: 'Building the team');
      await _wait(tester);
      expect(find.text('Building the team'), findsOneWidget);

      await pumpChat(tester, running: false, label: 'Building the team');
      await tester.pump();
      expect(find.text('Building the team'), findsNothing);
    });

    testWidgets('names the member at work', (tester) async {
      await pumpChat(tester);
      controller.feedEvent(_event(_started));
      controller.feedEvent(_event({'type': 'STEP_STARTED', 'stepName': 'writer-turn', 'memberEntityId': 'a1', 'displayName': 'Writer'}));
      await _wait(tester);
      expect(find.text('Writer is working on it…'), findsOneWidget);
      expect(controller.currentStep, 'writer-turn');

      controller.feedEvent(_event({'type': 'STEP_FINISHED', 'stepName': 'writer-turn', 'memberEntityId': 'a1'}));
      await tester.pump();
      expect(controller.currentStep, isNull);
      // The run is still working: the line stays, back to its plain wording.
      expect(find.text('Thinking…'), findsOneWidget);
    });
  });
}
