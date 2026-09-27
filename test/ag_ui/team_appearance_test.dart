import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Material code points, as Flutter's MaterialIcons font has them (Icons.explore / hotel / flight).
const _compass = IconRef.material('E248');
const _bed = IconRef.material('E322');
const _plane = IconRef.material('E297');

final _teamJson = {
  'id': 'team-1',
  'name': 'Trip Manager Team',
  'orchestratorId': 'manager-led',
  'managerAgentId': 'manager',
  'members': [
    {'topologyPositionId': 'manager', 'memberEntityId': 'agent-mgr', 'memberType': 'agent', 'displayName': 'Trip Manager', 'icon': _compass.toJson()},
    {'topologyPositionId': 'hotel', 'memberEntityId': 'agent-hotel', 'memberType': 'agent', 'displayName': 'Hotel Specialist', 'icon': _bed.toJson(), 'group': 'Booking'},
    {'topologyPositionId': 'flight', 'memberEntityId': 'agent-flight', 'memberType': 'agent', 'displayName': 'Flight Specialist', 'icon': _plane.toJson(), 'group': ' booking '},
    {'topologyPositionId': 'visa', 'memberEntityId': 'agent-visa', 'memberType': 'agent', 'displayName': 'Visa Specialist', 'group': 'Advice'},
  ],
  'connections': [
    {'fromTopologyPositionId': 'manager', 'toTopologyPositionId': 'hotel', 'types': ['Delegate']},
  ],
};

void main() {
  group('icon references', () {
    test('a Material reference is the MaterialIcons glyph at that code point', () {
      final glyph = agUiIcon(_bed)!;

      expect(glyph, Icons.hotel);
      expect(glyph.codePoint, 0xE322);
      expect(glyph.fontFamily, 'MaterialIcons');
      expect(agUiIcon(const IconRef.material('e297')), Icons.flight);
    });

    test('draws nothing for no icon, a set this SDK does not draw, or a value that is not a code point', () {
      expect(agUiIcon(null), isNull);
      expect(agUiIcon(const IconRef(type: 'simpleicons', value: 'wordpress')), isNull);
      expect(agUiIcon(const IconRef.material('hotel')), isNull);
      expect(agUiIcon(const IconRef.material('0')), isNull);
    });

    test('reads the shape the backend stores, and nothing else', () {
      expect(IconRef.tryParse({'type': 'Material', 'value': ' E322 '}), _bed);
      expect(IconRef.tryParse({'type': 'material', 'value': 'E322', 'color': '#fff'})?.color, '#fff');
      expect(IconRef.tryParse('E322'), isNull);
      expect(IconRef.tryParse({'type': 'material'}), isNull);
      expect(IconRef.tryParse(null), isNull);
      expect(_bed.toJson(), {'type': 'material', 'value': 'E322'});
    });

    test('reads a catalog entry, and turns it into the reference to store', () {
      final info = IconInfo.fromJson({'type': 'material', 'value': 'e322', 'name': 'hotel_baseline'});

      expect(info.value, 'E322');
      expect(info.name, 'hotel_baseline');
      expect(info.ref, _bed);
    });
  });

  group('team groups', () {
    test('groups get palette colors in order of first appearance, case-insensitively', () {
      final colors = agUiTeamGroupColors(['Booking', null, 'advice', ' booking ', 'Money']);

      expect(colors.keys.toList(), ['booking', 'advice', 'money']);
      expect(colors['booking'], agUiTeamGroupPalette[0]);
      expect(colors['advice'], agUiTeamGroupPalette[1]);
      expect(colors['money'], agUiTeamGroupPalette[2]);
    });

    test('uses the color the team editor chose for a group, and keeps the default order for the others', () {
      final team = TeamStructure.fromJson({
        ..._teamJson,
        'groupColors': {'booking': '#123abc', 'ghost': 'red', 'advice': '#zzz'},
      });
      final members = team.toTeamMembers();
      final colors = agUiTeamGroupColors(members.map((m) => m.group), custom: agUiGroupColorOverrides(members.map((m) => (group: m.group, groupColor: m.groupColor))));

      expect(team.groupColors, {'booking': '#123ABC'});
      expect(colors['booking'], const Color(0xFF123ABC));
      expect(colors['advice'], agUiTeamGroupPalette[1]);
      expect(agUiTeamAvatarResolver(members)(const AgUiChatMember(memberEntityId: 'agent-hotel'))?.color, const Color(0xFF123ABC));
    });

    test('colors cycle when there are more groups than palette entries', () {
      final many = [for (var i = 0; i < agUiTeamGroupPalette.length + 1; i++) 'g$i'];

      expect(agUiTeamGroupColors(many)['g${agUiTeamGroupPalette.length}'], agUiTeamGroupPalette[0]);
    });

    test('members are ordered so a group stays together, ungrouped last, original order kept inside', () {
      final ordered = agUiOrderByGroup<(String, String?)>([('a', 'X'), ('b', null), ('c', 'Y'), ('d', 'x'), ('e', 'Y'), ('f', null)], (m) => m.$2);

      expect(ordered.map((m) => m.$1).toList(), ['a', 'd', 'c', 'e', 'b', 'f']);
    });
  });

  group('TeamStructure', () {
    test('reads members with their icon and group, connections and the manager', () {
      final team = TeamStructure.fromJson(_teamJson);

      expect(team.orchestratorId, 'manager-led');
      expect(team.members, hasLength(4));
      expect(team.members[1].icon, _bed);
      expect(team.members[1].group, 'Booking');
      expect(team.members[3].icon, isNull);
      expect(team.connections.single.types, ['delegate']);
      expect(team.manager?.displayName, 'Trip Manager');
    });

    test('ignores an icon that is not a { type, value } reference', () {
      final team = TeamStructure.fromJson({
        'members': [
          {'topologyPositionId': 'a', 'memberEntityId': 'a', 'icon': 'E322'},
        ],
      });

      expect(team.members.single.icon, isNull);
    });

    test('becomes team members for the roster and the graph, with the hub being the manager', () {
      final team = TeamStructure.fromJson(_teamJson);
      final members = team.toTeamMembers();

      expect(members.map((m) => m.memberEntityId), ['agent-mgr', 'agent-hotel', 'agent-flight', 'agent-visa']);
      expect(members[1].icon, _bed);
      expect(team.hubMemberEntityId, 'agent-mgr');
    });

    test('a definition with nothing in it is empty, not an error', () {
      final team = TeamStructure.fromJson(const {});

      expect(team.members, isEmpty);
      expect(team.manager, isNull);
    });
  });

  group('drawing', () {
    testWidgets('an avatar with a catalog icon shows the glyph; an unknown icon falls back to initials', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MemberAvatarWidget(member: const AgUiChatMember(memberEntityId: 'a', displayName: 'Hotel Specialist'), resolver: (_) => const AgUiMemberAvatar(icon: _bed)),
                MemberAvatarWidget(member: const AgUiChatMember(memberEntityId: 'b', displayName: 'Zorblax Thing'), resolver: (_) => const AgUiMemberAvatar(icon: IconRef.material('not-hex'))),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.hotel), findsOneWidget);
      expect(find.text('ZT'), findsOneWidget);
    });

    testWidgets('an emoji the app chose wins over the icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberAvatarWidget(member: const AgUiChatMember(memberEntityId: 'a', displayName: 'Hotel Specialist'), resolver: (_) => const AgUiMemberAvatar(emoji: '🏨', icon: _bed)),
          ),
        ),
      );

      expect(find.text('🏨'), findsOneWidget);
      expect(find.byIcon(Icons.hotel), findsNothing);
    });

    testWidgets('the roster and the graph draw each member with the icon the team editor gave it', (tester) async {
      final controller = ChatController.fromStream(events: const Stream<AgUiEvent>.empty());
      final members = TeamStructure.fromJson(_teamJson).toTeamMembers();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AgUiTeamRoster(controller: controller, members: members),
                SizedBox(width: 400, child: AgUiTeamGraph(controller: controller, members: members, hubMemberId: 'agent-mgr')),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.hotel), findsNWidgets(2));
      expect(find.byIcon(Icons.flight), findsNWidgets(2));
      expect(find.byIcon(Icons.explore), findsNWidgets(2));
    });

    test('the team avatar resolver gives a chat the same icon and group color as the roster', () {
      final members = TeamStructure.fromJson(_teamJson).toTeamMembers();
      final resolve = agUiTeamAvatarResolver(members);

      final hotel = resolve(const AgUiChatMember(memberEntityId: 'agent-hotel', displayName: 'Hotel Specialist'));
      expect(hotel?.icon, _bed);
      expect(hotel?.color, agUiTeamGroupPalette[0]);
      expect(resolve(const AgUiChatMember(memberEntityId: 'nobody')), isNull);
    });

    test('an app-chosen avatar still comes first in the team avatar resolver', () {
      final members = TeamStructure.fromJson(_teamJson).toTeamMembers();
      final resolve = agUiTeamAvatarResolver(members, fallback: (m) => m.memberEntityId == 'agent-hotel' ? const AgUiMemberAvatar(emoji: '🏨') : null);

      final hotel = resolve(const AgUiChatMember(memberEntityId: 'agent-hotel'));
      expect(hotel?.emoji, '🏨');
      expect(hotel?.icon, _bed);
    });
  });
}
