import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _agent(Map<String, dynamic>? metadata) => {
      'id': 'a',
      'name': 'A',
      'graph': {
        'id': 'g',
        'name': 'G',
        'entryNode': 'ai',
        if (metadata != null) 'metadata': metadata,
        'nodes': [
          {'id': 'ai', 'nodeType': 'ai.node', 'inputs': {}},
        ],
        'connections': [],
      },
    };

void main() {
  Future<AgUiWorkflowPalette> paletteOf(WidgetTester tester, Map<String, dynamic>? metadata) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AgUiTemplateGraph(source: _agent(metadata)))));
    await tester.pump();
    return tester.widget<AgUiWorkflowGraph>(find.byType(AgUiWorkflowGraph)).palette;
  }

  testWidgets('an agent wears the color of its group', (tester) async {
    final palette = await paletteOf(tester, {'group': 'Sales', 'groupColor': '#123456'});

    expect(palette.node, const Color(0xFF123456));
  });

  testWidgets('without a group it keeps the default colors', (tester) async {
    expect((await paletteOf(tester, null)).node, const AgUiWorkflowPalette().node);
  });

  test('a workflow knows the group of its steps and the colors chosen for them', () {
    final structure = WorkflowGraphStructure.fromJson({
      'entryNode': 'a',
      'metadata': {
        'groupColors': {'crew': '#123456'},
      },
      'nodes': [
        {'id': 'a', 'nodeType': 'ai.node', 'metadata': {'group': ' Crew '}},
        {'id': 'b', 'nodeType': 'ai.node'},
      ],
      'connections': [
        {'from': 'a', 'to': 'b', 'fromPort': 'out', 'toPort': 'in'},
      ],
    });

    expect(structure.nodes.first.group, 'Crew');
    expect(structure.nodes.last.group, isNull);
    expect(structure.groupColors, {'crew': '#123456'});
  });
}
