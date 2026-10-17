import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// In a manager-led team, the manager is the member at the top of the topology — the first one. Nothing names it.
void main() {
  TeamStructure team(String orchestratorId, [Map<String, dynamic> extra = const {}]) => TeamStructure.fromJson({
        'id': 'team-1',
        'name': 'Trip team',
        'orchestratorId': orchestratorId,
        'members': [
          {'topologyPositionId': 'planner', 'memberEntityId': 'a-planner', 'memberType': 'agent'},
          {'topologyPositionId': 'hotel', 'memberEntityId': 'a-hotel', 'memberType': 'agent'},
        ],
        ...extra,
      });

  test('the manager is the member at the top of a manager-led team', () {
    expect(team('manager-led').manager?.topologyPositionId, 'planner');
  });

  test('it is still the member at the top when an older file named another one', () {
    expect(team('manager-led', {'managerAgentId': 'hotel'}).manager?.topologyPositionId, 'planner');
  });

  test('a team that is not manager-led has no manager', () {
    expect(team('sequential').manager, isNull);
  });
}
