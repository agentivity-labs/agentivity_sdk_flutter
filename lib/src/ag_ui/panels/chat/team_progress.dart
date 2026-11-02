import 'package:flutter/foundation.dart';

import '../../../client/app_client/agentivity_client.dart';
import '../../../client/app_client/domain/entity_models.dart';
import '../../../client/app_client/domain/execution_status_models.dart';
import '../../../client/app_client/domain/team_definition_models.dart';
import 'chat_controller.dart';
import 'execution_statuses_controller.dart';
import 'team_topology.dart';
import 'team_views.dart';

/// Where one agent stands in the widget: [pending] is an agent not reached yet (or a manager between two turns).
enum TeamProgressStatus { pending, working, waiting, done, failed }

/// Where the execution stands: [working] and [waiting] can still change, the others are its end.
enum TeamProgressPhase { working, waiting, done, failed, stopped }

class TeamProgressAgent {
  const TeamProgressAgent({required this.memberEntityId, required this.displayName, this.member, required this.isManager, required this.status, this.description, this.result});

  final String memberEntityId;
  final String displayName;

  /// The member as the team defines it, when the app can read the team.
  final AgUiTeamMember? member;

  /// The manager of a manager-led team: what it writes is for its team or is the answer itself, so it has no result to open.
  final bool isManager;
  final TeamProgressStatus status;

  /// A few words for a customer on what it does or has done. Null, the widget says its status only.
  final String? description;

  /// Its result, in full (Markdown), once its turn is done.
  final String? result;
}

class TeamProgress {
  const TeamProgress({required this.executionId, required this.phase, required this.agents, required this.total, required this.done, required this.worked, this.duration, required this.visible, this.jobFinished = false, this.closed = false});

  final String executionId;
  final TeamProgressPhase phase;

  /// One line per agent: every member while it works, those that took part once it has ended.
  final List<TeamProgressAgent> agents;

  /// Agents other than the manager, and how many of them are done.
  final int total;
  final int done;

  /// How many agents took part, the manager included.
  final int worked;

  /// How long it took, once it has ended and the platform says.
  final Duration? duration;

  /// False until the team really works together: a manager answering alone needs no list.
  final bool visible;

  /// What the platform says of the execution: for a chat reopened after it happened.
  final bool jobFinished;
  final bool closed;

  /// True while the execution can still move on.
  bool get isLive => phase == TeamProgressPhase.working || phase == TeamProgressPhase.waiting;
}

TeamProgressPhase _phaseOf(String executionState, Map<String, TeamMemberStatus> stream, {required bool questionPending, required bool awaitingResponse, required bool failed}) {
  if (questionPending) return TeamProgressPhase.waiting;
  switch (executionState) {
    case 'pending' || 'running':
      return TeamProgressPhase.working;
    case 'paused' || 'waitingforinput':
      return TeamProgressPhase.waiting;
    case 'completed':
      return TeamProgressPhase.done;
    case 'failed':
      return TeamProgressPhase.failed;
    case 'cancelled' || 'interrupted':
      return TeamProgressPhase.stopped;
  }
  // The stream alone: it says nothing of the state of the execution, only what goes on.
  if (failed) return TeamProgressPhase.failed;
  if (awaitingResponse || stream.containsValue(TeamMemberStatus.working)) return TeamProgressPhase.working;
  return stream.containsValue(TeamMemberStatus.waiting) ? TeamProgressPhase.waiting : TeamProgressPhase.done;
}

TeamProgressStatus _fromStream(TeamMemberStatus status) => switch (status) {
  TeamMemberStatus.working => TeamProgressStatus.working,
  TeamMemberStatus.waiting => TeamProgressStatus.waiting,
  TeamMemberStatus.done => TeamProgressStatus.done,
  TeamMemberStatus.failed => TeamProgressStatus.failed,
};

TeamProgressStatus _fromStep(ExecutionStepState state) => switch (state) {
  ExecutionStepState.working => TeamProgressStatus.working,
  ExecutionStepState.waiting => TeamProgressStatus.waiting,
  ExecutionStepState.done => TeamProgressStatus.done,
  ExecutionStepState.failed => TeamProgressStatus.failed,
};

/// Puts together what the stream and the execution's progress say into one line per agent. Mirrors the React SDK's `buildTeamProgress`.
TeamProgress buildTeamProgress({
  required String executionId,
  List<AgUiTeamMember>? members,
  Map<String, TeamMemberStatus> streamStatuses = const {},
  Map<String, String?> seenMembers = const {},
  Map<String, String> streamActivities = const {},
  Map<String, ExecutionMemberStep> steps = const {},
  String executionState = '',
  DateTime? lastStepAt,
  DateTime? startedAt,
  bool questionPending = false,
  bool awaitingResponse = false,
  bool failed = false,
  bool jobFinished = false,
  bool closed = false,
}) {
  final team = members ?? const <AgUiTeamMember>[];
  final phase = _phaseOf(executionState, streamStatuses, questionPending: questionPending, awaitingResponse: awaitingResponse, failed: failed);
  final live = phase == TeamProgressPhase.working || phase == TeamProgressPhase.waiting;
  final managerId = team.isNotEmpty && team.first.topology?.kind == AgUiTeamTopologyKind.managerLed ? team.first.memberEntityId : steps.values.where((s) => s.isManager).firstOrNull?.memberEntityId;
  final byId = {for (final m in team) m.memberEntityId: m};
  final ids = {...byId.keys, ...steps.keys, ...seenMembers.keys};

  final agents = [
    for (final id in ids)
      () {
        final step = steps[id];
        final isManager = id == managerId;
        final fromStream = streamStatuses[id] == null ? null : _fromStream(streamStatuses[id]!);
        final fromStep = step?.state == null ? null : _fromStep(step!.state!);
        // The stream is ahead of the progress while it goes on, and an ended execution is what the progress says.
        var status = (live ? (fromStream ?? fromStep) : (fromStep ?? fromStream)) ?? TeamProgressStatus.pending;
        if (!live && (status == TeamProgressStatus.working || status == TeamProgressStatus.waiting)) status = TeamProgressStatus.done;
        // Between two turns a manager is not done: the team still works for it.
        if (isManager && live && status == TeamProgressStatus.done) status = TeamProgressStatus.pending;
        final worker = !isManager && status == TeamProgressStatus.done;
        return TeamProgressAgent(
          memberEntityId: id,
          displayName: byId[id]?.displayName ?? step?.displayName ?? seenMembers[id] ?? id,
          member: byId[id],
          isManager: isManager,
          status: status,
          description: isManager ? null : (status == TeamProgressStatus.working ? (streamActivities[id] ?? step?.activity) : (worker ? (step?.summary ?? summarizeForCustomer(step?.result)) : null)),
          result: worker ? step?.result : null,
        );
      }(),
  ];

  final acted = [
    for (final a in agents)
      if (a.status != TeamProgressStatus.pending || (a.isManager && (streamStatuses.containsKey(a.memberEntityId) || steps.containsKey(a.memberEntityId)))) a,
  ];
  final workers = agents.where((a) => !a.isManager);
  final workersActed = acted.where((a) => !a.isManager).length;
  return TeamProgress(
    executionId: executionId,
    phase: phase,
    agents: live ? agents : acted,
    total: workers.length,
    done: workers.where((a) => a.status == TeamProgressStatus.done).length,
    worked: acted.length,
    duration: !live && startedAt != null && lastStepAt != null && lastStepAt.isAfter(startedAt) ? lastStepAt.difference(startedAt) : null,
    // Without the team's definition the manager is not known: a second agent is what says they work together.
    visible: managerId != null ? workersActed > 0 : workersActed > 1,
    jobFinished: jobFinished,
    closed: closed,
  );
}

const _maxSummary = 90;

/// A line that is not for a customer: what a team writes for itself, code, and addresses.
final _notForACustomer = RegExp(r'@team|@context|`|[{}<>]|https?://|\b[a-z]+_[a-z_]+\b');

/// A few words for a customer out of an agent's result: its title when it has one, otherwise its first sentence. Taken from the
/// text, never made up. Anything that does not read as prose for a customer gives `null`: the widget then says only that the agent
/// is done. It stands in until the platform says it itself (the `summary` of a step). Mirrors the React SDK.
String? summarizeForCustomer(String? result) {
  if (result == null || result.isEmpty) return null;
  final first = result.split('\n').map(_cleanLine).where((line) => line.split(RegExp(r'\s+')).length >= 3).firstOrNull;
  if (first == null || _notForACustomer.hasMatch(first)) return null;
  final sentence = RegExp(r'^.+?[.!?](?=\s|$)').firstMatch(first)?.group(0) ?? first;
  final words = sentence.replaceFirst(RegExp(r'[.:;,]+$'), '');
  if (words.length <= _maxSummary) return words;
  return '${words.substring(0, _maxSummary).replaceFirst(RegExp(r'\s+\S*$'), '')}…';
}

String _cleanLine(String line) => line
    .replaceFirst(RegExp(r'^\s*(#{1,6}\s+|[-*+]\s+|\d+[.)]\s+|>\s*)'), '')
    .replaceAll(RegExp(r'\*\*|__'), '')
    .replaceAllMapped(RegExp(r'(^|\s)[*_](\S)'), (m) => '${m[1]}${m[2]}')
    .replaceAllMapped(RegExp(r'(\S)[*_](?=\s|$)'), (m) => '${m[1]}')
    .trim();

/// What the widget reads beyond the stream. All of it is optional for the widget: what fails only makes it say less.
class AgUiTeamProgressSource {
  const AgUiTeamProgressSource({required this.fetchStatuses, required this.fetchExecution, required this.fetchTeam});

  /// The platform's client.
  factory AgUiTeamProgressSource.of(AgentivityClient client) => AgUiTeamProgressSource(fetchStatuses: client.runs.fetchExecutionStatuses, fetchExecution: client.runs.fetchExecution, fetchTeam: client.entities.fetchTeam);

  final Future<ExecutionStatuses?> Function(String executionId) fetchStatuses;
  final Future<ExecutionRecord?> Function(String executionId) fetchExecution;
  final Future<TeamStructure> Function(String teamId) fetchTeam;
}

/// Where each agent of a team stands in the execution of a chat: what [AgUiChatTeamProgress] draws. What it can read decides how
/// much it says: the inspector gives each agent's result, the team's definition the agents not reached yet. Without them (no
/// [source], or a key for a web page) it goes by the stream alone: the names and statuses of the agents that took a turn.
/// Mirrors the React SDK's `useTeamProgress`.
class AgUiTeamProgressController extends ChangeNotifier {
  AgUiTeamProgressController({required ChatController chat, AgUiTeamProgressSource? source, String? executionId, List<AgUiTeamMember>? members, this.interval = const Duration(milliseconds: 2500)}) : _chat = chat, _source = source, _givenId = executionId, _givenMembers = members {
    _chat.addListener(_onChat);
    _follow(_givenId ?? _chat.executionId);
  }

  final ChatController _chat;
  final AgUiTeamProgressSource? _source;
  final String? _givenId;
  final List<AgUiTeamMember>? _givenMembers;

  /// How often the execution is read while it can change: the stream is ahead of it anyway.
  final Duration interval;

  String? _executionId;
  ExecutionStatusesController? _statuses;
  DateTime? _startedAt;
  String? _teamRead;
  List<AgUiTeamMember>? _teamMembers;
  bool _disposed = false;

  /// Where the team stands, or null while no execution is known.
  TeamProgress? get progress {
    final id = _executionId;
    if (id == null) return null;
    final fromStream = id == _chat.executionId;
    final statuses = _statuses;
    return buildTeamProgress(
      executionId: id,
      members: _givenMembers ?? _teamMembers,
      streamStatuses: fromStream ? _chat.memberStatuses : const {},
      seenMembers: fromStream ? _chat.seenMembers : const {},
      streamActivities: fromStream ? _chat.memberActivities : const {},
      steps: statuses?.memberSteps ?? const {},
      jobFinished: statuses?.jobFinished ?? false,
      closed: statuses?.closed ?? false,
      executionState: statuses?.executionState ?? '',
      lastStepAt: statuses?.lastStepAt,
      startedAt: _startedAt,
      questionPending: _chat.pendingHilGate != null,
      awaitingResponse: _chat.isAwaitingResponse,
      failed: _chat.runError != null,
    );
  }

  void _onChat() {
    final id = _givenId ?? _chat.executionId;
    if (id != _executionId) _follow(id);
    notifyListeners();
  }

  void _follow(String? id) {
    _executionId = id;
    _statuses?.dispose();
    _statuses = null;
    _startedAt = null;
    final source = _source;
    if (id == null || source == null) return;
    _statuses = ExecutionStatusesController(fetch: () => source.fetchStatuses(id), chat: _chat, interval: interval)..addListener(notifyListeners);
    _readTeam(source, id).catchError((_) {}); // The team cannot be read: the stream says who works.
  }

  Future<void> _readTeam(AgUiTeamProgressSource source, String id) async {
    final execution = await source.fetchExecution(id);
    if (_disposed || id != _executionId || execution == null) return;
    _startedAt = execution.createdAt;
    if (_givenMembers == null && execution.entityKind.toLowerCase() == 'team' && _teamRead != execution.entityId) {
      final team = await source.fetchTeam(execution.entityId);
      if (_disposed) return;
      _teamRead = execution.entityId;
      _teamMembers = team.toTeamMembers();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _chat.removeListener(_onChat);
    _statuses?.dispose();
    super.dispose();
  }
}
