import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A chain of eight steps: wider than what a readable scale can show.
final _ids = ['start', 'read', 'think', 'route', 'write', 'check', 'send', 'end'];

final _longWorkflow = {
  'id': 'wf-long',
  'name': 'Long workflow',
  'entryNode': 'start',
  'nodes': [
    for (final id in _ids)
      {
        'id': id,
        'nodeType': id == 'start' ? 'core.start' : 'ai.llm.prompt',
        'inputs': {},
        'metadata': {'displayName': id},
      },
  ],
  'connections': [
    for (var i = 1; i < _ids.length; i++) {'from': _ids[i - 1], 'to': _ids[i], 'fromPort': 'out', 'toPort': 'in'},
  ],
};

final _team = {
  'id': 'team-1',
  'name': 'Team',
  'orchestratorId': 'manager-led',
  'managerAgentId': 'p1',
  'members': [
    {'topologyPositionId': 'p1', 'memberEntityId': 'a-lead', 'memberType': 'agent'},
    {'topologyPositionId': 'p2', 'memberEntityId': 'a-writer', 'memberType': 'agent'},
  ],
  'connections': [],
};

typedef _Camera = ({double scale, double dx, double dy});

/// The camera of the graph on screen: its scale and where the view is translated to.
_Camera _camera(WidgetTester tester) {
  final m = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!.value;
  return (scale: m.getMaxScaleOnAxis(), dx: m.storage[12], dy: m.storage[13]);
}

/// The camera that puts [id] in the middle of a [width] x [height] frame at the reading scale of the chat.
_Camera _centeredOn(String id, double width, double height) {
  final layout = layoutWorkflowGraph(WorkflowGraphStructure.fromJson(_longWorkflow));
  final scale = (layout.width / 360).clamp(0.4, 6.0);
  final at = layout.positions[id]!;
  return (scale: scale, dx: width / 2 - at.dx * scale, dy: height / 2 - at.dy * scale);
}

void _expectCamera(_Camera actual, _Camera expected) {
  expect(actual.scale, closeTo(expected.scale, 0.001));
  expect(actual.dx, closeTo(expected.dx, 0.5));
  expect(actual.dy, closeTo(expected.dy, 0.5));
}

Widget _framed(Widget child, {double width = 800, double height = 500, bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, height), disableAnimations: disableAnimations),
    child: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: width, height: height, child: child))),
  ),
);

void main() {
  group('AgUiTemplateGraph — camera on a workflow', () {
    testWidgets('is fit by default and is passed to the workflow graph', (tester) async {
      await tester.pumpWidget(_framed(AgUiTemplateGraph(source: _longWorkflow)));
      expect(tester.widget<AgUiWorkflowGraph>(find.byType(AgUiWorkflowGraph)).camera, AgUiWorkflowCamera.fit);

      await tester.pumpWidget(_framed(AgUiTemplateGraph(source: _longWorkflow, camera: AgUiWorkflowCamera.follow)));
      expect(tester.widget<AgUiWorkflowGraph>(find.byType(AgUiWorkflowGraph)).camera, AgUiWorkflowCamera.follow);
    });

    testWidgets('in fit, the whole diagram is in view', (tester) async {
      await tester.pumpWidget(_framed(AgUiTemplateGraph(source: _longWorkflow)));
      await tester.pump(const Duration(milliseconds: 50));
      final layout = layoutWorkflowGraph(WorkflowGraphStructure.fromJson(_longWorkflow));
      final scale = 800 / layout.width < 500 / layout.height ? 800 / layout.width : 500 / layout.height;
      expect(_camera(tester).scale, closeTo(scale, 0.001));
    });

    testWidgets('in follow, fills the size its parent gives it and opens on the start node at the reading scale', (tester) async {
      await tester.pumpWidget(_framed(AgUiTemplateGraph(source: _longWorkflow, camera: AgUiWorkflowCamera.follow)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getSize(find.byType(AgUiWorkflowGraph)), const Size(800, 500));
      _expectCamera(_camera(tester), _centeredOn('start', 800, 500));
      await tester.pump(const Duration(seconds: 10));
      _expectCamera(_camera(tester), _centeredOn('start', 800, 500));
    });

    testWidgets('in follow with no bounded height, is 16:9 and at least 240 high', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 800, child: AgUiTemplateGraph(source: _longWorkflow, camera: AgUiWorkflowCamera.follow)))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getSize(find.byType(AgUiWorkflowGraph)), const Size(800, 450));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 300, child: AgUiTemplateGraph(source: _longWorkflow, camera: AgUiWorkflowCamera.follow)))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getSize(find.byType(AgUiWorkflowGraph)).height, 240);
    });

    testWidgets('with autoplay, glides to each node that starts working and back to the start when the loop begins again', (tester) async {
      await tester.pumpWidget(
        _framed(AgUiTemplateGraph(source: _longWorkflow, camera: AgUiWorkflowCamera.follow, autoplay: true, stepDuration: const Duration(seconds: 2))),
      );
      await tester.pump(const Duration(milliseconds: 50));
      _expectCamera(_camera(tester), _centeredOn('start', 800, 500));

      // A tick of the playback every 2 s: the node that lights up pulls the camera, which then glides for 700 ms. The test clock is
      // 50 ms in, so the first tick is 1950 ms away and the following ones 1200 ms after the end of each glide (800 ms).
      var first = true;
      Future<void> step() async {
        await tester.pump(Duration(milliseconds: first ? 1950 : 1200));
        first = false;
        await tester.pump(const Duration(milliseconds: 800));
      }

      await step();
      _expectCamera(_camera(tester), _centeredOn('read', 800, 500));
      for (var i = 0; i < 6; i++) {
        await step();
      }
      _expectCamera(_camera(tester), _centeredOn('end', 800, 500));
      // 8 steps, then everything done, then at rest: the camera stays on the last node, then goes back to the start.
      await step();
      _expectCamera(_camera(tester), _centeredOn('end', 800, 500));
      await step();
      _expectCamera(_camera(tester), _centeredOn('end', 800, 500));
      await step();
      _expectCamera(_camera(tester), _centeredOn('start', 800, 500));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('stays a still picture on the start when the platform asks for reduced motion', (tester) async {
      await tester.pumpWidget(
        _framed(
          AgUiTemplateGraph(source: _longWorkflow, camera: AgUiWorkflowCamera.follow, autoplay: true, stepDuration: const Duration(milliseconds: 500)),
          disableAnimations: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 5));
      _expectCamera(_camera(tester), _centeredOn('start', 800, 500));
      expect(tester.widget<AgUiWorkflowGraph>(find.byType(AgUiWorkflowGraph)).statuses, isNull);
    });

    testWidgets('applies to the graph inside an agent and leaves a team alone', (tester) async {
      final agent = {
        'id': 'a1',
        'name': 'Solo',
        'graph': {'id': 'g', 'entryNode': 'start', 'nodes': _longWorkflow['nodes'], 'connections': _longWorkflow['connections']},
      };
      await tester.pumpWidget(_framed(AgUiTemplateGraph(source: agent, camera: AgUiWorkflowCamera.follow)));
      expect(tester.widget<AgUiWorkflowGraph>(find.byType(AgUiWorkflowGraph)).camera, AgUiWorkflowCamera.follow);

      await tester.pumpWidget(_framed(AgUiTemplateGraph(source: _team, camera: AgUiWorkflowCamera.follow)));
      expect(find.byType(AgUiTeamGraph), findsOneWidget);
      expect(find.byType(AgUiWorkflowGraph), findsNothing);
    });
  });
}
