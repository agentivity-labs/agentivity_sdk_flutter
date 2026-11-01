import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// An input at rest asks for no frame. Its microphone used to breathe all the time, recording or not: every frame painted what
/// was around it, and on the web the page ran out of memory while a chat sat waiting for an answer.
void main() {
  testWidgets('the input of a chat asks for no frame while nothing happens', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AgUiChatInput(enableVoice: true, onSend: (_, __) {}))));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.hasRunningAnimations, isFalse);
  });
}
