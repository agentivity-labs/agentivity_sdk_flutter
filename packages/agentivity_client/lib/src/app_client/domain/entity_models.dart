import 'package:meta/meta.dart';
import 'interaction_models.dart' show InteractionField;
import 'execution_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PortDefinition
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class PortDefinition {
  const PortDefinition({
    required this.name,
    required this.type,
    this.description,
  });

  final String name;

  /// e.g. "text" | "number" | "boolean" | "text_list" | "image_ref"
  final String type;
  final String? description;

  factory PortDefinition.fromJson(Map<String, dynamic> json) {
    return PortDefinition(
      name: (json['name'] as String? ?? '').trim(),
      type: (json['type'] as String? ?? 'text').trim(),
      description: _nullableTrimmed(json['description']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EntityUnit — unified catalog entry (agent | team | WorkflowEntity)
// Source: GET /api/v1/entities
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class EntityUnit {
  const EntityUnit({
    required this.id,
    required this.displayName,
    required this.kind,
    this.description,
    this.inputs = const [],
    this.outputs = const [],
    this.folderName,
  });

  final String id;
  final String displayName;

  /// "agent" | "team" | "workflow"
  final String kind;
  final String? description;
  final List<PortDefinition> inputs;
  final List<PortDefinition> outputs;

  /// Display name of the owning folder (agents/teams only — workflows have no
  /// folder concept today). Null means "root" / ungrouped.
  final String? folderName;

  bool get isAgent => kind == 'agent';
  bool get isTeam => kind == 'team';
  bool get isWorkflow => kind == 'workflow';

  factory EntityUnit.fromJson(Map<String, dynamic> json) {
    List<PortDefinition> parsePorts(dynamic raw) {
      if (raw is! List) return const [];
      return raw.whereType<Object>().map((e) {
        final map = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
        return PortDefinition.fromJson(map);
      }).toList(growable: false);
    }

    return EntityUnit(
      id: (json['id'] as String? ?? '').trim(),
      displayName: (json['displayName'] as String? ?? '').trim(),
      kind: (json['kind'] as String? ?? '').trim().toLowerCase(),
      description: _nullableTrimmed(json['description']),
      inputs: parsePorts(json['inputs']),
      outputs: parsePorts(json['outputs']),
      folderName: _nullableTrimmed(json['folderName']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AgentRunStartedResponse
// Source: POST /api/v1/agentic/agents/{agentId}/runs  → 202 Accepted
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class AgentRunStartedResponse {
  const AgentRunStartedResponse({
    required this.runId,
    required this.agentId,
    required this.streamUrl,
    required this.statusUrl,
    this.executionId = '',
    this.executionStreamUrl = '',
  });

  final String runId;
  final String agentId;
  final String streamUrl;
  final String statusUrl;

  /// Execution identifier — correlates all runs within the same execution chain.
  final String executionId;

  /// Execution-level stream URL — subscribe this for all events in the chain.
  final String executionStreamUrl;

  factory AgentRunStartedResponse.fromJson(Map<String, dynamic> json) {
    return AgentRunStartedResponse(
      runId: (json['runId'] as String? ?? '').trim(),
      agentId: (json['agentId'] as String? ?? '').trim(),
      streamUrl: (json['streamUrl'] as String? ?? '').trim(),
      statusUrl: (json['statusUrl'] as String? ?? '').trim(),
      executionId: (json['executionId'] as String? ?? '').trim(),
      executionStreamUrl: (json['executionStreamUrl'] as String? ?? '').trim(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AgentRunState
// ─────────────────────────────────────────────────────────────────────────────

enum AgentRunState {
  running,
  completed,
  failed,
  cancelled;

  factory AgentRunState.fromApi(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'completed':
        return AgentRunState.completed;
      case 'failed':
        return AgentRunState.failed;
      case 'cancelled':
        return AgentRunState.cancelled;
      default:
        return AgentRunState.running;
    }
  }

  bool get isTerminal => this == completed || this == failed || this == cancelled;
}

// ─────────────────────────────────────────────────────────────────────────────
// AgentRunStatusResponse
// Source: GET /api/v1/agentic/agents/{agentId}/runs/{runId}
// ─────────────────────────────────────────────────────────────────────────────

@Deprecated('Use RunSummary from run_models.dart for list views; '
    'AgentRunUiState.result retains this type for AG-UI stream logic.')
@immutable
class AgentRunStatusResponse {
  const AgentRunStatusResponse({
    required this.runId,
    this.agentId = '',
    required this.state,
    this.content,
    this.error,
    this.createdAt,
    this.completedAt,
  });

  final String runId;

  /// Agent id — empty when parsed from the unified GET /api/v1/runs/{runId} endpoint.
  final String agentId;
  final AgentRunState state;
  final String? content;
  final String? error;
  final DateTime? createdAt;
  final DateTime? completedAt;

  factory AgentRunStatusResponse.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) => raw is String ? DateTime.tryParse(raw) : null;
    return AgentRunStatusResponse(
      runId: (json['runId'] as String? ?? '').trim(),
      agentId: (json['agentId'] as String? ?? '').trim(),
      state: AgentRunState.fromApi(json['state'] as String? ?? ''),
      content: _nullableTrimmed(json['content']),
      error: _nullableTrimmed(json['error']),
      createdAt: parseDate(json['createdAt']),
      completedAt: parseDate(json['completedAt']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SessionStartedResponse — EPIC-0447
// Source: POST /api/v1/runs → 202 Accepted
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class SessionStartedResponse {
  const SessionStartedResponse({
    required this.runContext,
    required this.state,
    this.createdAt,
  });

  /// Full run context — carries executionId, streamId, runId, entityId, entityKind.
  final RunContext runContext;

  final String state;
  final DateTime? createdAt;

  // Convenience accessors
  String get runId => runContext.runId;
  String get executionId => runContext.executionId;
  String get streamId => runContext.streamId;
  String get streamUrl => runContext.streamUrl;
  String get entityId => runContext.execution.entityId;
  String get entityKind => runContext.execution.entityKind;

  factory SessionStartedResponse.fromJson(Map<String, dynamic> json) {
    final execution = ExecutionContext.fromJson(json);
    final runId = (json['runId'] as String? ?? '').trim();
    return SessionStartedResponse(
      runContext: RunContext(runId: runId, execution: execution),
      state: (json['state'] as String? ?? '').trim().toLowerCase(),
      createdAt: json['createdAt'] is String ? DateTime.tryParse(json['createdAt'] as String) : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HilPendingRequest — EPIC-0447
// Part of: GET /api/v1/executions/{executionId}/hil/pending
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class HilPendingRequest {
  const HilPendingRequest({
    required this.requestId,
    required this.runId,
    required this.agentId,
    required this.title,
    this.description,
    this.question,
    this.fields = const [],
    this.draftContent,
    this.createdAt,
    this.receivedAt,
  });

  final String requestId;
  final String runId;
  final String agentId;
  final String title;

  /// Instructions / context shown above the form fields.
  final String? description;

  /// Free-text question shown to the user in the HIL gate prompt.
  final String? question;

  /// Structured form fields to render (empty = free-text fallback).
  final List<InteractionField> fields;

  /// Optional pre-filled response text (legacy / draft).
  final String? draftContent;

  final DateTime? createdAt;

  /// Set by the client when the HIL event is first received (wall-clock time).
  final DateTime? receivedAt;

  factory HilPendingRequest.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'];
    final fields = rawFields is List
        ? rawFields.map((e) => InteractionField.fromJson(e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))).toList()
        : <InteractionField>[];
    return HilPendingRequest(
      requestId: (json['requestId'] as String? ?? '').trim(),
      runId: (json['runId'] as String? ?? '').trim(),
      agentId: (json['agentId'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      description: _nullableTrimmed(json['description']),
      question: _nullableTrimmed(json['question']),
      fields: fields,
      draftContent: _nullableTrimmed(json['draftContent']),
      createdAt: json['createdAt'] is String ? DateTime.tryParse(json['createdAt'] as String) : null,
      receivedAt: json['receivedAt'] is String ? DateTime.tryParse(json['receivedAt'] as String) : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HilPendingResponse — EPIC-0447
// Source: GET /api/v1/executions/{executionId}/hil/pending
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class HilPendingResponse {
  const HilPendingResponse({
    required this.executionId,
    required this.count,
    required this.requests,
  });

  final String executionId;
  final int count;
  final List<HilPendingRequest> requests;

  HilPendingRequest? get first => requests.isEmpty ? null : requests.first;

  factory HilPendingResponse.fromJson(Map<String, dynamic> json) {
    final rawRequests = json['requests'];
    final requests = <HilPendingRequest>[];
    if (rawRequests is List) {
      for (final entry in rawRequests) {
        if (entry is Map<String, dynamic>) {
          requests.add(HilPendingRequest.fromJson(entry));
        } else if (entry is Map) {
          requests.add(HilPendingRequest.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }
    return HilPendingResponse(
      // Accept executionId from new contract; fall back to legacy sessionId.
      executionId: ((json['executionId'] ?? json['sessionId']) as String? ?? '').trim(),
      count: (json['count'] as int?) ?? requests.length,
      requests: List.unmodifiable(requests),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HilRespondResult — EPIC-0447
// Source: POST /api/v1/executions/{executionId}/respond → 200 OK
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class HilRespondResult {
  const HilRespondResult({
    required this.executionId,
    required this.runId,
    required this.requestId,
    required this.state,
  });

  final String executionId;
  final String runId;
  final String requestId;

  /// Typically "resumed".
  final String state;

  factory HilRespondResult.fromJson(Map<String, dynamic> json) {
    return HilRespondResult(
      // Accept executionId from new contract; fall back to legacy sessionId.
      executionId: ((json['executionId'] ?? json['sessionId']) as String? ?? '').trim(),
      runId: (json['runId'] as String? ?? '').trim(),
      requestId: (json['requestId'] as String? ?? '').trim(),
      state: (json['state'] as String? ?? '').trim().toLowerCase(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RunInteractionResponse — new interaction contract
// Source: POST /api/v1/runs/{runId}/interactions → 200 OK
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class RunInteractionResponse {
  const RunInteractionResponse({
    required this.status,
    required this.runId,
    this.threadId,
    this.messageId,
    this.interactionRequestId,
  });

  final String status;
  final String runId;
  final String? threadId;
  final String? messageId;
  final String? interactionRequestId;

  factory RunInteractionResponse.fromJson(Map<String, dynamic> json) {
    return RunInteractionResponse(
      status: (json['status'] as String? ?? '').trim(),
      runId: (json['runId'] as String? ?? '').trim(),
      threadId: _nullableTrimmed(json['threadId']),
      messageId: _nullableTrimmed(json['messageId']),
      interactionRequestId: _nullableTrimmed(json['interactionRequestId']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ExecutionRecord — GET /api/v1/executions/{executionId}
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class ExecutionRecord {
  const ExecutionRecord({
    required this.executionId,
    required this.entityId,
    required this.entityKind,
    required this.state,
    this.channels = const {},
    this.currentRunId,
  });

  final String executionId;
  final String entityId;
  final String entityKind;
  final String state;

  /// channelType → threadId (e.g. { "chat": "919d4238-..." })
  final Map<String, String> channels;
  final String? currentRunId;

  /// Convenience: returns the default chat thread ID if present.
  String? get chatThreadId => channels['chat'];

  factory ExecutionRecord.fromJson(Map<String, dynamic> json) {
    final rawChannels = json['channels'];
    final channels = <String, String>{};
    if (rawChannels is Map) {
      rawChannels.forEach((k, v) {
        if (k is String && v is String) channels[k] = v;
      });
    }
    return ExecutionRecord(
      executionId: (json['executionId'] as String? ?? '').trim(),
      entityId: (json['entityId'] as String? ?? '').trim(),
      entityKind: (json['entityKind'] as String? ?? '').trim(),
      state: (json['state'] as String? ?? '').trim(),
      channels: channels,
      currentRunId: _nullableTrimmed(json['currentRunId']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String? _nullableTrimmed(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
}
