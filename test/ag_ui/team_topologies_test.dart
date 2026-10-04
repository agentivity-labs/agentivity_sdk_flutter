import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:agentivity_sdk/src/ag_ui/panels/chat/team_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _frame = SceneFrame(
  width: 400,
  height: 380,
  center: Offset(200, 190),
  ringX: 152,
  ringY: 132,
);

List<String> _ids(int n) => [for (var i = 0; i < n; i++) 'm$i'];

TeamStructure _team(String orchestrator, {int members = 3, List<(int, int)> links = const [], List<String?>? groups}) =>
    TeamStructure(
      id: 't',
      name: 'Team',
      orchestratorId: orchestrator,
      members: [
        for (var i = 0; i < members; i++)
          TeamMemberPosition(
            topologyPositionId: 'p$i',
            memberEntityId: 'm$i',
            displayName: 'Member $i',
            group: groups?[i],
          ),
      ],
      connections: [
        for (final (a, b) in links)
          TeamConnectionDefinition(fromTopologyPositionId: 'p$a', toTopologyPositionId: 'p$b'),
      ],
    );

ChatController _controller() => ChatController.fromStream(events: const Stream<AgUiEvent>.empty());

Future<void> _pump(WidgetTester tester, Widget graph) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: 400, height: 380, child: graph))),
  ),
);

void main() {
  group('agUiTeamTopology', () {
    test('maps each orchestrator to its kind', () {
      expect(agUiTeamTopology(_team('manager-led'))!.kind, AgUiTeamTopologyKind.managerLed);
      expect(agUiTeamTopology(_team('Sequential'))!.kind, AgUiTeamTopologyKind.sequential);
      expect(agUiTeamTopology(_team('concurrent'))!.kind, AgUiTeamTopologyKind.concurrent);
      expect(agUiTeamTopology(_team('handoff'))!.kind, AgUiTeamTopologyKind.handoff);
      expect(agUiTeamTopology(_team('group_chat'))!.kind, AgUiTeamTopologyKind.groupChat);
      expect(agUiTeamTopology(_team('something-else')), isNull);
    });

    test('turns connections into member links, dropping loops and duplicates', () {
      final topology = agUiTeamTopology(_team('handoff', links: [(0, 1), (0, 1), (1, 1), (1, 2)]))!;
      expect([for (final l in topology.links) '${l.from}>${l.to}'], ['m0>m1', 'm1>m2']);
    });

    test('toTeamMembers carries the topology on every member', () {
      final members = _team('sequential').toTeamMembers();
      expect(members.every((m) => m.topology?.kind == AgUiTeamTopologyKind.sequential), isTrue);
    });
  });

  group('layouts', () {
    test('sequential numbers members in order and links each to the next, with heads', () {
      final scene = sequentialScene(_ids(5), const [], _frame);
      expect([for (final m in scene.members) m.order], [1, 2, 3, 4, 5]);
      expect(scene.edges.length, 4);
      expect(scene.edges.every((e) => e.arrow), isTrue);
      expect(scene.edges.map((e) => e.lit), ['m1', 'm2', 'm3', 'm4']);
    });

    test('concurrent gives each member a lane of its own when there are few', () {
      final scene = concurrentScene(_ids(3), _frame);
      expect(scene.band, isNull);
      expect(scene.edges.length, 6);
      expect(scene.dots.map((d) => d.kind), [SceneDotKind.start, SceneDotKind.join]);
    });

    test('concurrent holds many members in one band, lit as a whole', () {
      final scene = concurrentScene(_ids(9), _frame);
      expect(scene.band, isNotNull);
      expect(scene.edges.map((e) => e.lit), [sceneLitAny, sceneLitAll]);
      for (final m in scene.members) {
        expect(scene.band!.contains(m.at), isTrue);
      }
    });

    test('handoff draws the given links and an entry on the first member', () {
      final scene = handoffScene(_ids(4), const [AgUiTeamLink('m0', 'm1'), AgUiTeamLink('m1', 'm2')], _frame);
      expect(scene.edges.map((e) => e.key), ['link-0', 'link-1', 'entry']);
      expect(scene.dots.single.kind, SceneDotKind.start);
    });

    test('group chat puts a shared conversation in the middle, a spoke to each member', () {
      final scene = groupChatScene(_ids(5), _frame);
      expect(scene.dots.single.kind, SceneDotKind.center);
      expect(scene.edges.length, 5);
      expect(scene.edges.any((e) => e.arrow), isFalse);
    });

    test('sceneFor leaves the manager-led kind to the constellation', () {
      expect(sceneFor(AgUiTeamTopologyKind.managerLed, _ids(3), const [], _frame), isNull);
    });

    test('group badges stay in the frame and clear of every member, on every topology', () {
      String? groupOf(String id) => int.parse(id.substring(1)) < 4 ? 'a' : 'b';
      for (final kind in [
        AgUiTeamTopologyKind.sequential,
        AgUiTeamTopologyKind.concurrent,
        AgUiTeamTopologyKind.handoff,
        AgUiTeamTopologyKind.groupChat,
      ]) {
        final scene = sceneFor(kind, _ids(8), const [], _frame, groupOf)!;
        final groups = groupsFor(scene, (id) => (key: groupOf(id)!, name: groupOf(id)!.toUpperCase()), _frame);
        expect(groups.map((g) => g.key).toSet(), {'a', 'b'}, reason: '$kind');
        for (final g in groups) {
          final w = scenePillWidth(g.name);
          final box = Rect.fromLTRB(g.label.dx - w / 2, g.label.dy - 8, g.label.dx + w / 2, g.label.dy + 8);
          expect(box.left >= 0 && box.right <= _frame.width && box.top >= 0 && box.bottom <= _frame.height, isTrue, reason: '$kind ${g.key}');
          for (final m in scene.members) {
            expect(box.overlaps(Rect.fromCenter(center: m.at, width: 30, height: 30)), isFalse, reason: '$kind ${g.key} over ${m.id}');
          }
        }
      }
    });
  });

  group('AgUiTeamGraph per topology', () {
    testWidgets('a sequential team shows its step numbers and every member', (tester) async {
      final members = _team('sequential', members: 4).toTeamMembers();
      await _pump(tester, AgUiTeamGraph(controller: _controller(), members: members));
      expect(tester.takeException(), isNull);
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TeamHexNode'), findsNWidgets(4));
      for (final n in ['1', '2', '3', '4']) {
        expect(find.text(n), findsOneWidget);
      }
    });

    testWidgets('concurrent, handoff and group-chat teams draw without error, grouped or not', (tester) async {
      for (final kind in ['concurrent', 'handoff', 'group-chat']) {
        for (final groups in [null, <String?>['A', 'A', 'B', 'B', 'B', 'C']]) {
          final team = _team(kind, members: 6, links: const [(0, 1), (1, 2), (2, 3)], groups: groups);
          await _pump(tester, AgUiTeamGraph(controller: _controller(), members: team.toTeamMembers()));
          expect(tester.takeException(), isNull, reason: '$kind $groups');
          expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TeamHexNode'), findsNWidgets(6));
        }
      }
    });

    testWidgets('a manager-led team keeps its hub', (tester) async {
      final team = _team('manager-led', members: 3);
      await _pump(tester, AgUiTeamGraph(controller: _controller(), members: team.toTeamMembers(), hubMemberId: 'm0'));
      expect(tester.takeException(), isNull);
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TeamHexNode'), findsNWidgets(3));
    });

    testWidgets('the topology prop wins over the one the members carry, and statuses light members', (tester) async {
      final c = _controller();
      final members = _team('handoff', members: 3).toTeamMembers();
      await _pump(
        tester,
        AgUiTeamGraph(controller: c, members: members, topology: const AgUiTeamTopology(AgUiTeamTopologyKind.groupChat)),
      );
      c.feedEvent(AgUiEvent.fromJson({'type': 'STEP_STARTED', 'stepName': 's', 'memberEntityId': 'm1', 'displayName': 'Member 1'}));
      await tester.pump();
      expect(find.bySemanticsLabel('Member 1, working now'), findsOneWidget);
      c.feedEvent(AgUiEvent.fromJson({'type': 'STEP_FINISHED', 'stepName': 's', 'memberEntityId': 'm1', 'displayName': 'Member 1'}));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('a chain in a tall, narrow frame (a side panel)', () {
    const tall = SceneFrame(width: 300, height: 808, center: Offset(150, 404), ringX: 102, ringY: 142);

    test('keeps its rows close together, centers the chain vertically and uses the width', () {
      final scene = sequentialScene(_ids(9), const [], tall);
      final ys = {for (final m in scene.members) m.at.dy.round()}.toList()..sort();
      expect(ys.length, greaterThan(2));
      for (var i = 1; i < ys.length; i++) {
        expect(ys[i] - ys[i - 1], lessThanOrEqualTo(118));
      }
      expect(((ys.first + ys.last) / 2 - tall.height / 2).abs(), lessThan(2));

      // Three columns, spread over the width.
      final xs = {for (final m in scene.members) m.at.dx.round()};
      expect(xs.length, 3);
      expect(xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b), greaterThan(120));
    });

    testWidgets('the graph draws in a 280 x 750 panel without error', (tester) async {
      final members = _team('sequential', members: 9).toTeamMembers();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: SizedBox(width: 280, height: 750, child: AgUiTeamGraph(controller: _controller(), members: members))),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TeamHexNode'), findsNWidgets(9));
    });
  });
}
