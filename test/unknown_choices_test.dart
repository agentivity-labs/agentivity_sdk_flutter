import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A custom widget this app does not have must not swallow an agent's question: its options still show, and can be chosen.
void main() {
  Future<void> show(WidgetTester tester, Widget widget) => tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

  Map<String, dynamic> hotels(void Function(String) onSubmit) => {
        'hotels': [
          {'name': 'Casa Llum', 'neighborhood': 'Gòtic', 'total': 690, 'currency': 'EUR', 'recommended': true},
          {'name': 'Gràcia Rooms', 'reason': 'Calmer'},
        ],
        '__onSubmit': onSubmit,
      };

  testWidgets('the options of an unknown widget show, with what they say', (tester) async {
    await show(tester, AgUnknownChoices.fromProps(hotels((_) {}))!);

    expect(find.text('Casa Llum'), findsOneWidget);
    expect(find.text('Gòtic · 690 EUR'), findsOneWidget);
    expect(find.text('Gràcia Rooms'), findsOneWidget);
  });

  testWidgets('choosing one answers once', (tester) async {
    final answers = <String>[];
    await show(tester, AgUnknownChoices.fromProps(hotels(answers.add))!);

    await tester.tap(find.text('Casa Llum'));
    await tester.tap(find.text('Gràcia Rooms'));

    expect(answers, ['Choice: Casa Llum']);
  });

  test('a widget that only shows something stays out of the way', () {
    expect(AgUnknownChoices.fromProps(const {'title': 'Barcelona', 'image': 'x'}), isNull);
    expect(AgUnknownChoices.fromProps(const {'points': [1, 2, 3]}), isNull);
  });
}
