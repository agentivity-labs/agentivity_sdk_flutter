import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Seen on the Desk (Contract Checker, image 0.1.120): every card an agent showed carried its own
// kind as a grey tag beside the title — "Key-Value" on each flag, "Select" on the decision card.
// Every user saw it, and it read as a debug tag. A card shows its title and its content; the badge
// is left for something the content does not say (a code block's language, a status's outcome).

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  const kinds = <String>[
    'Key–Value', 'Key-Value', 'Select', 'Multi-select', 'Metric', 'Confirmation',
    'Rating', 'Summary', 'Source', 'Date', 'Period', 'Timeline', 'Images',
    'LaTeX', 'SVG', 'JSON', 'Bar Chart', 'Line Chart', 'Area Chart',
    'Pie Chart', 'Donut Chart', 'Radar',
  ];

  Future<void> expectsNoKindTag(WidgetTester tester, Widget card) async {
    await tester.pumpWidget(_wrap(card));
    await tester.pumpAndSettle();
    for (final kind in kinds) {
      expect(find.text(kind), findsNothing, reason: '${card.runtimeType} shows its kind as "$kind"');
    }
  }

  testWidgets('a KeyValue card shows its title, not "Key-Value"', (tester) async {
    await expectsNoKindTag(tester, const AgKeyValue(props: {
      'title': 'Flag 1 — RED LINE — Rule 7 Personal data',
      'items': [
        {'key': 'Clause', 'value': '12.3'},
        {'key': 'Severity', 'value': 'Red line'},
      ],
    }));
    expect(find.text('Flag 1 — RED LINE — Rule 7 Personal data'), findsOneWidget);
    expect(find.text('Red line'), findsOneWidget);
  });

  testWidgets('a ChoiceCard shows its question, not "Select"', (tester) async {
    await expectsNoKindTag(tester, const AgChoiceCard(props: {
      'title': 'Your decision',
      'question': 'Sign, negotiate or refuse?',
      'options': [
        {'id': 'sign', 'label': 'Sign'},
        {'id': 'refuse', 'label': 'Refuse'},
      ],
    }));
    expect(find.text('Your decision'), findsOneWidget);
    expect(find.text('Sign, negotiate or refuse?'), findsOneWidget);
  });

  testWidgets('a MetricCard shows its value, not "Metric"', (tester) async {
    await expectsNoKindTag(tester, const AgMetricCard(props: {'title': 'Contracts reviewed', 'value': '12'}));
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('a status card keeps its outcome, which the content does not say', (tester) async {
    await tester.pumpWidget(_wrap(const AgArtifactViewer(
      type: 'StatusCard',
      props: {'title': 'Review', 'status': 'success', 'message': 'All good'},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('All good'), findsOneWidget);
  });
}
