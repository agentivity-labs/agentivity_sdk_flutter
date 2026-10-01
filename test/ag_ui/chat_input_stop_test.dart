import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 420, child: child))));

void main() {
  group('AgUiChatInput stop button', () {
    testWidgets('while a run works and onStop is given, the send button becomes a stop button that calls onStop', (tester) async {
      var stopped = 0;
      var sent = 0;
      await tester.pumpWidget(_host(AgUiChatInput(onSend: (_, _) => sent++, running: true, onStop: () => stopped++)));

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.stop_rounded));
      expect(stopped, 1);
      expect(sent, 0);
    });

    testWidgets('without onStop the input behaves as before, even while running', (tester) async {
      await tester.pumpWidget(_host(AgUiChatInput(onSend: (_, _) {}, running: true)));
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('when the run is not working the send button is back', (tester) async {
      await tester.pumpWidget(_host(AgUiChatInput(onSend: (_, _) {}, running: false, onStop: () {})));
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('a stop request in flight shows a spinner, not a second stop button', (tester) async {
      await tester.pumpWidget(_host(AgUiChatInput(onSend: (_, _) {}, running: true, onStop: () {}, stopping: true)));
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
