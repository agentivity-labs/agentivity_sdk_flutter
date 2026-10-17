import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The zones are really on screen. Geometry tests cannot see this: a zone can be computed right and never painted (it
// happened: the zones of a manager-led team were dropped on the way to the painter, in both looks, and no test said so).

TeamStructure _team(String orchestrator, {required bool grouped}) => TeamStructure(
  id: 't',
  name: 'Team',
  orchestratorId: orchestrator,
  members: [
    TeamMemberPosition(topologyPositionId: 'p0', memberEntityId: 'm0', displayName: 'Lead', group: grouped ? 'Lead' : null),
    for (var i = 1; i < 6; i++) TeamMemberPosition(topologyPositionId: 'p$i', memberEntityId: 'm$i', displayName: 'M$i', group: grouped ? (i < 4 ? 'Booking' : 'Money') : null),
  ],
  connections: const [],
);

/// How many pixels of the graph are a faint tint over the black ground: what a zone at about 11 % looks like.
Future<int> _faintPixels(WidgetTester tester, TeamStructure team, AgUiTeamZoneLook look) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(width: 400, height: 380, child: AgUiTeamGraph(members: team.toTeamMembers(), hubMemberId: team.hubMemberEntityId, restingColors: true, interactive: false, zoneLook: look)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  late ByteData data;
  await tester.runAsync(() async {
    final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
    data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  var faint = 0;
  for (var i = 0; i < data.lengthInBytes; i += 4) {
    final strongest = [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)].reduce((a, c) => a > c ? a : c);
    if (strongest > 6 && strongest < 45) faint++;
  }
  return faint;
}

void main() {
  for (final orchestrator in ['manager-led', 'handoff', 'sequential', 'concurrent', 'group-chat']) {
    for (final look in AgUiTeamZoneLook.values) {
      testWidgets('$orchestrator, ${look.name}: the groups are painted', (tester) async {
        final without = await _faintPixels(tester, _team(orchestrator, grouped: false), look);
        final withGroups = await _faintPixels(tester, _team(orchestrator, grouped: true), look);

        // Three zones of several members: thousands of pixels more than the same team without groups.
        expect(withGroups - without, greaterThan(6000), reason: 'faint pixels: $without without groups, $withGroups with');
      });
    }
  }
}
