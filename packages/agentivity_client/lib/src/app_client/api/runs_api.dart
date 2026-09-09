import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../core/http_core.dart';
import '../domain/entity_models.dart';

/// Run lifecycle endpoints: start, HIL, interactions, and SSE streams.
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
  }) async {
    final normalizedEntityId = _c.requireNormalizedId(entityId, label: 'Entity id');
    final body = <String, dynamic>{
      'entityId': normalizedEntityId,
      'input': input,
      'executionId': executionId?.trim().isEmpty ?? true ? null : executionId!.trim(),
      'enableHil': enableHil,
      if (maxAgentIterations != null) 'maxAgentIterations': maxAgentIterations,
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
  // HIL — GET /api/v1/executions/{executionId}/hil/pending
  //         POST /api/v1/executions/{executionId}/respond
  // ---------------------------------------------------------------------------

  Future<HilPendingResponse> fetchPendingHil(String executionId) async {
    final normalized = _c.requireNormalizedId(executionId, label: 'Execution id');
    final response = await _c.get<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/executions/$normalized/hil/pending'),
    );
    return HilPendingResponse.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<HilRespondResult> submitHilResponse({
    required String executionId,
    required String requestId,
    required String response,
  }) async {
    final normalizedExecution = _c.requireNormalizedId(executionId, label: 'Execution id');
    final normalizedRequest = _c.requireNormalizedId(requestId, label: 'Request id');
    final result = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/executions/$normalizedExecution/respond'),
      data: <String, dynamic>{
        'requestId': normalizedRequest,
        'response': response,
      },
    );
    return HilRespondResult.fromJson(result.data ?? const <String, dynamic>{});
  }

  // ---------------------------------------------------------------------------
  // Send message or HIL response — POST /api/v1/runs/{runId}/interactions
  // ---------------------------------------------------------------------------

  Future<RunInteractionResponse> sendRunInteraction({
    required String runId,
    required String message,
    String? threadId,
    String? authorId,
    String? authorName,
    String? interactionRequestId,
    String? outcome,
    String? executionId,
  }) async {
    final normalizedRunId = _c.requireNormalizedId(runId, label: 'Run id');
    final body = <String, dynamic>{'message': message};
    if (threadId != null && threadId.trim().isNotEmpty) body['threadId'] = threadId.trim();
    if (authorId != null && authorId.trim().isNotEmpty) body['authorId'] = authorId.trim();
    if (authorName != null && authorName.trim().isNotEmpty) {
      body['authorName'] = authorName.trim();
    }
    if (interactionRequestId != null && interactionRequestId.trim().isNotEmpty) {
      body['interactionRequestId'] = interactionRequestId.trim();
    }
    if (outcome != null && outcome.trim().isNotEmpty) body['outcome'] = outcome.trim();
    if (executionId != null && executionId.trim().isNotEmpty) {
      body['executionId'] = executionId.trim();
    }
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/runs/$normalizedRunId/interactions'),
      data: body,
    );
    return RunInteractionResponse.fromJson(response.data ?? const <String, dynamic>{});
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
  // Unified cancel — POST /api/v1/runs/{runId}/cancel
  // ---------------------------------------------------------------------------

  Future<void> cancelRun(String runId) async {
    final normalizedRunId = _c.requireNormalizedId(runId, label: 'Run id');
    await _c.post<dynamic>(AgentivityHttpCore.v1('/runs/$normalizedRunId/cancel'));
  }

  // ---------------------------------------------------------------------------
  // Stream-scoped HIL response — POST /api/v1/streams/{streamId}/interactions
  // Chat uses only streamId + requestId. The backend resolves the runId internally.
  // ---------------------------------------------------------------------------

  Future<void> respondToStreamInteraction({
    required String streamId,
    required String requestId,
    required String text,
    String source = 'text',
  }) async {
    final normalizedStreamId = _c.requireNormalizedId(streamId, label: 'Stream id');
    await _c.post<dynamic>(
      AgentivityHttpCore.v1('/streams/$normalizedStreamId/interactions'),
      data: <String, dynamic>{
        'requestId': requestId,
        'text': text,
        'source': source,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // AG-UI standard resume — POST /api/v1/runs/{runId}/resume
  // ---------------------------------------------------------------------------

  Future<void> resumeRun({
    required String runId,
    required String interruptId,
    required String responseText,
    String? source,
  }) async {
    final normalizedRunId = _c.requireNormalizedId(runId, label: 'Run id');
    developer.log('runId=$normalizedRunId interruptId=$interruptId response=$responseText source=$source', name: '[resumeRun]');
    await _c.post<dynamic>(
      AgentivityHttpCore.v1('/runs/$normalizedRunId/resume'),
      data: <String, dynamic>{
        'interruptId': interruptId,
        'response': <String, dynamic>{'text': responseText, if (source != null) 'source': source},
      },
    );
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

    final response = await _c.dio.get<ResponseBody>(
      path,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        receiveTimeout: Duration.zero,
      ),
    );
    final body = response.data;
    if (body == null) {
      throw StateError('SSE stream did not return a response body for $path.');
    }
    return body;
  }
}
