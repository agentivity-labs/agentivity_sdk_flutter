import 'dart:typed_data';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Same fake provider shape as chat_controller_test.dart, kept local so this file
// stays a self-contained widget test.
class _FakeChatProvider implements IChatProvider {
  _FakeChatProvider({this.threads = const [], this.messages = const []});

  final List<ChatThread> threads;
  final List<ChatMessage> messages;
  int sendCallCount = 0;
  String? lastSentText;
  List<ChatAttachment>? lastAttachments;

  @override
  Future<List<ChatThread>> listThreads({required String contextId}) async => threads;

  @override
  Future<ChatThread> fetchThread({required String contextId, required String threadId}) async => threads.firstWhere((t) => t.threadId == threadId);

  @override
  Future<List<ChatMessage>> listMessages({required String contextId, required String threadId}) async => messages;

  @override
  Future<void> sendMessage({required String contextId, String? threadId, required String text, List<ChatAttachment>? attachments}) async {
    sendCallCount++;
    lastSentText = text;
    lastAttachments = attachments;
  }
}

ChatThread _thread(String id) => ChatThread.fromJson({'id': id, 'contextId': 'ctx1', 'runId': 'r1', 'title': 'Thread', 'isDefault': true, 'status': 'active'});

void main() {
  testWidgets('AgUiChatDiscussion renders the composer and forwards a sent message', (tester) async {
    final provider = _FakeChatProvider(threads: [_thread('t1')]);
    final controller = ChatController(provider: provider, contextId: 'ctx1');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgUiChatDiscussion(client: AgentivityPlatformClient(baseUrl: 'http://localhost:1'), controller: controller, threadId: 't1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(AgUiChatInput), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'hello there');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(provider.sendCallCount, 1);
    expect(provider.lastSentText, 'hello there');
  });

  testWidgets('a later message goes with its photos, as the first one', (tester) async {
    final provider = _FakeChatProvider(threads: [_thread('t1')]);
    final controller = ChatController(provider: provider, contextId: 'ctx1');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AgUiChatDiscussion(client: AgentivityPlatformClient(baseUrl: 'http://localhost:1'), controller: controller, threadId: 't1'))),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final photo = Uint8List.fromList([1, 2, 3]);
    tester.widget<AgUiChatInput>(find.byType(AgUiChatInput)).onSend('and the kitchen', [AgUiImageBytesAttachment(bytes: photo, name: 'kitchen.jpg', mimeType: 'image/jpeg')]);
    await tester.pump(const Duration(milliseconds: 50));

    final sent = provider.lastAttachments!.single as ImageBytesAttachment;
    expect(sent.bytes, photo);
    expect(sent.mimeType, 'image/jpeg');
  });

}
