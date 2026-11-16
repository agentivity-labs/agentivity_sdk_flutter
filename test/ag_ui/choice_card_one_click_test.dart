import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Conversation implements IChatProvider {
  @override
  Future<List<ChatThread>> listThreads({required String contextId}) async => const [];
  @override
  Future<ChatThread> fetchThread({required String contextId, required String threadId}) async =>
      ChatThread(threadId: threadId, contextId: contextId, runId: '', title: '', isDefault: true, status: 'active', createdAt: DateTime.now());
  @override
  Future<List<ChatMessage>> listMessages({required String contextId, required String threadId}) async => const [];
  @override
  Future<void> sendMessage({required String contextId, String? threadId, required String text, List<ChatAttachment>? attachments}) async {}
}

void main() {
  testWidgets('a choice is confirmed with one click on Confirm', (tester) async {
    final chat = ChatController(provider: _Conversation(), contextId: 'e1');
    addTearDown(chat.dispose);
    chat.addThread(ChatThread(threadId: 't', contextId: 'e1', runId: 'r', title: 'Main', isDefault: true, status: 'Open', createdAt: DateTime.now()));
    chat.addMessage(
      threadId: 't',
      message: ChatMessage(
        id: 'q',
        role: ChatMessageRole.assistant,
        contextId: 'e1',
        threadId: 't',
        runId: 'r',
        text: '',
        metadata: {
          'blocks': [
            {
              'type': 'ChoiceCard',
              'widgetProps': {
                'title': 'What should I do?',
                'options': [
                  {'id': 'approve', 'label': 'Approve it'},
                  {'id': 'changes', 'label': 'Ask for changes'},
                ],
              },
            },
          ],
        },
      ),
    );
    chat.setHilGate(ChatHilGate(requestId: 'q1', threadId: 't', question: '', title: 'Your answer'));

    final answers = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgUiChatDiscussion(
            client: AgentivityPlatformClient(baseUrl: 'http://localhost:1'),
            controller: chat,
            widgetRegistry: AgArtifactsBundle.registry(),
            onHilResponse: (gate, text, source) async => answers.add(text),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // The person had been typing: the box under the conversation holds the focus when they turn to the card.
    await tester.tap(find.byType(TextField).first);
    await tester.pump();

    await tester.tap(find.text('Approve it'));
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(answers, ['Choice: Approve it'], reason: 'one click, one answer');
  });
}
