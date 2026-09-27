import 'dart:async';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatController _controller() =>
    ChatController.fromStream(events: const Stream<AgUiEvent>.empty());

AgUiEvent _started(String id) => AgUiEvent.fromJson({
  'type': 'STEP_STARTED',
  'stepName': 's',
  'memberEntityId': id,
  'displayName': id,
});
AgUiEvent _finished(String id) => AgUiEvent.fromJson({
  'type': 'STEP_FINISHED',
  'stepName': 's',
  'memberEntityId': id,
  'displayName': id,
});

const _members = [
  AgUiTeamMember(memberEntityId: 'mgr', displayName: 'Trip Manager'),
  AgUiTeamMember(memberEntityId: 'hotel', displayName: 'Hotel Specialist'),
  AgUiTeamMember(memberEntityId: 'flight', displayName: 'Flight Specialist'),
];

void main() {
  group('ChatController.memberStatuses', () {
    test(
      'is empty until a Team member takes a turn, then follows STEP_STARTED / STEP_FINISHED',
      () {
        final c = _controller();
        expect(c.memberStatuses, isEmpty);

        c.feedEvent(_started('hotel'));
        expect(c.memberStatuses['hotel'], TeamMemberStatus.working);

        c.feedEvent(_finished('hotel'));
        expect(c.memberStatuses['hotel'], TeamMemberStatus.done);
        expect(c.memberStatuses.containsKey('flight'), isFalse);
      },
    );

    test(
      'shows a member working again when it is called back after finishing',
      () {
        final c = _controller();
        c.feedEvent(_started('hotel'));
        c.feedEvent(_finished('hotel'));
        c.feedEvent(_started('hotel'));
        expect(c.memberStatuses['hotel'], TeamMemberStatus.working);
      },
    );

    test(
      'never records a step that carries no member identity (a standalone Agent)',
      () {
        final c = _controller();
        c.feedEvent(
          AgUiEvent.fromJson({'type': 'STEP_STARTED', 'stepName': 's'}),
        );
        c.feedEvent(
          AgUiEvent.fromJson({'type': 'STEP_FINISHED', 'stepName': 's'}),
        );
        expect(c.memberStatuses, isEmpty);
      },
    );

    test(
      'marks a member still mid-turn as waiting when the run pauses for a human answer',
      () {
        final c = _controller();
        c.feedEvent(_started('hotel'));
        c.feedEvent(
          AgUiEvent.fromJson({
            'type': 'RUN_FINISHED',
            'runId': 'r1',
            'outcome': {
              'type': 'interrupt',
              'interrupts': [
                {
                  'id': 'req',
                  'reason': 'chat_hil_gate',
                  'metadata': {'threadId': 't1'},
                },
              ],
            },
          }),
        );
        expect(c.memberStatuses['hotel'], TeamMemberStatus.waiting);
      },
    );

    test(
      'settles a member still mid-turn as done when the run ends or fails',
      () {
        final finishedRun = _controller();
        finishedRun.feedEvent(_started('hotel'));
        finishedRun.feedEvent(
          AgUiEvent.fromJson({'type': 'RUN_FINISHED', 'runId': 'r1'}),
        );
        expect(finishedRun.memberStatuses['hotel'], TeamMemberStatus.done);

        final failedRun = _controller();
        failedRun.feedEvent(_started('hotel'));
        failedRun.feedEvent(
          AgUiEvent.fromJson({'type': 'RUN_ERROR', 'message': 'boom'}),
        );
        expect(failedRun.memberStatuses['hotel'], TeamMemberStatus.done);
      },
    );

    test('hands out a new map on every change and resets on clear()', () {
      final c = _controller();
      final before = c.memberStatuses;
      c.feedEvent(_started('hotel'));
      expect(identical(c.memberStatuses, before), isFalse);
      expect(before, isEmpty);

      c.clear();
      expect(c.memberStatuses, isEmpty);
    });
  });

  group('AgUiTeamRoster', () {
    testWidgets(
      'shows every member and reflects each one status as the run progresses',
      (tester) async {
        final c = _controller();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgUiTeamRoster(controller: c, members: _members),
            ),
          ),
        );

        expect(find.byType(MemberAvatarWidget), findsNWidgets(3));
        expect(
          find.bySemanticsLabel('Hotel Specialist, not needed yet'),
          findsOneWidget,
        );

        c.feedEvent(_started('hotel'));
        await tester.pump();
        expect(
          find.bySemanticsLabel('Hotel Specialist, working now'),
          findsOneWidget,
        );

        c.feedEvent(_finished('hotel'));
        await tester.pump();
        expect(find.bySemanticsLabel('Hotel Specialist, done'), findsOneWidget);
      },
    );
  });

  group('AgUiTeamGraph', () {
    testWidgets(
      'draws every member with the hub in the middle and lights the one at work',
      (tester) async {
        final c = _controller();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: AgUiTeamGraph(
                  controller: c,
                  members: _members,
                  hubMemberId: 'mgr',
                ),
              ),
            ),
          ),
        );

        expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TeamHexNode'), findsNWidgets(3));
        expect(find.text('Flight'), findsOneWidget);

        c.feedEvent(_started('flight'));
        await tester.pump();
        expect(
          find.bySemanticsLabel('Flight Specialist, working now'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Hotel Specialist, not needed yet'),
          findsOneWidget,
        );

        // Stop the repeating link animation so the test can end.
        c.feedEvent(_finished('flight'));
        await tester.pump();
      },
    );

    testWidgets(
      'shortens a long name under its node but keeps the full name for accessibility',
      (tester) async {
        final c = _controller();
        const long = [
          AgUiTeamMember(
            memberEntityId: 'r',
            displayName: 'Restaurant & Dining & Bar Specialist',
          ),
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: AgUiTeamGraph(controller: c, members: long),
              ),
            ),
          ),
        );

        expect(find.text('Restaurant & Di…'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            'Restaurant & Dining & Bar Specialist, not needed yet',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('fills the box it is given, and keeps its design aspect ratio when the height is open', (tester) async {
      final c = _controller();
      Widget host(Widget child) => MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)));

      // A tall, narrow box: the graph takes all of it.
      await tester.pumpWidget(
        host(SizedBox(width: 300, height: 500, child: AgUiTeamGraph(controller: c, members: _members, hubMemberId: 'mgr'))),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AgUiTeamGraph)), const Size(300, 500));

      // No height given: the width decides, at the design aspect ratio (400 : 380).
      await tester.pumpWidget(
        host(SizedBox(width: 400, child: AgUiTeamGraph(controller: c, members: _members, hubMemberId: 'mgr'))),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AgUiTeamGraph)), const Size(400, 380));
    });

    testWidgets('can be dragged and zoomed, and the fit button brings it back', (tester) async {
      final c = _controller();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 400, height: 380, child: AgUiTeamGraph(controller: c, members: _members, hubMemberId: 'mgr')),
            ),
          ),
        ),
      );
      final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      final view = viewer.transformationController!;
      expect(view.value, Matrix4.identity());

      // Drag: the graph moves.
      await tester.dragFrom(const Offset(200, 190), const Offset(60, 40));
      await tester.pump();
      expect(view.value, isNot(Matrix4.identity()));
      expect(view.value.getTranslation().x, greaterThan(0));

      // Zoom (the wheel): the graph scales.
      final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(const Offset(200, 190));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -200)));
      await tester.pump();
      expect(view.value.getMaxScaleOnAxis(), greaterThan(1));

      // Fit: back to the fitted view.
      await tester.tap(find.byTooltip('Fit to view'));
      await tester.pump();
      expect(view.value, Matrix4.identity());
    });
  });

  group('agUiTeamMemberShortName', () {
    test('drops the generic role word a name usually ends with', () {
      expect(agUiTeamMemberShortName('Flight Specialist'), 'Flight');
      expect(agUiTeamMemberShortName('Payment Agent'), 'Payment');
      expect(agUiTeamMemberShortName('On-Trip Assistant'), 'On-Trip');
      expect(
        agUiTeamMemberShortName('Currency & Budget Advisor'),
        'Currency & Budget',
      );
    });

    test(
      'keeps a name that is only the role word, or that does not end with one',
      () {
        expect(agUiTeamMemberShortName('Specialist'), 'Specialist');
        expect(agUiTeamMemberShortName('Trip Manager'), 'Trip Manager');
        expect(
          agUiTeamMemberShortName('  Activity Planner '),
          'Activity Planner',
        );
      },
    );
  });
}
