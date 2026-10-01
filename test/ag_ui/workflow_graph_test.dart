import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:agentivity_sdk/src/ag_ui/panels/chat/workflow_graph_layout.dart';
import 'package:agentivity_sdk/src/client/app_client/domain/workflow_graph_models.dart';
// ignore: unused_import
import 'package:agentivity_sdk/src/client/app_client/domain/execution_status_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// A trimmed version of a real workflow definition's shape (same fields the backend's
/// `GET /workflows/{id}` returns) — a straight chain plus one `core.if` branch, one resource
/// binding (an LLM model, via a `resource` port) that must be excluded from the flow graph.
Map<String, dynamic> _rawDefinition() => {
  'entryNode': 'start',
  'nodes': [
    {
      'id': 'start',
      'nodeType': 'interaction.human',
      'metadata': {'displayName': 'Intro Message'},
    },
    {
      'id': 'llm',
      'nodeType': 'ai.llm.model.anthropic',
      'metadata': {'displayName': 'LLM Model'},
    },
    {
      'id': 'summarize',
      'nodeType': 'ai.llm.prompt',
      'metadata': {'displayName': 'Summarize'},
    },
    {
      'id': 'route',
      'nodeType': 'core.if',
      'inputs': {
        'true_branch_label': 'Auto-approve',
        'false_branch_label': 'Needs review',
      },
      'metadata': {'displayName': 'Score >= 75?'},
    },
    {
      'id': 'approved',
      'nodeType': 'ai.llm.prompt',
      'metadata': {'displayName': 'Finalize — Approved'},
    },
    {
      'id': 'rejected',
      'nodeType': 'ai.llm.prompt',
      'metadata': {'displayName': 'Finalize — Rejected'},
    },
  ],
  'connections': [
    {'from': 'start', 'fromPort': 'out', 'to': 'summarize', 'toPort': 'in'},
    {'from': 'summarize', 'fromPort': 'out', 'to': 'route', 'toPort': 'in'},
    {'from': 'route', 'fromPort': 'true', 'to': 'approved', 'toPort': 'in'},
    {'from': 'route', 'fromPort': 'false', 'to': 'rejected', 'toPort': 'in'},
    {'from': 'llm', 'fromPort': 'resource', 'to': 'summarize', 'toPort': 'llm_model'},
  ],
};

void main() {
  executionStatusTests();
  group('WorkflowGraphStructure.fromJson', () {
    test('keeps only flow-connected nodes, dropping resource bindings', () {
      final structure = WorkflowGraphStructure.fromJson(_rawDefinition());
      final ids = structure.nodes.map((n) => n.id).toSet();
      expect(ids, {'start', 'summarize', 'route', 'approved', 'rejected'});
      expect(ids.contains('llm'), isFalse);
      expect(structure.edges.length, 4);
    });

    test('the entry node is "start", a node with no outgoing edge is "end"', () {
      final structure = WorkflowGraphStructure.fromJson(_rawDefinition());
      final byId = {for (final n in structure.nodes) n.id: n};
      expect(byId['start']!.kind, WorkflowNodeKind.start);
      expect(byId['approved']!.kind, WorkflowNodeKind.end);
      expect(byId['rejected']!.kind, WorkflowNodeKind.end);
    });

    test('a decision node in between reads as "decision", carrying its branch labels', () {
      final structure = WorkflowGraphStructure.fromJson(_rawDefinition());
      final byId = {for (final n in structure.nodes) n.id: n};
      expect(byId['route']!.kind, WorkflowNodeKind.decision);
      final labels = {for (final e in structure.edges) e.from: e.label}..removeWhere(
        (k, v) => v == null,
      );
      expect(labels['route'], anyOf('Auto-approve', 'Needs review'));
      final routeEdges = structure.edges.where((e) => e.from == 'route').toList();
      expect(routeEdges.map((e) => e.label).toSet(), {'Auto-approve', 'Needs review'});
    });

    test('an empty definition parses to an empty graph, not an error', () {
      final structure = WorkflowGraphStructure.fromJson(const {});
      expect(structure.nodes, isEmpty);
      expect(structure.edges, isEmpty);
      expect(structure.entryNodeId, isNull);
    });
  });

  group('layoutWorkflowGraph', () {
    test('lays the chain out left to right, one column per step from the start', () {
      final structure = WorkflowGraphStructure.fromJson(_rawDefinition());
      final layout = layoutWorkflowGraph(structure);
      final startX = layout.positions['start']!.dx;
      final summarizeX = layout.positions['summarize']!.dx;
      final routeX = layout.positions['route']!.dx;
      expect(summarizeX, greaterThan(startX));
      expect(routeX, greaterThan(summarizeX));
      // The two branches share the same column (both one step past the decision).
      expect(layout.positions['approved']!.dx, layout.positions['rejected']!.dx);
      expect(layout.positions['approved']!.dx, greaterThan(routeX));
    });

    test('the two branches land on different rows, not stacked on each other', () {
      final structure = WorkflowGraphStructure.fromJson(_rawDefinition());
      final layout = layoutWorkflowGraph(structure);
      expect(layout.positions['approved']!.dy, isNot(layout.positions['rejected']!.dy));
    });

    test('a retry loop back to an earlier node is reported as a back edge, not laid out forward', () {
      final looping = {
        'entryNode': 'a',
        'nodes': [
          {'id': 'a', 'nodeType': 'ai.llm.prompt', 'metadata': {}},
          {'id': 'b', 'nodeType': 'ai.llm.prompt', 'metadata': {}},
        ],
        'connections': [
          {'from': 'a', 'fromPort': 'out', 'to': 'b', 'toPort': 'in'},
          {'from': 'b', 'fromPort': 'out', 'to': 'a', 'toPort': 'in'},
        ],
      };
      final structure = WorkflowGraphStructure.fromJson(looping);
      final layout = layoutWorkflowGraph(structure);
      expect(layout.backEdges, contains(edgeKey('b', 'a')));
      expect(layout.backEdges.contains(edgeKey('a', 'b')), isFalse);
    });

    test('an empty graph lays out to a zero-size, empty layout', () {
      final layout = layoutWorkflowGraph(const WorkflowGraphStructure(nodes: [], edges: []));
      expect(layout.positions, isEmpty);
      expect(layout.width, 0);
      expect(layout.height, 0);
    });
  });
}

void executionStatusTests() {
  group('ExecutionStatuses.fromJson (inspector snapshot)', () {
    test('a team step (memberEntityId null, agentTopologyPositionId set) is keyed by its step id', () {
      final s = ExecutionStatuses.fromJson({
        'status': 'WaitingForInput',
        'steps': [
          {'id': 'entity-1', 'status': 'Running', 'agentTopologyPositionId': 'flight', 'memberEntityId': null},
          {'id': 'node-1', 'status': 'Completed', 'agentTopologyPositionId': null},
        ],
      });
      expect(s.members['entity-1'], ExecutionStepState.working);
      expect(s.nodes.containsKey('entity-1'), isFalse);
      expect(s.nodes['node-1'], ExecutionStepState.done);
    });

    Map<String, dynamic> body(String status) => {
      'status': status,
      'steps': [
        {'id': 'a', 'status': 'Completed'},
        {'id': 'b', 'status': 'Running'},
        {'id': 'c', 'status': 'Pending'},
        {'id': 'd', 'status': 'Failed'},
        {'id': 'x1', 'status': 'Completed', 'memberEntityId': 'flight'},
        {'id': 'x2', 'status': 'Running', 'memberEntityId': 'hotel'},
      ],
    };

    test('workflow nodes and team members are read from the same snapshot; pending steps are left out', () {
      final s = ExecutionStatuses.fromJson(body('Running'));
      expect(s.nodes, {'a': ExecutionStepState.done, 'b': ExecutionStepState.working, 'd': ExecutionStepState.failed});
      expect(s.members, {'flight': ExecutionStepState.done, 'hotel': ExecutionStepState.working});
      expect(s.isLive, isTrue);
    });

    test('a step waiting on a person reads as waiting', () {
      final s = ExecutionStatuses.fromJson({
        'status': 'WaitingForInput',
        'steps': [
          {'id': 'ask', 'status': 'WaitingForInput'},
        ],
      });
      expect(s.nodes['ask'], ExecutionStepState.waiting);
      expect(s.isLive, isTrue);
    });

    test('a finished execution is no longer live', () {
      expect(ExecutionStatuses.fromJson(body('Completed')).isLive, isFalse);
    });
  });
}
