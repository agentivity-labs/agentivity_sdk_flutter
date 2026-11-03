import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 420, child: child))));

/// A dictation that fails says so in the field, in the app's words, until the person types: a mic that just stops looks broken.
void main() {
  const channel = MethodChannel('com.llfbandit.record/messages');

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  testWidgets('a mic that cannot be opened says so, and the line goes once the person types', (tester) async {
    // No recorder on the test machine: opening the mic fails, as when it is refused.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isRecording') return false;
      if (call.method == 'create' || call.method == 'dispose' || call.method == 'stop') return null;
      throw PlatformException(code: 'denied', message: 'Microphone permission denied');
    });
    await tester.pumpWidget(_host(AgUiChatInput(onSend: (_, _) {}, onTranscribeAudio: (_, _) async => 'hello', voiceProblemTexts: const AgUiVoiceProblemTexts(noMic: 'Micro refusé.'))));

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Micro refusé.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pump();
    expect(find.byKey(const ValueKey('ag-chat-input-voice-problem')), findsNothing);
  });

  test('the default texts say what to do next', () {
    const texts = AgUiVoiceProblemTexts();
    expect(texts.notHeard, 'Could not hear that. Try again, or type it.');
    expect(texts.noMic, 'The mic could not be used. Allow it, or type your message.');
  });
}
