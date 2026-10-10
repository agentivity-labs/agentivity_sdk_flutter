import 'dart:convert';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _agent(String id, String name) => {
  'id': id,
  'name': name,
  'graph': {
    'id': 'g-$id',
    'entryNode': 'agent',
    'nodes': [
      {'id': 'agent', 'nodeType': 'ai.node', 'inputs': {}},
    ],
    'connections': [],
  },
};

final _team = {
  'id': 'team-1',
  'name': 'SEO team',
  'orchestratorId': 'manager-led',
  'managerAgentId': 'p1',
  'members': [
    {'topologyPositionId': 'p1', 'memberEntityId': 'a-lead', 'memberType': 'agent'},
    {'topologyPositionId': 'p2', 'memberEntityId': 'a-writer', 'memberType': 'agent'},
    {'topologyPositionId': 'p3', 'memberEntityId': 'a-reviewer', 'memberType': 'agent'},
  ],
  'connections': [],
};

final _workflow = {
  'id': 'wf-1',
  'name': 'Publish',
  'entryNode': 'start',
  'nodes': [
    {
      'id': 'start',
      'nodeType': 'core.start',
      'inputs': {},
      'metadata': {'displayName': 'Start'},
    },
    {
      'id': 'think',
      'nodeType': 'ai.llm.prompt',
      'inputs': {},
      'metadata': {'displayName': 'Think'},
    },
    {
      'id': 'send',
      'nodeType': 'core.http',
      'inputs': {},
      'metadata': {'displayName': 'Send'},
    },
  ],
  'connections': [
    {'from': 'start', 'to': 'think', 'fromPort': 'out', 'toPort': 'in'},
    {'from': 'think', 'to': 'send', 'fromPort': 'out', 'toPort': 'in'},
  ],
};

final _template = {
  'schema': 'agentivity.template',
  'schemaVersion': 1,
  'id': 'seo-factory',
  'version': '1.0.0',
  'name': 'SEO factory',
  'root': {'kind': 'team', 'id': 'team-1'},
  'entities': [
    {'kind': 'team', 'id': 'team-1', 'name': 'SEO team', 'entry': _team},
    {'kind': 'agent', 'id': 'a-lead', 'name': 'Content Manager', 'entry': _agent('a-lead', 'Content Manager')},
    {'kind': 'agent', 'id': 'a-writer', 'name': 'Writer', 'entry': _agent('a-writer', 'Writer')},
    {'kind': 'agent', 'id': 'a-reviewer', 'name': 'Reviewer', 'entry': _agent('a-reviewer', 'Reviewer')},
  ],
};

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: const Size(800, 600), disableAnimations: disableAnimations),
    child: Scaffold(body: SizedBox(width: 800, height: 500, child: child)),
  ),
);

WorkflowGraphStructure _structure(List<String> nodes, List<List<String>> edges, [String? entry]) => WorkflowGraphStructure(
  nodes: [for (final id in nodes) WorkflowGraphNode(id: id, displayName: id, nodeType: '', kind: WorkflowNodeKind.action)],
  edges: [for (final e in edges) WorkflowGraphEdge(from: e[0], to: e[1])],
  entryNodeId: entry,
);

void main() {
  group('AgUiTemplateGraph — a still picture, with no run and no chat', () {
    testWidgets('draws the team of a Template, naming each member from the Template', (tester) async {
      await tester.pumpWidget(_host(AgUiTemplateGraph(source: _template)));
      expect(find.byType(AgUiTeamGraph), findsOneWidget);
      expect(find.text('Writer'), findsWidgets);
      expect(find.text('Reviewer'), findsWidgets);
      final graph = tester.widget<AgUiTeamGraph>(find.byType(AgUiTeamGraph));
      expect(graph.controller, isNull);
      expect(graph.statuses, isNull);
      expect(graph.restingColors, isTrue);
    });

    testWidgets('draws a workflow as its flow', (tester) async {
      await tester.pumpWidget(_host(AgUiTemplateGraph(source: {'kind': 'workflow', 'name': 'Publish', 'entryJson': _workflow})));
      expect(find.byType(AgUiWorkflowGraph), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Think'), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);
    });

    testWidgets('draws the graph inside an agent', (tester) async {
      final solo = {..._agent('a1', 'Solo'), 'graph': {'id': 'g', 'entryNode': 'start', 'nodes': _workflow['nodes'], 'connections': _workflow['connections']}};
      await tester.pumpWidget(_host(AgUiTemplateGraph(source: solo)));
      expect(find.text('Think'), findsOneWidget);
    });

    testWidgets('accepts the JSON text of a Template', (tester) async {
      await tester.pumpWidget(_host(AgUiTemplateGraph(source: '{"schema":"agentivity.template","id":"x","root":{"kind":"workflow","id":"wf-1"},"entities":[{"kind":"workflow","id":"wf-1","name":"Publish","entry":${jsonEncode(_workflow)}}]}')));
      expect(find.byType(AgUiWorkflowGraph), findsOneWidget);
    });

    testWidgets('says so instead of throwing when there is nothing to draw', (tester) async {
      await tester.pumpWidget(_host(const AgUiTemplateGraph(source: {'hello': 'world'})));
      expect(find.textContaining('not a team, a workflow or an agent'), findsOneWidget);
      await tester.pumpWidget(_host(AgUiTemplateGraph(source: {'kind': 'workflow', 'name': 'Empty', 'entryJson': {'id': 'w', 'nodes': [], 'connections': []}})));
      expect(find.textContaining('no steps to draw'), findsOneWidget);
    });

    testWidgets('a lone node is drawn at its normal size, not zoomed to fill the box', (tester) async {
      final lone = {'id': 'w', 'entryNode': 'only', 'nodes': [{'id': 'only', 'nodeType': 'core.start', 'inputs': {}, 'metadata': {'displayName': 'Only'}}], 'connections': []};
      final layout = layoutWorkflowGraph(WorkflowGraphStructure.fromJson(lone));
      expect(layout.width, greaterThanOrEqualTo(880));
      expect(layout.height, greaterThanOrEqualTo(330));
      final at = layout.positions['only']!;
      expect(at.dx, closeTo(layout.width / 2, 0.01));
      expect(at.dy, closeTo(layout.height / 2, 0.01));
    });
  });

  group('AgUiTemplateGraph — autoplay', () {
    testWidgets('lights the members up one after the other, then rests', (tester) async {
      await tester.pumpWidget(_host(AgUiTemplateGraph(source: _template, autoplay: true, stepDuration: const Duration(seconds: 1))));
      Map<String, TeamMemberStatus>? statuses() => tester.widget<AgUiTeamGraph>(find.byType(AgUiTeamGraph)).statuses;
      expect(statuses(), {'a-lead': TeamMemberStatus.working});
      await tester.pump(const Duration(seconds: 1));
      expect(statuses(), {'a-lead': TeamMemberStatus.done, 'a-writer': TeamMemberStatus.working});
      // members: 3, then a round of "all done", then at rest
      await tester.pump(const Duration(seconds: 3));
      expect(statuses(), isEmpty);
      // Take the widget off the tree so no timer is left running.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('does nothing unless asked to', (tester) async {
      await tester.pumpWidget(_host(AgUiTemplateGraph(source: _template)));
      await tester.pump(const Duration(seconds: 10));
      expect(tester.widget<AgUiTeamGraph>(find.byType(AgUiTeamGraph)).statuses, isNull);
    });

    testWidgets('stays still for a visitor who prefers reduced motion', (tester) async {
      await tester.pumpWidget(_host(AgUiTemplateGraph(source: _template, autoplay: true, stepDuration: const Duration(milliseconds: 500)), disableAnimations: true));
      await tester.pump(const Duration(seconds: 5));
      expect(tester.widget<AgUiTeamGraph>(find.byType(AgUiTeamGraph)).statuses, isNull);
    });

    testWidgets('plays a workflow too', (tester) async {
      await tester.pumpWidget(_host(AgUiTemplateGraph(source: _workflow, autoplay: true, stepDuration: const Duration(milliseconds: 500))));
      expect(tester.widget<AgUiWorkflowGraph>(find.byType(AgUiWorkflowGraph)).statuses, {'start': WorkflowStepStatus.working});
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('agUiWorkflowWalk — the order a run goes through a workflow', () {
    test('starts at the entry node and follows the edges', () {
      expect(agUiWorkflowWalk(_structure(['c', 'a', 'b'], [['a', 'b'], ['b', 'c']], 'a')), ['a', 'b', 'c']);
    });

    test('goes through each branch of a decision, and never loops', () {
      expect(
        agUiWorkflowWalk(_structure(['a', 'b', 'c', 'd'], [['a', 'b'], ['a', 'c'], ['b', 'd'], ['c', 'd'], ['d', 'a']], 'a')),
        ['a', 'b', 'c', 'd'],
      );
    });

    test('leaves what is not reachable for last', () {
      expect(agUiWorkflowWalk(_structure(['a', 'b', 'lonely'], [['a', 'b']], 'a')), ['a', 'b', 'lonely']);
    });
  });

  group('AgUiTemplateGraph — a picture on a page that scrolls', () {
    testWidgets('leaves the gestures to the page by default: no fit button, no recenter button', (tester) async {
      await tester.pumpWidget(_host(AgUiTemplateGraph(source: _template)));
      expect(find.byTooltip('Fit to view'), findsNothing);
      expect(tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).panEnabled, isFalse);
      expect(tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).scaleEnabled, isFalse);

      await tester.pumpWidget(_host(AgUiTemplateGraph(source: _workflow)));
      expect(find.byTooltip('Recenter on the active step'), findsNothing);
      expect(tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).panEnabled, isFalse);
    });

    testWidgets('zooms and offers to fit when asked to be interactive', (tester) async {
      await tester.pumpWidget(_host(AgUiTemplateGraph(source: _template, interactive: true)));
      expect(find.byTooltip('Fit to view'), findsOneWidget);
      expect(tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).scaleEnabled, isTrue);
      await tester.pumpWidget(_host(AgUiTemplateGraph(source: _workflow, interactive: true)));
      expect(find.byTooltip('Recenter on the active step'), findsOneWidget);
    });
  });

  test('agUiPlaybackStatuses walks, rounds up, and rests', () {
    Map<String, String> at(int step) => agUiPlaybackStatuses<String>(['a', 'b'], step, working: 'working', done: 'done');
    expect(at(0), {'a': 'working'});
    expect(at(1), {'a': 'done', 'b': 'working'});
    expect(at(2), {'a': 'done', 'b': 'done'});
    expect(at(3), isEmpty);
  });
}
