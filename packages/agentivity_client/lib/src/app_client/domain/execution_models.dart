/// Frontend mirror of the server-side ExecutionContext / RunContext hierarchy.
/// An execution is the user-facing lifecycle concept; runs are internal details.

// ─────────────────────────────────────────────────────────────────────────────
// ExecutionContext
// ─────────────────────────────────────────────────────────────────────────────

/// Shared context for an entire execution chain (agent / team / WorkflowEntity).
/// Created once when the execution starts; stable across all nested runs.
/// Mirror of server-side ExecutionContext.
class ExecutionContext {
  const ExecutionContext({
    required this.executionId,
    required this.streamId,
    required this.entityId,
    required this.entityKind,
  });

  /// Correlation identifier for the execution chain.
  final String executionId;

  /// Stable SSE channel identifier — distinct from executionId and any runId.
  /// Use [streamUrl] to connect to the SSE stream.
  final String streamId;

  /// ID of the entity being executed (agentId | teamId | workflowId).
  final String entityId;

  /// "agent" | "team" | "WorkflowEntity"
  final String entityKind;

  /// Constructs the SSE stream URL from [streamId].
  String get streamUrl => '/api/v1/streams/$streamId/events';

  /// Parses from the JSON envelope returned by POST /api/v1/executions.
  factory ExecutionContext.fromJson(Map<String, dynamic> json) => ExecutionContext(
        executionId: (json['executionId'] as String? ?? '').trim(),
        streamId: (json['streamId'] as String? ?? '').trim(),
        entityId: (json['entityId'] as String? ?? '').trim(),
        entityKind: (json['entityKind'] as String? ?? '').trim().toLowerCase(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ExecutionContext && executionId == other.executionId;

  @override
  int get hashCode => executionId.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────────
// RunContext
// ─────────────────────────────────────────────────────────────────────────────

/// Context for one run within an execution.
/// A single execution may contain multiple runs (e.g. HIL resume).
/// Mirror of server-side RunContext.
class RunContext {
  const RunContext({
    required this.runId,
    required this.execution,
  });

  /// Internal run identifier — for inspector/status polling only.
  final String runId;

  /// The execution this run belongs to.
  final ExecutionContext execution;

  String get executionId => execution.executionId;
  String get streamId => execution.streamId;
  String get streamUrl => execution.streamUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RunContext && runId == other.runId;

  @override
  int get hashCode => runId.hashCode;
}
