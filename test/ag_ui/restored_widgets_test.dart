import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

ChatController _controller() => ChatController.fromStream(events: const Stream<AgUiEvent>.empty());

ChatMessage _message({String id = 'm1', List<ChatContentBlock>? blocks, Map<String, dynamic>? metadata, String text = ''}) =>
    ChatMessage(id: id, role: ChatMessageRole.assistant, contextId: 'c', threadId: 't1', runId: 'r', text: text, blocks: blocks, metadata: metadata);

void main() {
  group('a conversation restored from history', () {
    test('shows the widgets its messages carried, read back from their metadata', () {
      final c = _controller();
      c.addMessage(
        threadId: 't1',
        message: _message(
          metadata: {
            'blocks': [
              {'type': 'text', 'text': 'Here is the report'},
              {
                'type': 'StatusCard',
                'widgetProps': {'title': 'Watch-outs', 'status': 'warning', 'message': 'Check the reviews'},
              },
            ],
          },
        ),
      );

      final blocks = c.localMessages('t1').single.blocks;
      expect(blocks, isNotNull);
      expect(blocks!.length, 2);
      expect(blocks[1].type, 'StatusCard');
    });

    test('keeps the blocks a message already has, and leaves a plain message alone', () {
      final c = _controller();
      c.addMessage(
        threadId: 't1',
        message: _message(
          id: 'a',
          blocks: [ChatContentBlock.fromJson({'type': 'text', 'text': 'own'})],
          metadata: {
            'blocks': [
              {'type': 'text', 'text': 'other'},
            ],
          },
        ),
      );
      c.addMessage(threadId: 't1', message: _message(id: 'b', text: 'plain'));

      final messages = c.localMessages('t1');
      expect(messages[0].blocks!.single.text, 'own');
      expect(messages[1].blocks, isNull);
    });
  });
}
