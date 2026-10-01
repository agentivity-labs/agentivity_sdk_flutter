/// Live status of a running execution, read from its inspector snapshot —
/// `GET /api/v1/executions/{id}/inspector`. One source for every kind of execution: a workflow's
/// steps are its nodes, a team's steps are its members. `AgUiWorkflowGraph`, `AgUiTeamGraph` and
/// `AgUiTeamRoster` all light up from it (their `statusSource`), so a diagram is right on a fresh run,
/// after a reconnect and when reopening an old execution — unlike stream events, which are not
/// replayed. Mirrors the React SDK's `execution-status-models.ts`.

/// Where one step (a workflow node, or a team member) stands. A step not reached yet has no entry.
enum ExecutionStepState { working, waiting, done, failed }

class ExecutionStatuses {
  const ExecutionStatuses({required this.executionState, required this.nodes, required this.members});

  /// The run's own status, lowercase (`running`, `waitingforinput`, `completed`, `failed`, …).
  final String executionState;

  /// Workflow nodes that have started, keyed by node id.
  final Map<String, ExecutionStepState> nodes;

  /// Team members that have taken a turn, keyed by `memberEntityId`.
  final Map<String, ExecutionStepState> members;

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
    final steps = json['steps'] is List ? json['steps'] as List : const [];
    for (final raw in steps) {
      if (raw is! Map) continue;
      final state = _state((raw['status'] is String ? raw['status'] as String : '').toLowerCase());
      if (state == null) continue;
      final explicit = raw['memberEntityId'];
      final id = raw['id'];
      // A team step is an agent's turn: the inspector leaves memberEntityId null and carries the member's entity id as the
      // step id, marked by agentTopologyPositionId. A workflow step has neither.
      final position = raw['agentTopologyPositionId'];
      final isTeamStep = position is String && position.isNotEmpty;
      final memberId = explicit is String && explicit.isNotEmpty ? explicit : (isTeamStep && id is String ? id : null);
      if (memberId != null) {
        members[memberId] = state;
      } else if (id is String) {
        nodes[id] = state;
      }
    }
    return ExecutionStatuses(executionState: executionState, nodes: nodes, members: members);
  }
}
