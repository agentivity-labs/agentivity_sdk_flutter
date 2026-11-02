import 'dart:async';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _topology = AgUiTeamTopology(AgUiTeamTopologyKind.managerLed);
const _members = [
  AgUiTeamMember(memberEntityId: 'lead', displayName: 'Lead', topology: _topology),
  AgUiTeamMember(memberEntityId: 'a', displayName: 'Analyst', topology: _topology),
  AgUiTeamMember(memberEntityId: 'b', displayName: 'Writer', topology: _topology),
];

ExecutionMemberStep _step(String id, ExecutionStepState state, [String? result]) => ExecutionMemberStep(memberEntityId: id, state: state, result: result);

AgUiEvent _event(Map<String, dynamic> json) => AgUiEvent.fromJson({'executionId': 'e1', ...json});

ChatController _teamAtWork() {
  final c = ChatController.fromStream(events: StreamController<AgUiEvent>().stream);
  c.feedEvent(_event({'type': 'CUSTOM', 'name': 'CHAT_THREAD_CREATED', 'value': {'threadId': 't', 'isDefault': true}}));
  c.feedEvent(_event({'type': 'CUSTOM', 'name': 'CHAT_MESSAGE_RECEIVED', 'value': {'threadId': 't', 'messageId': 'u1', 'role': 'user', 'text': 'Write my report'}}));
  c.feedEvent(_event({'type': 'RUN_STARTED', 'runId': 'r'}));
  c.feedEvent(_event({'type': 'STEP_STARTED', 'stepName': 's', 'memberEntityId': 'lead', 'displayName': 'Lead'}));
  c.feedEvent(_event({'type': 'STEP_FINISHED', 'stepName': 's', 'memberEntityId': 'lead'}));
  c.feedEvent(_event({'type': 'STEP_STARTED', 'stepName': 's', 'memberEntityId': 'a', 'displayName': 'Analyst'}));
  return c;
}

AgUiTeamProgressSource _source(ExecutionStatuses? Function() statuses, {bool team = true, String kind = 'team'}) => AgUiTeamProgressSource(
  fetchStatuses: (_) async => statuses(),
  fetchExecution: (id) async => ExecutionRecord(executionId: id, entityId: 't1', entityKind: kind, state: '', createdAt: DateTime.utc(2026, 1, 1, 10)),
  fetchTeam: (_) async => team
      ? const TeamStructure(id: 't1', name: 'T', orchestratorId: 'manager-led', members: [TeamMemberPosition(topologyPositionId: 'l', memberEntityId: 'lead', displayName: 'Lead'), TeamMemberPosition(topologyPositionId: 'x', memberEntityId: 'a', displayName: 'Analyst'), TeamMemberPosition(topologyPositionId: 'y', memberEntityId: 'b', displayName: 'Writer')])
      : throw StateError('refused'),
);

ExecutionStatuses _statuses(String state, Map<String, ExecutionMemberStep> steps) => ExecutionStatuses(executionState: state, nodes: const {}, members: {for (final e in steps.entries) e.key: e.value.state!}, memberSteps: steps, lastStepAt: DateTime.utc(2026, 1, 1, 10, 4, 32));

Widget _chat(ChatController c, {AgUiTeamProgressSource? source, bool show = true}) => MaterialApp(
  home: Scaffold(body: AgUiChatDiscussion(controller: c, autoLoad: false, teamProgressSource: source, showTeamProgress: show, showActiveMemberIndicator: true)),
);

/// Lets the reads of the widget come back; the moving mark never settles.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('summarizeForCustomer', () {
    test('takes the title of a result, without its Markdown', () {
      expect(summarizeForCustomer("# Tom's plan, safety-checked and corrected\n\nTom reported no injuries."), "Tom's plan, safety-checked and corrected");
      expect(summarizeForCustomer('**Training plan for Tom: 2 days a week.** All picks come from the catalogue.'), 'Training plan for Tom: 2 days a week');
    });

    test('skips a heading of a word or two', () {
      expect(summarizeForCustomer('**Rules**\n- **Protein at every meal.** Aim for 120 g a day.'), 'Protein at every meal');
    });

    test('cuts at a word, within a few words', () {
      final summary = summarizeForCustomer('word ' * 40)!;
      expect(summary.length, lessThanOrEqualTo(91));
      expect(summary.endsWith('word…'), isTrue);
    });

    test('gives nothing rather than what a team writes for itself', () {
      for (final text in ['@team Writer, please pick the exercises from the catalogue', 'I called `search_catalog` with these args', 'Calling the search_catalog tool on the data', '{"plan": "the whole plan"}', 'See https://example.com/internal for more', null]) {
        expect(summarizeForCustomer(text), isNull, reason: text);
      }
    });
  });

  group('buildTeamProgress', () {
    test('stays out of the way of a manager answering alone', () {
      expect(buildTeamProgress(executionId: 'e', members: _members, executionState: 'running', streamStatuses: const {'lead': TeamMemberStatus.working}).visible, isFalse);
    });

    test('needs no team definition: the progress lists every member and says who the manager is', () {
      final progress = buildTeamProgress(
        executionId: 'e1',
        executionState: 'running',
        steps: const {
          'lead': ExecutionMemberStep(memberEntityId: 'lead', displayName: 'Lead', state: ExecutionStepState.working, isManager: true),
          'a': ExecutionMemberStep(memberEntityId: 'a', displayName: 'Analyst', state: ExecutionStepState.done, result: 'The market grew by a third.'),
          'b': ExecutionMemberStep(memberEntityId: 'b', displayName: 'Writer'),
        },
      );
      expect(progress.agents.map((a) => (a.displayName, a.status, a.isManager)), [('Lead', TeamProgressStatus.working, true), ('Analyst', TeamProgressStatus.done, false), ('Writer', TeamProgressStatus.pending, false)]);
      expect(progress.visible, isTrue);
      expect(progress.total, 2);
    });

    test('says what an agent does as soon as the stream says it, ahead of the progress', () {
      final progress = buildTeamProgress(
        executionId: 'e1',
        executionState: 'running',
        streamStatuses: const {'a': TeamMemberStatus.working},
        streamActivities: const {'a': 'Picking your exercises'},
        steps: const {'a': ExecutionMemberStep(memberEntityId: 'a', state: ExecutionStepState.working, activity: 'Old words')},
      );
      expect(progress.agents.single.description, 'Picking your exercises');
    });

    test('a member not reached yet is listed by the progress, with no status to light up', () {
      final statuses = ExecutionStatuses.fromJson({
        'status': 'Running',
        'steps': [
          {'id': 'lead', 'name': 'Lead', 'status': 'Running', 'agentTopologyPositionId': 'l', 'isManager': true},
          {'id': 'b', 'name': 'Writer', 'status': 'Pending', 'agentTopologyPositionId': 'b'},
        ],
      });
      expect(statuses.members.containsKey('b'), isFalse);
      expect(statuses.memberSteps['b']?.displayName, 'Writer');
      expect(statuses.memberSteps['b']?.state, isNull);
      expect(statuses.memberSteps['lead']?.isManager, isTrue);
    });

    test('gives every member one line, the stream ahead of the inspector', () {
      final p = buildTeamProgress(executionId: 'e', members: _members, executionState: 'running', streamStatuses: const {'lead': TeamMemberStatus.done, 'a': TeamMemberStatus.working}, steps: {'a': _step('a', ExecutionStepState.done, 'old result')});
      expect(p.visible, isTrue);
      expect(p.agents.map((a) => a.status), [TeamProgressStatus.pending, TeamProgressStatus.working, TeamProgressStatus.pending]);
      expect(p.agents[1].result, isNull);
      expect((p.done, p.total), (0, 2));
    });

    test('never opens what the manager wrote: it is a brief for the team, or the answer itself', () {
      final p = buildTeamProgress(executionId: 'e', members: _members, executionState: 'completed', steps: {'lead': _step('lead', ExecutionStepState.done, '@team Writer, go'), 'a': _step('a', ExecutionStepState.done, 'The market grew by a third.')});
      final manager = p.agents.firstWhere((a) => a.isManager);
      expect(manager.result, isNull);
      expect(manager.description, isNull);
    });

    test('keeps those who took part once it ends, with how long it took', () {
      final p = buildTeamProgress(executionId: 'e', members: _members, executionState: 'completed', startedAt: DateTime.utc(2026, 1, 1, 10), lastStepAt: DateTime.utc(2026, 1, 1, 10, 4, 32), steps: {'lead': _step('lead', ExecutionStepState.done), 'a': _step('a', ExecutionStepState.done, 'The market grew by a third.')});
      expect(p.agents.map((a) => a.memberEntityId), ['lead', 'a']);
      expect(p.worked, 2);
      expect(p.duration, const Duration(minutes: 4, seconds: 32));
      expect(p.agents[1].description, 'The market grew by a third');
    });

    test('prefers the words of the platform', () {
      final working = buildTeamProgress(executionId: 'e', members: _members, executionState: 'running', steps: const {'a': ExecutionMemberStep(memberEntityId: 'a', state: ExecutionStepState.working, activity: 'Comparing three suppliers')});
      expect(working.agents[1].description, 'Comparing three suppliers');
      final done = buildTeamProgress(executionId: 'e', members: _members, executionState: 'completed', steps: const {'a': ExecutionMemberStep(memberEntityId: 'a', state: ExecutionStepState.done, summary: 'Found the best supplier', result: 'A long report on the suppliers.')});
      expect(done.agents.single.description, 'Found the best supplier');
    });

    test('goes by the stream alone when nothing else can be read', () {
      final p = buildTeamProgress(executionId: 'e', awaitingResponse: true, seenMembers: const {'lead': 'Lead', 'a': 'Analyst'}, streamStatuses: const {'lead': TeamMemberStatus.done, 'a': TeamMemberStatus.working});
      expect(p.phase, TeamProgressPhase.working);
      expect(p.visible, isTrue);
      expect(p.agents.map((a) => a.displayName), ['Lead', 'Analyst']);
    });

    test('reads where it stands', () {
      TeamProgressPhase phase({String state = '', bool question = false, bool failed = false}) => buildTeamProgress(executionId: 'e', executionState: state, questionPending: question, failed: failed).phase;
      expect(phase(state: 'running', question: true), TeamProgressPhase.waiting);
      expect(phase(state: 'failed'), TeamProgressPhase.failed);
      expect(phase(state: 'cancelled'), TeamProgressPhase.stopped);
      expect(phase(failed: true), TeamProgressPhase.failed);
      expect(phase(), TeamProgressPhase.done);
    });
  });

  test('a new execution starts its members afresh, the same as the React SDK', () {
    final c = _teamAtWork();
    expect(c.executionId, 'e1');
    expect(c.seenMembers['a'], 'Analyst');
    c.feedEvent(AgUiEvent.fromJson({'type': 'STEP_STARTED', 'stepName': 's', 'memberEntityId': 'b', 'displayName': 'Writer', 'executionId': 'e2'}));
    expect(c.executionId, 'e2');
    expect(c.seenMembers.keys, ['b']);
    expect(c.memberStatuses.containsKey('a'), isFalse);
  });

  test('the inspector gives each member with its result and when the last turn ended', () {
    final s = ExecutionStatuses.fromJson({
      'status': 'Completed',
      'steps': [
        {'id': 'a', 'name': 'Analyst', 'status': 'Completed', 'agentTopologyPositionId': 'x', 'outputs': {'output': 'Result'}},
      ],
      'callSequence': [
        {'occurredAt': '2026-01-01T10:04:32Z'},
      ],
    });
    expect(s.memberSteps['a'], const ExecutionMemberStep(memberEntityId: 'a', displayName: 'Analyst', state: ExecutionStepState.done, result: 'Result'));
    expect(s.lastStepAt, DateTime.utc(2026, 1, 1, 10, 4, 32));
  });

  group('in a chat', () {
    testWidgets('shows one line per agent, in place of the indicator', (tester) async {
      await tester.pumpWidget(_chat(_teamAtWork(), source: _source(() => _statuses('running', {'a': _step('a', ExecutionStepState.working)}))));
      await _settle(tester);
      expect(find.text('Writer'), findsOneWidget);
      expect(find.text('Waiting for its turn'), findsOneWidget);
      expect(find.text('Working on it…'), findsOneWidget);
      expect(find.text('Organizing the work'), findsOneWidget);
      expect(find.text('0 of 2 done'), findsOneWidget);
      expect(find.textContaining('is working on it'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('fits a phone width', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_chat(_teamAtWork(), source: _source(() => _statuses('running', {'a': ExecutionMemberStep(memberEntityId: 'a', state: ExecutionStepState.working, activity: 'A rather long description of what this agent is doing right now for the person')}))));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('collapses to one line above the answer when it ends, and opens an agent to read its result', (tester) async {
      final c = _teamAtWork();
      await tester.pumpWidget(_chat(c, source: _source(() => _statuses('completed', {'lead': _step('lead', ExecutionStepState.done), 'a': _step('a', ExecutionStepState.done, 'The market grew by a third.\n\nMore details follow.')}))));
      c.feedEvent(_event({'type': 'CUSTOM', 'name': 'CHAT_MESSAGE_RECEIVED', 'value': {'threadId': 't', 'messageId': 'm2', 'role': 'assistant', 'text': 'Your report is ready'}}));
      c.feedEvent(_event({'type': 'RUN_FINISHED', 'runId': 'r'}));
      await _settle(tester);

      final head = find.text('2 agents worked for 4 min 32 s');
      expect(head, findsOneWidget);
      expect(find.text('Analyst'), findsNothing);
      expect(tester.getTopLeft(find.text('Write my report')).dy, lessThan(tester.getTopLeft(head).dy));
      expect(tester.getTopLeft(head).dy, lessThan(tester.getTopLeft(find.text('Your report is ready')).dy));

      await tester.tap(head);
      await tester.pump();
      await tester.tap(find.text('Analyst'));
      await tester.pump();
      expect(find.text('More details follow.'), findsOneWidget);
      expect(find.text('Brought it all together'), findsOneWidget);
      await tester.tap(find.text('Lead'));
      await tester.pump();
      expect(find.text('Brought it all together'), findsOneWidget);
    });

    testWidgets('falls back on the names and statuses of the stream with no client', (tester) async {
      await tester.pumpWidget(_chat(_teamAtWork()));
      await _settle(tester);
      expect(find.text('Analyst'), findsOneWidget);
      expect(find.text('Lead'), findsOneWidget);
      expect(find.text('Writer'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('stops asking when the key may read nothing', (tester) async {
      var reads = 0;
      await tester.pumpWidget(
        _chat(
          _teamAtWork(),
          source: _source(() {
            reads++;
            return const ExecutionStatuses.refused();
          }, team: false),
        ),
      );
      await _settle(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Analyst'), findsOneWidget);
      expect(reads, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('can be turned off', (tester) async {
      await tester.pumpWidget(_chat(_teamAtWork(), show: false));
      await _settle(tester);
      expect(find.text('Your team is working'), findsNothing);
      expect(find.textContaining('is working on it'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows nothing for a standalone agent', (tester) async {
      final c = ChatController.fromStream(events: StreamController<AgUiEvent>().stream);
      c.feedEvent(_event({'type': 'RUN_STARTED', 'runId': 'r'}));
      await tester.pumpWidget(_chat(c, source: _source(() => _statuses('running', const {}), kind: 'agent')));
      await _settle(tester);
      expect(find.byType(AgUiChatTeamProgress), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
