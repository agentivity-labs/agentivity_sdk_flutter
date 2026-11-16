import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A conversation of the workspace serves nothing of its own: what it knows it puts in the controller itself (the stream, or
/// what it read back when it was opened again). Same shape as AgentivityConversation.
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

ChatController _conversation() => ChatController(provider: _Conversation(), contextId: 'e1');

/// What [AgentivityConversation.reopen] puts back: the thread of the execution, then its stored messages.
void _reopened(ChatController chat) {
  chat.addThread(ChatThread(threadId: 'ab647d9a', contextId: 'e1', runId: 'r1', title: 'Main', isDefault: true, status: 'Open', createdAt: DateTime.now()));
  chat.addMessage(
    threadId: 'ab647d9a',
    message: ChatMessage(id: 'm1', role: ChatMessageRole.user, contextId: 'e1', threadId: 'ab647d9a', runId: 'r1', text: 'Check this contract'),
  );
  chat.addMessage(
    threadId: 'ab647d9a',
    message: ChatMessage(
      id: 'm2',
      role: ChatMessageRole.assistant,
      contextId: 'e1',
      threadId: 'ab647d9a',
      runId: 'r1',
      text: '',
      metadata: {
        'interaction.request_id': 'q1',
        'interaction.awaiting_response': true,
        'blocks': [
          {
            'type': 'SourceInput',
            'widgetProps': {'title': 'Nesko Stone supply agreement', 'description': 'Please upload the supplier contract', 'sources': ['upload']},
          },
        ],
      },
    ),
  );
}

Widget _panel(ChatController chat) => MaterialApp(
      home: Scaffold(
        body: AgUiChatDiscussion(client: AgentivityPlatformClient(baseUrl: 'http://localhost:1'), controller: chat, widgetRegistry: AgArtifactsBundle.registry()),
      ),
    );

void main() {
  testWidgets('a conversation opened again shows what it read back, though the page swapped its chat on the way', (tester) async {
    // The page builds its chat before it knows what the conversation is (its kind, its entity), then replaces it with the real
    // one and reads the conversation back into it.
    final placeholder = _conversation();
    addTearDown(placeholder.dispose);
    await tester.pumpWidget(_panel(placeholder));
    await tester.pump(const Duration(milliseconds: 50));

    final real = _conversation();
    addTearDown(real.dispose);
    await tester.pumpWidget(_panel(real));
    await tester.pump();
    _reopened(real);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Check this contract'), findsOneWidget, reason: 'the person sees what they said');
    expect(find.textContaining('Nesko Stone supply agreement'), findsOneWidget, reason: 'and the card the agent asked with');
  });

  testWidgets('what the execution says is shown though the conversation wrote a thread of its own first', (tester) async {
    final chat = _conversation();
    addTearDown(chat.dispose);
    await tester.pumpWidget(_panel(chat));
    await tester.pump(const Duration(milliseconds: 50));

    // What the person typed, written before the execution had announced any thread.
    chat.addMessage(
      threadId: chat.ownThread(),
      message: ChatMessage(id: 'w1', role: ChatMessageRole.user, contextId: 'e1', threadId: chat.ownThread(), runId: '', text: 'Check this contract'),
    );
    await tester.pump();
    // Then the execution's own thread arrives, with the agent's question.
    _reopened(chat);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Nesko Stone supply agreement'), findsOneWidget, reason: 'the card the agent asked with');
    expect(find.textContaining('Check this contract'), findsOneWidget, reason: 'what the person said is still there, and said once');
  });

  testWidgets('a chat swapped for one that already holds the conversation shows it', (tester) async {
    final placeholder = _conversation();
    addTearDown(placeholder.dispose);
    await tester.pumpWidget(_panel(placeholder));
    await tester.pump(const Duration(milliseconds: 50));

    // The page read the conversation back before it put its chat on screen: nothing will be announced after the swap.
    final real = _conversation();
    addTearDown(real.dispose);
    _reopened(real);
    await tester.pumpWidget(_panel(real));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Check this contract'), findsOneWidget);
    expect(find.textContaining('Nesko Stone supply agreement'), findsOneWidget);
  });

  testWidgets('a card that had nowhere to go is kept when the execution announces its thread', (tester) async {
    final chat = _conversation();
    addTearDown(chat.dispose);
    await tester.pumpWidget(_panel(chat));
    await tester.pump(const Duration(milliseconds: 50));

    // An agent on its own asks with a card before any thread has been announced: it goes to the thread of the conversation.
    chat.addMessage(
      threadId: chat.ownThread(),
      message: ChatMessage(
        id: 'card',
        role: ChatMessageRole.assistant,
        contextId: 'e1',
        threadId: chat.ownThread(),
        runId: '',
        text: '',
        metadata: {
          'blocks': [
            {
              'type': 'SourceInput',
              'widgetProps': {'title': 'Nesko Stone supply agreement', 'sources': ['upload']},
            },
          ],
        },
      ),
    );
    await tester.pump();
    chat.addThread(ChatThread(threadId: 'ab647d9a', contextId: 'e1', runId: 'r1', title: 'Main', isDefault: true, status: 'Open', createdAt: DateTime.now()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Nesko Stone supply agreement'), findsOneWidget, reason: 'the thread takes it over rather than hiding it');
  });
}
