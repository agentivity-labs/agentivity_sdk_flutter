import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 420, child: child))));

/// A dictation that fails says so in the field, in the app's words, until the person types: a mic that just stops looks broken.
void main() {
  const channel = MethodChannel('com.llfbandit.record/messages');

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  testWidgets('a mic that cannot be opened shows a card: how to allow it, Try again, and a close button', (tester) async {
    // No recorder on the test machine: opening the mic fails, as when it is refused.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isRecording') return false;
      if (call.method == 'create' || call.method == 'dispose' || call.method == 'stop') return null;
      throw PlatformException(code: 'denied', message: 'Microphone permission denied');
    });
    await tester.pumpWidget(_host(AgUiChatInput(onSend: (_, _) {}, onTranscribeAudio: (_, _) async => 'hello', voiceProblemTexts: const AgUiVoiceProblemTexts(noMic: 'Micro bloqué', noMicHow: 'Autorisez-le, puis réessayez.', tryAgain: 'Réessayer'))));

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ag-chat-input-mic-blocked')), findsOneWidget);
    expect(find.text('Micro bloqué'), findsOneWidget);
    expect(find.text('Autorisez-le, puis réessayez.'), findsOneWidget);

    // Try again asks for the mic again: still refused, the card stays.
    await tester.tap(find.byKey(const ValueKey('ag-chat-input-mic-try-again')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ag-chat-input-mic-blocked')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(find.byKey(const ValueKey('ag-chat-input-mic-blocked')), findsNothing);
  });

  testWidgets('a device without any mic is told so, not that its mic is blocked', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isRecording') return false;
      if (call.method == 'listInputDevices') return <Object?>[];
      if (call.method == 'create' || call.method == 'dispose' || call.method == 'stop') return null;
      throw PlatformException(code: 'denied', message: 'No microphone');
    });
    await tester.pumpWidget(_host(AgUiChatInput(onSend: (_, _) {}, onTranscribeAudio: (_, _) async => 'hello')));

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pumpAndSettle();
    expect(find.text('No mic found'), findsOneWidget);
    expect(find.text('Plug in a mic or a headset, then try again.'), findsOneWidget);
    expect(find.text('The mic is blocked'), findsNothing);
  });

  test('the default texts say what to do next, where the app runs', () {
    const texts = AgUiVoiceProblemTexts();
    expect(texts.notHeard, 'Could not hear that. Try again, or type it.');
    expect(texts.noMic, 'The mic is blocked');
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(texts.noMicHowHere(), contains('Settings > Privacy & security > Microphone'));
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(texts.noMicHowHere(), contains('System Settings > Privacy & Security > Microphone'));
    debugDefaultTargetPlatformOverride = null;
  });
}
