/// Live status of a running execution, read from its progress —
/// `GET /api/v1/executions/{id}/progress`, what a customer may read of it, a key for a web page included. One source for every kind of execution: a workflow's
/// steps are its nodes, a team's steps are its members. `AgUiWorkflowGraph`, `AgUiTeamGraph` and
/// `AgUiTeamRoster` all light up from it (their `statusSource`), so a diagram is right on a fresh run,
/// after a reconnect and when reopening an old execution — unlike stream events, which are not
/// replayed. Mirrors the React SDK's `execution-status-models.ts`.

import 'package:meta/meta.dart';

/// Where one step (a workflow node, or a team member) stands. A step not reached yet has no entry.
enum ExecutionStepState { working, waiting, done, failed }

/// One team member, as far as the execution's progress tells it.
@immutable
class ExecutionMemberStep {
  const ExecutionMemberStep({required this.memberEntityId, this.displayName, this.state, this.isManager = false, this.activity, this.summary, this.result});

  final String memberEntityId;
  final String? displayName;

  /// Null for a member not reached yet.
  final ExecutionStepState? state;

  /// The manager of a manager-led team: what it writes is for its team or is the answer itself.
  final bool isManager;

  /// What it is doing, in a few words for a customer, when the platform says it.
  final String? activity;

  /// What it has done, in a few words for a customer, when the platform says it.
  final String? summary;

  /// Its last result, in full (Markdown).
  final String? result;

  @override
  bool operator ==(Object other) => other is ExecutionMemberStep && other.memberEntityId == memberEntityId && other.displayName == displayName && other.state == state && other.isManager == isManager && other.activity == activity && other.summary == summary && other.result == result;

  @override
  int get hashCode => Object.hash(memberEntityId, displayName, state, isManager, activity, summary, result);
}

class ExecutionStatuses {
  const ExecutionStatuses({required this.executionState, required this.nodes, required this.members, this.memberSteps = const {}, this.lastStepAt, this.jobFinished = false, this.closed = false, this.refused = false});

  /// This key may not read it (a key for a web page): asking again is pointless.
  const ExecutionStatuses.refused() : this(executionState: '', nodes: const {}, members: const {}, refused: true);

  /// The run's own status, lowercase (`running`, `waitingforinput`, `completed`, `failed`, …).
  final String executionState;

  /// Workflow nodes that have started, keyed by node id.
  final Map<String, ExecutionStepState> nodes;

  /// Team members that have taken a turn, keyed by `memberEntityId`.
  final Map<String, ExecutionStepState> members;

  /// The same members with what each has to show, keyed by `memberEntityId`.
  final Map<String, ExecutionMemberStep> memberSteps;

  /// When the last finished turn of a team ended, if it has one.
  final DateTime? lastStepAt;

  /// Its last job is finished: the person can go on, close or start another.
  final bool jobFinished;

  /// The conversation has been closed.
  final bool closed;

  /// See [ExecutionStatuses.refused].
  final bool refused;

  /// True while the execution can still change (worth polling); false once it has ended.
  bool get isLive => const {'pending', 'running', 'paused', 'waitingforinput'}.contains(executionState);

  static ExecutionStepState? _state(String status) => switch (status) {
    'running' => ExecutionStepState.working,
    'waitingforinput' || 'paused' => ExecutionStepState.waiting,
    'completed' => ExecutionStepState.done,
    'failed' => ExecutionStepState.failed,
    _ => null, // pending, cancelled, interrupted, unknown — not lit
  };

  factory ExecutionStatuses.fromJson(Map<String, dynamic> json) {
    final executionState = (json['status'] is String ? json['status'] as String : '').toLowerCase();
    final nodes = <String, ExecutionStepState>{};
    final members = <String, ExecutionStepState>{};
    final memberSteps = <String, ExecutionMemberStep>{};
    final steps = json['steps'] is List ? json['steps'] as List : const [];
    for (final raw in steps) {
      if (raw is! Map) continue;
      final status = (raw['status'] is String ? raw['status'] as String : '').toLowerCase();
      final state = _state(status);
      final explicit = raw['memberEntityId'];
      final id = raw['id'];
      // A team step is an agent's turn: the platform leaves memberEntityId null and carries the member's entity id as the
      // step id, marked by agentTopologyPositionId. A workflow step has neither.
      final position = raw['agentTopologyPositionId'];
      final isTeamStep = position is String && position.isNotEmpty;
      final memberId = explicit is String && explicit.isNotEmpty ? explicit : (isTeamStep && id is String ? id : null);
      // Every member is listed, those not reached yet too: they have no status to light up, only a line.
      if (state == null && !(memberId != null && status == 'pending')) continue;
      if (memberId != null) {
        if (state != null) members[memberId] = state;
        final outputs = raw['outputs'];
        memberSteps[memberId] = ExecutionMemberStep(memberEntityId: memberId, state: state, isManager: raw['isManager'] == true, displayName: _text(raw['name']), activity: _text(raw['activity']), summary: _text(raw['summary']), result: outputs is Map ? _text(outputs['output']) : null);
      } else if (id is String && state != null) {
        nodes[id] = state;
      }
    }
    return ExecutionStatuses(executionState: executionState, nodes: nodes, members: members, memberSteps: memberSteps, lastStepAt: _lastOccurredAt(json['callSequence']), jobFinished: json['jobFinished'] == true, closed: json['closed'] == true);
  }

  static String? _text(Object? value) => value is String && value.trim().isNotEmpty ? value.trim() : null;

  static DateTime? _lastOccurredAt(Object? calls) {
    if (calls is! List) return null;
    for (final call in calls.reversed) {
      final at = call is Map ? _text(call['occurredAt']) : null;
      if (at != null) return DateTime.tryParse(at);
    }
    return null;
  }
}
