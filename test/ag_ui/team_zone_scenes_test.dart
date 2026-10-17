import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:agentivity_sdk/src/ag_ui/panels/chat/team_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Whole teams in every layout and several frames: whatever the team and the layout, the zone of a group never passes over
// a member that is not its own. The same teams as the React SDK's `team-zone-scenes` test.

typedef _M = (String name, String? group);

/// A travel agency: a manager and twelve specialists in four groups of very different sizes.
const List<_M> _agency = [
  ('Trip Manager', null),
  ('On-Trip', 'Support'),
  ('Payment', 'Money'),
  ('Reservations', 'Money'),
  ('Flight', 'Booking'),
  ('Hotel', 'Booking'),
  ('Car Rental', 'Booking'),
  ('Restaurant & Dining', 'Booking'),
  ('Ground Transport', 'Booking'),
  ('Travel Insurance', 'Booking'),
  ('Activity Planner', 'Advice'),
  ('Visa & Documents', 'Advice'),
  ('Currency & Budget', 'Advice'),
];

/// The same agency with its groups shuffled through the team, as people really list their members.
final List<_M> _shuffled = [for (final i in [0, 4, 10, 2, 5, 1, 11, 6, 3, 7, 12, 8, 9]) _agency[i]];
const List<_M> _oneGroup = [('Trip Coord', 'Coordination'), ('Activities', 'Recommendations'), ('Flights', 'Recommendations'), ('Hotels', 'Recommendations')];
final List<_M> _seven = [('Lead', 'Lead'), for (final n in ['Flights', 'Hotels', 'Cars', 'Trains', 'Visa', 'Insurance', 'Dining']) (n, 'Services')];

final _teams = <String, List<_M>>{'agency': _agency, 'agency, groups shuffled': _shuffled, 'one group round the manager': _oneGroup, 'one group of seven': _seven};

const _frames = [Size(400, 380), Size(760, 340), Size(300, 560)];

SceneFrame _frame(Size size) => SceneFrame(
  width: size.width,
  height: size.height,
  center: size.center(Offset.zero),
  ringX: (size.width / 2 - 48).clamp(100, double.infinity),
  ringY: (size.height / 2 - 58).clamp(85, double.infinity),
);

double _toSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final length = ab.dx * ab.dx + ab.dy * ab.dy;
  final t = length == 0 ? 0.0 : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

bool _inside(Offset p, List<Offset> polygon) {
  var within = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) && p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) within = !within;
  }
  return within;
}

/// Whether [zone], drawn either way (bands, or organic with its areas and ties), passes over a hexagon standing at [at].
bool _passesOver(ZoneShape zone, Offset at) {
  const reach = zoneHalfWidth + 13 - 1;
  final bands = [...zone.links, ...zone.ties];
  final areas = [if (zone.filled) zone.points, ...zone.areas];
  return zone.points.any((p) => (p - at).distance < reach) ||
      bands.any((l) => _toSegment(at, l.$1, l.$2) < reach) ||
      areas.any((area) => _inside(at, area) || [for (var i = 0; i < area.length; i++) _toSegment(at, area[i], area[(i + 1) % area.length])].any((d) => d < reach));
}

TeamStructure _structure(String orchestrator, List<_M> members) => TeamStructure(
  id: 't',
  name: 'Team',
  orchestratorId: orchestrator,
  members: [
    for (var i = 0; i < members.length; i++) TeamMemberPosition(topologyPositionId: 'p$i', memberEntityId: 'm$i', displayName: members[i].$1, group: members[i].$2),
  ],
  connections: [
    if (orchestrator == 'handoff')
      for (var i = 0; i < members.length; i++) TeamConnectionDefinition(fromTopologyPositionId: 'p$i', toTopologyPositionId: 'p${(i + 1) % members.length}'),
  ],
);

void main() {
  const kinds = {
    'sequential': AgUiTeamTopologyKind.sequential,
    'concurrent': AgUiTeamTopologyKind.concurrent,
    'handoff': AgUiTeamTopologyKind.handoff,
    'group-chat': AgUiTeamTopologyKind.groupChat,
  };

  group('the zones of whole teams, layout by layout', () {
    for (final team in _teams.entries) {
      for (final kind in kinds.entries) {
        for (final size in _frames) {
          test('${team.key}, ${kind.key}, ${size.width.toInt()}×${size.height.toInt()}: no zone over a member of another group', () {
            final members = team.value;
            final all = [for (var i = 0; i < members.length; i++) 'm$i'];
            final groupOf = {for (var i = 0; i < members.length; i++) all[i]: members[i].$2};
            // As the graph does: a chain keeps the order of the team, every other layout puts a group's members together.
            final ids = kind.value == AgUiTeamTopologyKind.sequential ? all : agUiOrderByGroup(all, (id) => groupOf[id]);
            final frame = _frame(size);
            final scene = sceneFor(kind.value, ids, const [], frame, (id) => groupOf[id])!;
            final groups = groupsFor(scene, (id) => groupOf[id] == null ? null : (key: groupOf[id]!, name: groupOf[id]!), frame);

            expect(groups, isNotEmpty);
            for (final group in groups) {
              final strangers = [for (final m in scene.members) if (!group.ids.contains(m.id)) m];
              expect([for (final m in strangers) if (_passesOver(group.zone, m.at)) m.id], isEmpty, reason: 'zone of ${group.name}');
            }
          });
        }
      }
    }
  });

  group('whole teams are drawn, in every layout and both looks', () {
    for (final team in _teams.entries) {
      for (final orchestrator in ['manager-led', ...kinds.keys]) {
        for (final look in AgUiTeamZoneLook.values) {
          testWidgets('${team.key}, $orchestrator, ${look.name}', (tester) async {
            final structure = _structure(orchestrator, team.value);
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 620,
                      height: 560,
                      child: AgUiTeamGraph(members: structure.toTeamMembers(), hubMemberId: structure.hubMemberEntityId, restingColors: true, interactive: false, zoneLook: look),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();

            expect(tester.takeException(), isNull);
            // Every member is there, by its name.
            expect(find.byType(Tooltip), findsNWidgets(team.value.length));
          });
        }
      }
    }
  });

  test('the check itself sees a zone drawn over a stranger (the drawing this replaced)', () {
    const around = [Offset(200, 60), Offset(330, 270), Offset(70, 270)];
    const old = ZoneShape(points: around, links: [], filled: true);
    expect(_passesOver(old, const Offset(200, 190)), isTrue);
  });
}
