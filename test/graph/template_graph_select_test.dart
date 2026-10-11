import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _workflow = {
  'id': 'wf',
  'name': 'Flow',
  'entryNode': 'start',
  'nodes': [
    for (final id in ['start', 'write', 'send'])
      {
        'id': id,
        'nodeType': id == 'start' ? 'core.start' : 'ai.llm.prompt',
        'inputs': {},
        'metadata': {'displayName': id},
      },
  ],
  'connections': [
    {'from': 'start', 'to': 'write', 'fromPort': 'out', 'toPort': 'in'},
    {'from': 'write', 'to': 'send', 'fromPort': 'out', 'toPort': 'in'},
  ],
};

final _team = {
  'id': 'team-1',
  'name': 'Team',
  'orchestratorId': 'manager-led',
  'managerAgentId': 'p1',
  'members': [
    {'topologyPositionId': 'p1', 'memberEntityId': 'a-lead', 'memberType': 'agent', 'displayName': 'Lead'},
    {'topologyPositionId': 'p2', 'memberEntityId': 'a-writer', 'memberType': 'agent', 'displayName': 'Writer'},
  ],
  'connections': [],
};

Widget _framed(Widget child) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 800, height: 500, child: child))));

void main() {
  testWidgets('tapping a node of a workflow selects it', (tester) async {
    final picked = <AgUiGraphSelection>[];
    await tester.pumpWidget(_framed(AgUiTemplateGraph(source: _workflow, onSelect: picked.add)));
    await tester.pump();

    await tester.tap(find.text('write'));
    await tester.pump();

    expect(picked.single.kind, AgUiGraphSelectionKind.node);
    expect(picked.single.id, 'write');
  });

  testWidgets('tapping a member of a team selects it, by the entity it stands for', (tester) async {
    final picked = <AgUiGraphSelection>[];
    await tester.pumpWidget(_framed(AgUiTemplateGraph(source: _team, onSelect: picked.add)));
    await tester.pump();

    await tester.tap(find.text('Writer'));
    await tester.pump();

    expect(picked.single.kind, AgUiGraphSelectionKind.member);
    expect(picked.single.id, 'a-writer');
    expect(picked.single.displayName, 'Writer');
  });

  testWidgets('the selected element is the one named in the accent color', (tester) async {
    await tester.pumpWidget(_framed(AgUiTemplateGraph(source: _workflow, selectedId: 'send', onSelect: (_) {})));
    await tester.pump();

    final primary = Theme.of(tester.element(find.text('send'))).colorScheme.primary;
    expect(tester.widget<Text>(find.text('send')).style?.color, primary);
    expect(tester.widget<Text>(find.text('write')).style?.color, isNot(primary));
  });

  testWidgets('without onSelect the graph stays a picture: nothing is clickable', (tester) async {
    await tester.pumpWidget(_framed(AgUiTemplateGraph(source: _workflow)));
    await tester.pump();

    expect(find.ancestor(of: find.text('write'), matching: find.byType(GestureDetector)).evaluate().where((e) => (e.widget as GestureDetector).onTap != null), isEmpty);
  });
}
