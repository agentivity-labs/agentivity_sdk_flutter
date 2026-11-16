import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

ChatController _controller() => ChatController.fromStream(events: const Stream<AgUiEvent>.empty());

void main() {
  group('after the person answers a question', () {
    test('the conversation says it is working again', () {
      final chat = _controller();
      addTearDown(chat.dispose);
      // The run that stops to ask says it has finished: nothing is at work while the question waits.
      expect(chat.isAwaitingResponse, isFalse);

      chat.noteWorkingAgain();

      expect(chat.isAwaitingResponse, isTrue, reason: 'the run takes its work up again, and it shows');
    });

    test('and stops saying so when the run ends', () {
      final chat = _controller();
      addTearDown(chat.dispose);
      chat.noteWorkingAgain();

      chat.feedEvent(AgUiEvent.fromJson({'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r'}));

      expect(chat.isAwaitingResponse, isFalse);
    });
  });
}
