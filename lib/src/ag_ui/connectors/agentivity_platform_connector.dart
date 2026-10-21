import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../protocol/ag_ui_protocol.dart';
import '../protocol/ag_ui_sse_channel.dart';
import '../../client/core/streaming_request.dart';

// ── Run handle ────────────────────────────────────────────────────────────────

/// Returned by [AgentivityPlatformConnector.startRun].
///
/// [streamUrl] is the SSE endpoint to subscribe for live [AgUiEvent]s.
/// Pass it to [AgentivityPlatformConnector.openRunStream] to avoid recomputing.
class AgUiRunHandle {
  const AgUiRunHandle({required this.runId, required this.executionId, required this.streamUrl, required this.entityId, required this.entityKind, required this.state, this.createdAt});

  /// Internal run identifier.
  final String runId;

  /// Execution identifier — correlates all runs within the same execution chain.
  final String executionId;

  /// SSE event stream URL for this run.
  final String streamUrl;

  final String entityId;

  /// `"agent"` | `"team"` | `"workflow"`
  final String entityKind;

  final String state;
  final DateTime? createdAt;

  factory AgUiRunHandle.fromJson(Map<String, dynamic> json) {
    return AgUiRunHandle(
      runId: (json['runId'] as String? ?? '').trim(),
      executionId: (json['executionId'] as String? ?? '').trim(),
      streamUrl: (json['streamUrl'] as String? ?? '').trim(),
      entityId: (json['entityId'] as String? ?? '').trim(),
      entityKind: (json['entityKind'] as String? ?? '').trim().toLowerCase(),
      state: (json['state'] as String? ?? '').trim().toLowerCase(),
      createdAt: json['createdAt'] is String ? DateTime.tryParse(json['createdAt'] as String) : null,
    );
  }
}

// ── Options ───────────────────────────────────────────────────────────────────

/// Options forwarded to [AgentivityPlatformConnector.startRun].
class AgUiStartRunOptions {
  const AgUiStartRunOptions({this.enableHil = false, this.executionId, this.maxAgentIterations});

  /// Whether to enable Human-in-the-Loop gates for this run.
  final bool enableHil;

  /// Optional execution identifier to attach the run to an existing chain.
  final String? executionId;

  /// Cap on the number of agent iterations (backend-enforced).
  final int? maxAgentIterations;
}

/// Options for [AgentivityPlatformConnector.sendMessage].
class AgUiSendMessageOptions {
  const AgUiSendMessageOptions({this.threadId});

  /// Conversation to write the message in. The main conversation of the execution when omitted.
  final String? threadId;
}

// ── Thread models ─────────────────────────────────────────────────────────────

/// A conversation of an execution, returned by [AgentivityPlatformConnector.listThreads].
class AgUiRunThread {
  const AgUiRunThread({required this.threadId, required this.title, required this.isDefault, required this.status, required this.createdAt});

  final String threadId;
  final String title;
  final bool isDefault;
  final String status;
  final String createdAt;

  factory AgUiRunThread.fromJson(Map<String, dynamic> json) {
    return AgUiRunThread(threadId: (json['threadId'] as String? ?? '').trim(), title: (json['title'] as String? ?? '').trim(), isDefault: json['isDefault'] == true, status: (json['status'] as String? ?? '').trim(), createdAt: (json['createdAt'] as String? ?? '').trim());
  }
}

/// A message in a conversation of an execution, returned by
/// [AgentivityPlatformConnector.listMessages].
class AgUiThreadMessage {
  const AgUiThreadMessage({required this.messageId, required this.threadId, required this.authorType, required this.text, required this.createdAt, this.authorName});

  final String messageId;
  final String threadId;

  /// `"assistant"` | `"user"` | `"system"` | `"tool"`
  final String authorType;
  final String? authorName;
  final String text;
  final String createdAt;

  factory AgUiThreadMessage.fromJson(Map<String, dynamic> json) {
    return AgUiThreadMessage(messageId: (json['messageId'] as String? ?? '').trim(), threadId: (json['threadId'] as String? ?? '').trim(), authorType: (json['authorType'] as String? ?? '').trim(), authorName: json['authorName'] as String?, text: (json['text'] as String? ?? '').trim(), createdAt: (json['createdAt'] as String? ?? '').trim());
  }
}

// ── Connector ─────────────────────────────────────────────────────────────────

/// REST + SSE connector for the Agentivity platform backend (EPIC-0449 contract).
///
/// Works at the level of an execution (`/api/v1/executions`): starting one, listening to its live AG-UI events over
/// SSE, answering the questions it asks a person, and writing in its conversation. Runs, the levels inside an
/// execution, are never needed.
///
/// ## Quick start
///
/// ```dart
/// final connector = AgentivityPlatformConnector(
///   baseUrl: 'https://api.agentivity.com',
///   authToken: 'agp_...',
/// );
///
/// // Start a run
/// final handle = await connector.startRun(
///   'my-workflow-id',
///   'Analyse this document',
///   options: const AgUiStartRunOptions(enableHil: true),
/// );
///
/// // Subscribe to live events
/// await for (final event in connector.openRunStream(handle.runId, streamUrl: handle.streamUrl)) {
///   if (event is TextMessageContentEvent) print(event.delta);
/// }
/// ```
///
/// ## Answering a question
///
/// ```dart
/// // Stream emits RUN_FINISHED with outcome.interrupt — collect user reply:
/// await connector.respond(
///   handle.executionId,
///   requestId: interrupt.id,
///   responseText: userReply,
/// );
/// // The same SSE channel re-emits RUN_STARTED and continues.
/// ```
class AgentivityPlatformConnector {
  AgentivityPlatformConnector({required this.baseUrl, required String authToken, Dio? dio}) : _authToken = authToken.startsWith('Bearer ') ? authToken : 'Bearer $authToken', _dio = dio ?? Dio();

  /// Root URL of the Agentivity backend (no trailing slash).
  ///
  /// Example: `'https://api.agentivity.com'`
  final String baseUrl;

  final String _authToken;
  final Dio _dio;

  String get _executionsBase => '$baseUrl/api/v1/executions';

  // ── Run start ──────────────────────────────────────────────────────────────

  /// Starts an execution of [entityId] (agent, team, or workflow) and returns a
  /// [AgUiRunHandle] containing its [AgUiRunHandle.executionId] and
  /// [AgUiRunHandle.streamUrl].
  ///
  /// Pass [AgUiRunHandle.streamUrl] to [openRunStream] for the best performance
  /// (avoids re-computing the URL).
  Future<AgUiRunHandle> startRun(String entityId, String input, {AgUiStartRunOptions? options}) async {
    final body = <String, dynamic>{'entityId': entityId, 'input': input, 'enableHil': options?.enableHil ?? false};
    final execId = options?.executionId?.trim();
    if (execId != null && execId.isNotEmpty) body['executionId'] = execId;
    final maxIter = options?.maxAgentIterations;
    if (maxIter != null) body['maxAgentIterations'] = maxIter;

    final response = await _dio.post<Map<String, dynamic>>(_executionsBase, data: body, options: Options(headers: {'Authorization': _authToken, 'Content-Type': 'application/json'}, receiveTimeout: const Duration(seconds: 60)));
    return AgUiRunHandle.fromJson(response.data ?? const <String, dynamic>{});
  }

  // ── SSE stream ─────────────────────────────────────────────────────────────

  /// Opens the AG-UI event stream for [runId] and yields [AgUiEvent]s.
  ///
  /// The stream stays alive through HIL interrupts (the backend keeps the SSE
  /// connection open). It only terminates when:
  /// - [RunFinishedEvent] arrives with a non-interrupt outcome (success /
  ///   cancelled / error), or
  /// - [RunErrorEvent] arrives.
  ///
  /// Pass [streamUrl] from [AgUiRunHandle] to use the exact URL returned by
  /// the backend; otherwise the connector computes
  /// `$baseUrl/api/v1/streams/runs/{runId}/events`.
  ///
  /// Heartbeat SSE comments (`: heartbeat`) are silently ignored.
  /// Reconnection with `Last-Event-ID` is handled automatically.
  Stream<AgUiEvent> openRunStream(String runId, {String? streamUrl}) {
    // The platform gives the stream as a path of its own: it is read from it.
    final url = (streamUrl != null && streamUrl.isNotEmpty) ? (Uri.parse(streamUrl).hasScheme ? streamUrl : '$baseUrl$streamUrl') : '$baseUrl/api/v1/streams/runs/$runId/events';
    return _getEventStream(url);
  }

  Stream<AgUiEvent> _getEventStream(String url) async* {
    final channel = AgUiSseChannel<AgUiEvent>(
      opener: (path, {lastEventId, cancelToken}) async {
        return openStreamingRequest(_dio, 'GET', path, cancelToken: cancelToken, headers: {'Accept': 'text/event-stream', 'Authorization': _authToken, 'Cache-Control': 'no-cache', if (lastEventId != null) 'Last-Event-ID': lastEventId});
      },
      path: url,
      parser: _parseAgUiEvent,
    );

    channel.start();
    try {
      await for (final event in channel.stream) {
        yield event;
        // Only close the stream for terminal non-interrupt outcomes.
        if (event is RunErrorEvent) break;
        if (event is RunFinishedEvent && !event.isInterrupted) break;
      }
    } finally {
      await channel.dispose();
    }
  }

  static AgUiEvent? _parseAgUiEvent(String event, String? id, String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      final json = jsonDecode(data);
      if (json is Map<String, dynamic>) return AgUiEvent.fromJson(json);
    } catch (_) {
      // Malformed frame — silently discard.
    }
    return null;
  }

  // ── Questions ─────────────────────────────────────────────────────────────

  /// Answers the question [requestId] of the execution [executionId] (for an interrupt, its id) with [responseText].
  /// Several questions can wait at once: the one answered is named, and the platform takes up again the run that asked
  /// it. The answer is kept in the conversation of the execution.
  ///
  /// After a successful POST the backend emits `RUN_STARTED` on the open SSE
  /// channel and the run continues.
  ///
  /// Throws a [DioException] on non-2xx responses.
  Future<void> respond(String executionId, {required String requestId, required String responseText}) async {
    await _dio.post<void>('$_executionsBase/$executionId/respond', data: {'requestId': requestId, 'response': responseText}, options: Options(headers: {'Authorization': _authToken, 'Content-Type': 'application/json'}));
  }

  // ── Conversation ──────────────────────────────────────────────────────────

  /// Writes [message] in a conversation of the execution [executionId]: the one of [options], or its main one. To
  /// answer a question, use [respond].
  ///
  /// Throws a [DioException] on non-2xx responses.
  Future<void> sendMessage(String executionId, String message, {AgUiSendMessageOptions? options}) async {
    var threadId = options?.threadId?.trim();
    if (threadId == null || threadId.isEmpty) {
      final threads = await listThreads(executionId);
      if (threads.isEmpty) throw StateError('Execution $executionId has no conversation to write in yet.');
      threadId = threads.firstWhere((t) => t.isDefault, orElse: () => threads.first).threadId;
    }
    await _dio.post<void>('$_executionsBase/$executionId/threads/$threadId/messages', data: {'text': message}, options: Options(headers: {'Authorization': _authToken, 'Content-Type': 'application/json'}));
  }

  /// Lists the conversations of the execution [executionId].
  Future<List<AgUiRunThread>> listThreads(String executionId) async {
    final response = await _dio.get<dynamic>('$_executionsBase/$executionId/threads', options: Options(headers: {'Authorization': _authToken}));
    final data = response.data;
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(AgUiRunThread.fromJson).toList();
    }
    return const [];
  }

  /// Lists the messages of the conversation [threadId] of the execution [executionId].
  Future<List<AgUiThreadMessage>> listMessages(String executionId, String threadId) async {
    final response = await _dio.get<dynamic>('$_executionsBase/$executionId/threads/$threadId/messages', options: Options(headers: {'Authorization': _authToken}));
    final data = response.data;
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(AgUiThreadMessage.fromJson).toList();
    }
    return const [];
  }
}
