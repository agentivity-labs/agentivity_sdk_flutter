import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _compass = IconRef.material('E248');

void main() {
  testWidgets('on a large graph a member keeps its proportions: the icon stays well inside its hexagon', (tester) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AgUiTeamGraph(
            hubMemberId: 'manager',
            restingColors: true,
            members: [
              AgUiTeamMember(memberEntityId: 'manager', displayName: 'Trip Manager', icon: _compass),
              AgUiTeamMember(memberEntityId: 'hotel', displayName: 'Restaurant Specialist', icon: _compass, group: 'Booking'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final hexagons = find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_HexPainter');
    expect(hexagons, findsNWidgets(2));
    for (final element in hexagons.evaluate()) {
      final hexagon = tester.getSize(find.byWidget(element.widget));
      final icon = tester.getSize(find.descendant(of: find.byWidget(element.widget), matching: find.byType(Icon)));
      expect(hexagon.width, closeTo(hexagon.height, 0.5));
      expect(icon.width, lessThan(hexagon.width * 0.6));
    }
  });
}
