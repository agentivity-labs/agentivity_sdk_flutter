import 'dart:async';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatController _controller() {
  final controller = ChatController.fromStream(events: const Stream<AgUiEvent>.empty());
  controller.addThread(ChatThread.fromJson({'id': 't1', 'contextId': 'c', 'runId': 'r', 'title': 'Thread', 'isDefault': true, 'status': 'active'}));
  return controller;
}

/// Whether the answer box takes typing: the text field the chat shows.
bool _boxTakesTyping(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).enabled ?? true;

void main() {
  // An answer can take the whole next turn to come back (the Studio's Assistant: minutes, its next question shown long before).
  // The next question showed over a box that typed nothing, waiting for the answer before it.
  testWidgets('a question asked while the answer before is still on its way can be answered at once', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller.setHilGate(const ChatHilGate(requestId: 'q1', threadId: 't1', question: 'Where do the requests live?', title: 'Data'));
    final first = Completer<void>();
    final answers = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AgUiChatDiscussion(
          controller: controller,
          threadId: 't1',
          onHilResponse: (gate, text, source) {
            answers.add('${gate.requestId}:$text');
            return gate.requestId == 'q1' ? first.future : Future<void>.value();
          },
        ),
      ),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'In a Data Table');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(answers, ['q1:In a Data Table']);
    expect(_boxTakesTyping(tester), isFalse, reason: 'while its own answer is on its way, a question waits');

    // The next question arrives before the first answer has come back.
    controller.setHilGate(const ChatHilGate(requestId: 'q2', threadId: 't1', question: 'Which columns?', title: 'Data'));
    await tester.pump();

    expect(_boxTakesTyping(tester), isTrue, reason: 'a new question is answerable at once');
    await tester.enterText(find.byType(TextField), 'Date and subject');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(answers.last, 'q2:Date and subject');

    first.complete();
    await tester.pump();
  });
}
