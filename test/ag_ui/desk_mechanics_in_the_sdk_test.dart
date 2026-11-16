import 'dart:convert';
import 'dart:typed_data';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// What every app of the platform does with a conversation lives here, not in each app: the card an agent sends, the images
/// joined to a message, and what the conversation produced to show beside it.
class _Nothing implements IChatProvider {
  @override
  Future<List<ChatThread>> listThreads({required String contextId}) async => const [];

  @override
  Future<ChatThread> fetchThread({required String contextId, required String threadId}) async =>
      ChatThread(threadId: threadId, contextId: contextId, runId: '', title: '', isDefault: true, status: 'active');

  @override
  Future<List<ChatMessage>> listMessages({required String contextId, required String threadId}) async => const [];

  @override
  Future<void> sendMessage({required String contextId, String? threadId, required String text, List<ChatAttachment>? attachments}) async {}
}

ChatController _chat() => ChatController(provider: _Nothing(), contextId: 'ctx');

/// A widget the agent sends, as it arrives on the stream.
AgUiEvent _card(String type, Map<String, dynamic> props) => AgUiEvent.fromJson({'type': 'CUSTOM', 'name': type, 'value': props});

void main() {
  test('a card sent before any thread was announced is shown, not dropped', () {
    final chat = _chat();
    addTearDown(chat.dispose);

    chat.feedEvent(_card('SummaryCard', {'title': 'What happens next'}));

    final thread = chat.threads.single.threadId;
    final message = chat.localMessages(thread).single;
    expect(message.metadata?['widgetType'], 'SummaryCard');
    expect((message.metadata?['widgetProps'] as Map)['title'], 'What happens next');
  });

  test('the thread made for a conversation that announced none is made once', () {
    final chat = _chat();
    addTearDown(chat.dispose);

    chat.feedEvent(_card('StatusCard', {'message': 'Reading'}));
    chat.feedEvent(_card('SummaryCard', {'title': 'Done'}));

    expect(chat.threads, hasLength(1));
    expect(chat.localMessages(chat.ownThread()), hasLength(2));
  });

  test('an image joined to a message travels as the run takes it, and one too large is refused by name', () {
    final small = AgUiImageBytesAttachment(bytes: Uint8List.fromList([1, 2, 3]), name: 'plan.png', mimeType: 'image/png');
    final images = imagesForARun([small, const AgUiFileAttachment(path: 'C:/notes.txt', name: 'notes.txt')]);

    expect(images, hasLength(1));
    expect(images.single['base64Data'], base64Encode(const [1, 2, 3]));
    expect(images.single['mimeType'], 'image/png');

    final huge = AgUiImageBytesAttachment(bytes: Uint8List(maxImageForARun + 1), name: 'scan.png');
    expect(
      () => imagesForARun([huge]),
      throwsA(isA<ImageTooLargeForARun>().having((e) => e.toString(), 'said', allOf(contains('scan.png'), contains('too large')))),
    );
  });

  test('what the conversation produced to show is listed oldest first, and what it asks is not', () {
    final chat = _chat();
    addTearDown(chat.dispose);
    final thread = chat.ownThread();
    final older = DateTime(2026, 11, 16, 9);
    final newer = DateTime(2026, 11, 16, 10);

    chat.addMessage(
      threadId: thread,
      message: ChatMessage(
        id: 'm2',
        role: ChatMessageRole.assistant,
        contextId: 'ctx',
        threadId: thread,
        runId: '',
        text: '',
        metadata: const {'widgetType': 'BarChart', 'widgetProps': <String, dynamic>{}},
        createdAt: newer,
      ),
    );
    chat.addMessage(
      threadId: thread,
      message: ChatMessage(
        id: 'm1',
        role: ChatMessageRole.assistant,
        contextId: 'ctx',
        threadId: thread,
        runId: '',
        text: '',
        metadata: const {'widgetType': 'SummaryCard', 'widgetProps': <String, dynamic>{'title': 'The three contracts'}},
        createdAt: older,
      ),
    );
    chat.addMessage(
      threadId: thread,
      message: ChatMessage(
        id: 'm3',
        role: ChatMessageRole.assistant,
        contextId: 'ctx',
        threadId: thread,
        runId: '',
        text: '',
        metadata: const {'widgetType': 'ChoiceCard', 'widgetProps': <String, dynamic>{'title': 'Your decision'}},
        createdAt: newer,
      ),
    );

    final results = chatResultsOf(chat);

    expect(results.map((r) => r.type), ['SummaryCard', 'BarChart']);
    expect(results.first.title, 'The three contracts');
    expect(results.last.title, 'Chart');
  });
}
