import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../client/app_client/domain/execution_status_models.dart';
import 'chat_controller.dart';

/// Live per-step status of an execution — workflow nodes and team members alike — from its
/// inspector snapshot. The one source [AgUiWorkflowGraph], [AgUiTeamGraph] and [AgUiTeamRoster]
/// light up from (their `statusSource`): read from the API rather than rebuilt from stream events,
/// so it is right on a fresh run, after a reconnect and when reopening an old execution (stream
/// events are not replayed). Polls only while the execution can still change. Mirrors the React
/// SDK's `useExecutionStatuses`.
///
/// ```dart
/// final source = ExecutionStatusesController(
///   fetch: () => client.runs.fetchExecutionStatuses(executionId),
///   chat: chatController, // optional: a chat event refreshes at once instead of at the next poll
/// );
/// AgUiTeamGraph(controller: chatController, members: members, statusSource: source);
/// ```
class ExecutionStatusesController extends ChangeNotifier {
  ExecutionStatusesController({
    required Future<ExecutionStatuses?> Function() fetch,
    ChatController? chat,
    this.interval = const Duration(milliseconds: 1200),
  }) : _fetch = fetch,
       _chat = chat {
    _chat?.addListener(_onChat);
    unawaited(refresh());
  }

  final Future<ExecutionStatuses?> Function() _fetch;
  final ChatController? _chat;
  final Duration interval;

  Timer? _timer;
  Timer? _debounce;
  bool _inFlight = false;
  bool _disposed = false;
  Map<String, WorkflowStepStatus> _nodeStatuses = const {};
  Map<String, TeamMemberStatus> _memberStatuses = const {};

  /// Workflow nodes that have started, keyed by node id.
  Map<String, WorkflowStepStatus> get nodeStatuses => _nodeStatuses;

  /// Team members that have taken a turn, keyed by `memberEntityId`.
  Map<String, TeamMemberStatus> get memberStatuses => _memberStatuses;

  static WorkflowStepStatus _node(ExecutionStepState s) => switch (s) {
    ExecutionStepState.working => WorkflowStepStatus.working,
    ExecutionStepState.waiting => WorkflowStepStatus.waiting,
    ExecutionStepState.done => WorkflowStepStatus.done,
    ExecutionStepState.failed => WorkflowStepStatus.failed,
  };

  static TeamMemberStatus _member(ExecutionStepState s) => switch (s) {
    ExecutionStepState.working => TeamMemberStatus.working,
    ExecutionStepState.waiting => TeamMemberStatus.waiting,
    ExecutionStepState.done => TeamMemberStatus.done,
    ExecutionStepState.failed => TeamMemberStatus.failed,
  };

  Future<void> refresh() async {
    if (_disposed || _inFlight) return;
    _inFlight = true;
    try {
      final result = await _fetch();
      if (_disposed) return;
      if (result != null) {
        final nodes = {for (final e in result.nodes.entries) e.key: _node(e.value)};
        final members = {for (final e in result.members.entries) e.key: _member(e.value)};
        if (!mapEquals(nodes, _nodeStatuses) || !mapEquals(members, _memberStatuses)) {
          _nodeStatuses = Map.unmodifiable(nodes);
          _memberStatuses = Map.unmodifiable(members);
          notifyListeners();
        }
      }
      // An unreachable status (null) is retried like a live one — a blip must not freeze the diagram.
      _schedule(result?.isLive ?? true);
    } finally {
      _inFlight = false;
    }
  }

  void _schedule(bool live) {
    _timer?.cancel();
    if (!_disposed && live) _timer = Timer(interval, () => unawaited(refresh()));
  }

  void _onChat() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => unawaited(refresh()));
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _debounce?.cancel();
    _chat?.removeListener(_onChat);
    super.dispose();
  }
}
