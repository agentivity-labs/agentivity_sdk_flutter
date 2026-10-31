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

    expect(palette.ai, const Color(0xFF123456));
    expect(palette.start, const Color(0xFF123456));
  });

  testWidgets('without a group it keeps the default colors', (tester) async {
    expect((await paletteOf(tester, null)).ai, const AgUiWorkflowPalette().ai);
  });
}
