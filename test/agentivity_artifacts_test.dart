import 'package:agentivity_artifacts/agentivity_artifacts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('AgArtifactCard', () {
    testWidgets('renders title and type badge', (tester) async {
      await tester.pumpWidget(_wrap(
        const AgArtifactCard(
          title: 'My Card',
          type: 'Test',
          child: Text('content'),
        ),
      ));
      expect(find.text('My Card'), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
    });
  });

  group('AgArtifactViewer', () {
    testWidgets('unknown type shows error widget', (tester) async {
      await tester.pumpWidget(_wrap(
        const AgArtifactViewer(
          type: 'DoesNotExist',
          props: {},
        ),
      ));
      expect(find.textContaining('Unknown artifact type: DoesNotExist'),
          findsOneWidget);
    });

    testWidgets('routes BarChart', (tester) async {
      await tester.pumpWidget(_wrap(
        const AgArtifactViewer(
          type: 'BarChart',
          props: {
            'title': 'Revenue',
            'labels': ['Q1', 'Q2'],
            'datasets': [
              {
                'label': '2024',
                'data': <num>[100, 200],
              },
            ],
          },
        ),
      ));
      await tester.pump();
      expect(find.text('Revenue'), findsOneWidget);
    });

    testWidgets('routes LineChart', (tester) async {
      await tester.pumpWidget(_wrap(
        const AgArtifactViewer(
          type: 'LineChart',
          props: {
            'title': 'Growth',
            'labels': ['Jan', 'Feb'],
            'datasets': [
              {
                'label': 'Users',
                'data': <num>[100, 200],
              },
            ],
          },
        ),
      ));
      await tester.pump();
      expect(find.text('Growth'), findsOneWidget);
    });

    testWidgets('routes MetricCard', (tester) async {
      await tester.pumpWidget(_wrap(
        const AgArtifactViewer(
          type: 'MetricCard',
          props: {'title': 'ARR', 'value': '€ 1.2M', 'trend': 'up'},
        ),
      ));
      await tester.pump();
      expect(find.text('ARR'), findsOneWidget);
      expect(find.text('€ 1.2M'), findsOneWidget);
    });

    testWidgets('routes KeyValue', (tester) async {
      await tester.pumpWidget(_wrap(
        const AgArtifactViewer(
          type: 'KeyValue',
          props: {
            'title': 'Order',
            'items': [
              {'key': 'Status', 'value': 'Shipped'},
            ],
          },
        ),
      ));
      await tester.pump();
      expect(find.text('Order'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Shipped'), findsOneWidget);
    });

    testWidgets('routes CodeBlock', (tester) async {
      await tester.pumpWidget(_wrap(
        const AgArtifactViewer(
          type: 'CodeBlock',
          props: {
            'title': 'Hello',
            'language': 'dart',
            'code': 'void main() {}',
          },
        ),
      ));
      await tester.pump();
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('routes JsonViewer', (tester) async {
      await tester.pumpWidget(_wrap(
        const AgArtifactViewer(
          type: 'JsonViewer',
          props: {
            'title': 'Response',
            'data': {'status': 'ok', 'count': 3},
          },
        ),
      ));
      await tester.pump();
      expect(find.text('Response'), findsOneWidget);
    });

    testWidgets('routes StatusCard success', (tester) async {
      await tester.pumpWidget(_wrap(
        const AgArtifactViewer(
          type: 'StatusCard',
          props: {
            'title': 'Done',
            'status': 'success',
            'message': 'All good',
          },
        ),
      ));
      await tester.pump();
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('All good'), findsOneWidget);
    });

    testWidgets('routes Timeline', (tester) async {
      await tester.pumpWidget(_wrap(
        const AgArtifactViewer(
          type: 'Timeline',
          props: {
            'title': 'Pipeline',
            'events': [
              {'label': 'Build', 'status': 'success', 'time': '09:00'},
            ],
          },
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Pipeline'), findsOneWidget);
      expect(find.text('Build'), findsOneWidget);
    });

    testWidgets('routes Svg', (tester) async {
      await tester.pumpWidget(_wrap(
        const AgArtifactViewer(
          type: 'Svg',
          props: {
            'title': 'Icon',
            'svg':
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
                    '<circle cx="5" cy="5" r="5"/></svg>',
          },
        ),
      ));
      await tester.pump();
      expect(find.text('Icon'), findsOneWidget);
    });
  });

  group('buildArtifactsRegistry', () {
    test('contains all expected type keys', () {
      final reg = buildArtifactsRegistry();
      const expected = [
        'BarChart',
        'LineChart',
        'PieChart',
        'AreaChart',
        'MetricCard',
        'StatGrid',
        'KeyValue',
        'CodeBlock',
        'JsonViewer',
        'StatusCard',
        'Timeline',
        'Latex',
        'Svg',
      ];
      for (final key in expected) {
        expect(reg.containsKey(key), isTrue, reason: 'Missing key: $key');
      }
    });

    testWidgets('registry builder returns a widget', (tester) async {
      final reg = buildArtifactsRegistry();
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => reg['BarChart']!(
            context,
            {
              'title': 'Test',
              'labels': ['A'],
              'datasets': [
                {'data': <num>[1]},
              ],
            },
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Test'), findsOneWidget);
    });
  });
}
