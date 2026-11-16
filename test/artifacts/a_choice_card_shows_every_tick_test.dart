import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Seen on the Desk (Contract Checker, agl 0.1.120): a card asking "Which flags do you want to raise
// with the supplier?" over 8 flags showed only the last one ticked. The card was declared
// single-select — one tick, and a second replaces it — so the plural question could not be answered.
// These two tests pin both halves: a card that allows several keeps every tick and sends them all,
// and a card that allows one says so by replacing, which is what the agent asked for there.

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  const flags = [
    {'id': '1', 'label': 'Flag 1 — Term and renewal'},
    {'id': '2', 'label': 'Flag 2 — Liability'},
    {'id': '3', 'label': 'Flag 3 — Governing law'},
  ];

  testWidgets('a card that allows several keeps every tick and sends them all', (tester) async {
    final answers = <String>[];
    await tester.pumpWidget(_wrap(AgChoiceCard(props: {
      'title': 'Select changes to request from Taldor Freight',
      'question': 'Which flags do you want to raise with the supplier?',
      'multiple': true,
      'options': flags,
      '__onSubmit': (String answer) => answers.add(answer),
    })));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Flag 1 — Term and renewal'));
    await tester.pump();
    await tester.tap(find.text('Flag 2 — Liability'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_box_rounded), findsNWidgets(2), reason: 'both ticks stay on screen');
    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(answers, ['Choice: Flag 1 — Term and renewal, Flag 2 — Liability']);
  });

  testWidgets('a card that allows one replaces the tick, and shows round buttons for it', (tester) async {
    final answers = <String>[];
    await tester.pumpWidget(_wrap(AgChoiceCard(props: {
      'title': 'Your decision',
      'multiple': false,
      'options': flags,
      '__onSubmit': (String answer) => answers.add(answer),
    })));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Flag 1 — Term and renewal'));
    await tester.pump();
    await tester.tap(find.text('Flag 2 — Liability'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_box_rounded), findsNothing);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(answers, ['Choice: Flag 2 — Liability']);
  });
}
