
import 'package:dio/dio.dart';

import '../../core/http_core.dart';
import '../domain/entity_models.dart';
import '../domain/execution_status_models.dart';
import '../../core/streaming_request.dart';

/// Execution lifecycle endpoints: start, questions to a person, and SSE streams.
///
/// Part of the lightweight [AgentivityClient].
class RunsApi {
  RunsApi(this._c);
  final AgentivityHttpCore _c;

  // ---------------------------------------------------------------------------
  // Unified execution start — POST /api/v1/executions
  // ---------------------------------------------------------------------------

  Future<SessionStartedResponse> startExecution({
    required String entityId,
    required String input,
    String? executionId,
    bool enableHil = false,
    int? maxAgentIterations,
    /// Images attached to this turn (vision) — agent-kind executions only for
    /// now. Each entry: `{'base64Data': ..., 'mimeType': ...}`.
    List<Map<String, String>>? images,
  }) async {
    final normalizedEntityId = _c.requireNormalizedId(entityId, label: 'Entity id');
    final body = <String, dynamic>{
      'entityId': normalizedEntityId,
      'input': input,
      'executionId': executionId?.trim().isEmpty ?? true ? null : executionId!.trim(),
      'enableHil': enableHil,
      if (maxAgentIterations != null) 'maxAgentIterations': maxAgentIterations,
      if (images != null && images.isNotEmpty) 'images': images,
    };
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/executions'),
      data: body,
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    return SessionStartedResponse.fromJson(response.data ?? const <String, dynamic>{});
  }

  // ---------------------------------------------------------------------------
  // Execution lifecycle — GET/POST /api/v1/executions/{executionId}
  // ---------------------------------------------------------------------------

  Future<void> cancelExecution(String executionId) async {
    await _c.post<void>(AgentivityHttpCore.v1('/executions/$executionId/cancel'));
  }

  Future<void> pauseExecution(String executionId) async {
    await _c.post<void>(AgentivityHttpCore.v1('/executions/$executionId/pause'));
  }

  Future<void> unpauseExecution(String executionId) async {
    await _c.post<void>(AgentivityHttpCore.v1('/executions/$executionId/unpause'));
  }


  // ---------------------------------------------------------------------------
  // Questions of an execution — GET /api/v1/executions/{executionId}/hil/pending
  //                             POST /api/v1/executions/{executionId}/respond
  // ---------------------------------------------------------------------------

  Future<HilPendingResponse> fetchPendingHil(String executionId) async {
    final normalized = _c.requireNormalizedId(executionId, label: 'Execution id');
    final response = await _c.get<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/executions/$normalized/hil/pending'),
    );
    return HilPendingResponse.fromJson(response.data ?? const <String, dynamic>{});
  }

  /// Answers the question [requestId] of the execution [executionId], whatever the channel it was asked through
  /// (chat, form, widget…). Several questions can wait at once: the one answered is named, and the platform takes up
  /// again the run that asked it. The answer is kept in the conversation the question was asked in; [source] is
  /// `'widget'` when a widget gave it (the widget shows the answer itself, so the chat does not show it again).
  Future<HilRespondResult> submitHilResponse({
    required String executionId,
    required String requestId,
    required String response,
    String? source,
  }) async {
    final normalizedExecution = _c.requireNormalizedId(executionId, label: 'Execution id');
    final normalizedRequest = _c.requireNormalizedId(requestId, label: 'Request id');
    final result = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/executions/$normalizedExecution/respond'),
      data: <String, dynamic>{'requestId': normalizedRequest, 'response': response, if (source != null) 'source': source},
    );
    return HilRespondResult.fromJson(result.data ?? const <String, dynamic>{});
  }

  // ---------------------------------------------------------------------------
  // Unified run status — GET /api/v1/runs/{runId}
  // ---------------------------------------------------------------------------
  // Unified run status — GET /api/v1/runs/{runId}
  // ---------------------------------------------------------------------------

  Future<AgentRunStatusResponse> fetchRun(String runId) async {
    final normalizedRunId = _c.requireNormalizedId(runId, label: 'Run id');
    final response = await _c.get<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/runs/$normalizedRunId'),
    );
    return AgentRunStatusResponse.fromJson(response.data ?? const <String, dynamic>{});
  }

  // ---------------------------------------------------------------------------
  // Executions by entity — GET /api/v1/executions?entityId={id}
  //
  // For standalone agents, RunId == ExecutionId (EPIC-execution-centric-api,
  // Story 1), so a multiturn conversation collapses into a single entry here.
  // ---------------------------------------------------------------------------

  Future<List<AgentRunStatusResponse>> fetchRunsByEntityId(String entityId) async {
    final normalizedId = _c.requireNormalizedId(entityId, label: 'Entity id');
    final response = await _c.get<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/executions'),
      queryParameters: {'entityId': normalizedId},
    );
    final data = response.data ?? const <String, dynamic>{};
    final items = data['executions'] as List<dynamic>? ?? const [];
    return items.whereType<Object>().map((e) {
      final map = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      // executionId doubles as runId for the unified AgentRunStatusResponse shape.
      return AgentRunStatusResponse.fromJson({...map, 'runId': map['executionId']});
    }).toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Execution record — GET /api/v1/executions/{executionId}
  // Returns channels (channelType → threadId) and execution metadata.
  // ---------------------------------------------------------------------------

  Future<ExecutionRecord?> fetchExecution(String executionId) async {
    final normalized = _c.requireNormalizedId(executionId, label: 'Execution id');
    try {
      final response = await _c.get<Map<String, dynamic>>(
        AgentivityHttpCore.v1('/executions/$normalized'),
      );
      final data = response.data;
      if (data == null) return null;
      return ExecutionRecord.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Live step statuses — GET /api/v1/executions/{executionId}/inspector
  // The authoritative per-step state (workflow nodes, team members) of any execution: valid on a fresh run, after a reconnect
  // and when reopening an old execution — unlike stream events, which are not replayed.
  // ---------------------------------------------------------------------------

  Future<ExecutionStatuses?> fetchExecutionStatuses(String executionId) async {
    final normalized = _c.requireNormalizedId(executionId, label: 'Execution id');
    try {
      final response = await _c.get<Map<String, dynamic>>(
        AgentivityHttpCore.v1('/executions/$normalized/inspector'),
        dataBody: true,
      );
      final data = response.data;
      if (data == null) return null;
      return ExecutionStatuses.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Unified cancel — POST /api/v1/runs/{runId}/cancel
  // ---------------------------------------------------------------------------

  Future<void> cancelRun(String runId) async {
    final normalizedRunId = _c.requireNormalizedId(runId, label: 'Run id');
    await _c.post<dynamic>(AgentivityHttpCore.v1('/runs/$normalizedRunId/cancel'));
  }

  // ---------------------------------------------------------------------------
  // SSE stream
  // ---------------------------------------------------------------------------

  Future<ResponseBody> openEventStream(
    String path, {
    String? lastEventId,
    CancelToken? cancelToken,
  }) async {
    final headers = <String, dynamic>{
      Headers.acceptHeader: 'text/event-stream',
      'Cache-Control': 'no-cache',
    };
    final normalizedLastEventId = lastEventId?.trim();
    if (normalizedLastEventId != null && normalizedLastEventId.isNotEmpty) {
      headers['Last-Event-ID'] = normalizedLastEventId;
    }

    return openStreamingRequest(_c.dio, 'GET', path, headers: headers, cancelToken: cancelToken);
  }
}
