import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

/// A recap reads its facts as label and value, the value on the right ("Price … $499"). A section marked "list" holds lines
/// of text instead (the steps of a plan): they read from the left, like any other text of the conversation.
void main() {
  TextAlign? alignOf(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).textAlign;

  testWidgets('a fact keeps its value on the right', (tester) async {
    await tester.pumpWidget(_wrap(const AgSummaryCard(props: {
      'sections': [
        {
          'items': [
            {'key': 'Price', 'value': r'$499'},
          ],
        },
      ],
    })));

    expect(alignOf(tester, r'$499'), TextAlign.right);
  });

  testWidgets('the lines of a list section read from the left', (tester) async {
    await tester.pumpWidget(_wrap(const AgSummaryCard(props: {
      'sections': [
        {
          'label': 'What I will build',
          'list': true,
          'items': [
            {'key': '1', 'value': 'A support team that answers customer e-mails from your own data and articles'},
          ],
        },
      ],
    })));

    expect(alignOf(tester, 'A support team that answers customer e-mails from your own data and articles'), TextAlign.left);
  });
}
