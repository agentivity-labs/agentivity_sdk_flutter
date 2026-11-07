import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))));

void main() {
  testWidgets('a tap on a day chooses it; a day outside the window is not chosen', (tester) async {
    DateTime? chosen;
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => AgCalendar(
        value: chosen,
        shortcuts: false,
        firstDate: DateTime(2026, 11, 5),
        lastDate: DateTime(2026, 12, 31),
        onChanged: (d) => setState(() => chosen = d),
      ),
    )));
    // The month shown is today's when it is in the window; go to November 2026 whatever today is.
    while (find.text('November').evaluate().isEmpty || find.text('2026').evaluate().isEmpty) {
      final forward = DateTime.now().isBefore(DateTime(2026, 11));
      await tester.tap(find.byTooltip(forward ? 'Next month' : 'Previous month'));
      await tester.pumpAndSettle();
      if (find.text('2026').evaluate().isEmpty && !forward) break;
    }

    await tester.tap(find.text('3'));
    await tester.pump();
    expect(chosen, isNull);

    await tester.tap(find.text('18'));
    await tester.pumpAndSettle();
    expect(chosen, DateTime(2026, 11, 18));
  });

  testWidgets('a period is its first day, then its last, either way round', (tester) async {
    DateTime? start;
    DateTime? end;
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => AgCalendar(
        rangeMode: true,
        rangeStart: start,
        rangeEnd: end,
        shortcuts: false,
        firstDate: DateTime(2030, 3, 1),
        lastDate: DateTime(2030, 3, 31),
        onRangeChanged: (s, e) => setState(() {
          start = s;
          end = e;
        }),
      ),
    )));

    expect(find.text('March'), findsOneWidget);
    await tester.tap(find.text('20'));
    await tester.pump();
    expect((start, end), (DateTime(2030, 3, 20), null));
    await tester.tap(find.text('12'));
    await tester.pump();
    expect((start, end), (DateTime(2030, 3, 12), DateTime(2030, 3, 20)));
    // A whole period: the next tap starts another one.
    await tester.tap(find.text('25'));
    await tester.pump();
    expect((start, end), (DateTime(2030, 3, 25), null));
  });

  testWidgets('the name of the month opens the twelve months, to go far quickly', (tester) async {
    DateTime? chosen;
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => AgCalendar(value: chosen ?? DateTime(2031, 1, 10), shortcuts: false, onChanged: (d) => setState(() => chosen = d)),
    )));

    await tester.tap(find.text('January'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sep'));
    await tester.pumpAndSettle();
    expect(find.text('September'), findsOneWidget);
    await tester.tap(find.text('30'));
    expect(chosen, DateTime(2031, 9, 30));
  });

  testWidgets('a shortcut chooses in one tap', (tester) async {
    DateTime? chosen;
    await tester.pumpWidget(_host(StatefulBuilder(builder: (context, setState) => AgCalendar(value: chosen, onChanged: (d) => setState(() => chosen = d)))));

    await tester.tap(find.text('Tomorrow'));
    await tester.pump();
    final today = DateTime.now();
    expect(chosen, DateTime(today.year, today.month, today.day + 1));
  });

  testWidgets('in a dialog, a tap on a day answers with it', (tester) async {
    DateTime? answer;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => answer = await showAgDatePicker(context, initialDate: DateTime(2032, 5, 4)),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Tue 4 May 2032'), findsOneWidget);
    await tester.tap(find.text('21'));
    await tester.pumpAndSettle();
    expect(answer, DateTime(2032, 5, 21));
  });
}
