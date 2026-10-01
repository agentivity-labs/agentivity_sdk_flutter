import 'dart:convert';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Map<String, dynamic> props) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 420, child: AgSourceInput(props: props)))));

void main() {
  group('AgSourceInput', () {
    testWidgets('shows the three sources by default and Continue is disabled until something is given', (tester) async {
      await tester.pumpWidget(_host({'title': 'Candidate CV'}));
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('Link'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets('a pasted text submits a {kind:text} envelope', (tester) async {
      String? sent;
      await tester.pumpWidget(_host({'title': 't', '__onSubmit': (String r) => sent = r}));
      await tester.tap(find.text('Paste'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Jane Doe — Senior Backend Engineer');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(jsonDecode(sent!), {'kind': 'text', 'content': 'Jane Doe — Senior Backend Engineer'});
      expect(find.textContaining('Sent — Pasted text'), findsOneWidget);
    });

    testWidgets('a link is only accepted when it is a valid http(s) URL', (tester) async {
      String? sent;
      await tester.pumpWidget(_host({'title': 't', '__onSubmit': (String r) => sent = r}));
      await tester.tap(find.text('Link'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'not a url');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'https://example.com/cv.pdf');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(jsonDecode(sent!), {'kind': 'url', 'url': 'https://example.com/cv.pdf'});
    });

    testWidgets('sources limits the tabs; a single source shows no tab bar', (tester) async {
      await tester.pumpWidget(_host({'title': 't', 'sources': ['paste']}));
      expect(find.text('Upload'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
