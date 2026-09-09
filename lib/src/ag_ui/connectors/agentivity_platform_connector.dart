import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../protocol/ag_ui_protocol.dart';
import '../protocol/ag_ui_sse_channel.dart';

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
  const AgUiSendMessageOptions({this.threadId, this.interactionRequestId});

  /// Thread to post the message into. Uses the default thread when omitted.
  final String? threadId;

  /// Optional HIL interaction request ID when responding to a specific gate.
  final String? interactionRequestId;
}

// ── Thread models ─────────────────────────────────────────────────────────────

/// A chat thread on a run, returned by [AgentivityPlatformConnector.listThreads].
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

/// A message in a run thread, returned by
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
/// Implements the unified `/api/v1/runs` API: starting runs, listening to live
/// AG-UI events over SSE, resuming HIL interrupts, and sending chat messages.
///
/// ## Quick start
///
/// ```dart
/// final connector = AgentivityPlatformConnector(
///   baseUrl: 'https://api.agentivity.com',
///   authToken: 'Bearer ag_live_...',
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
/// await for (final event in connector.openRunStream(handle.runId)) {
///   if (event is TextMessageContentEvent) print(event.delta);
/// }
/// ```
///
/// ## HIL resume
///
/// ```dart
/// // Stream emits RUN_FINISHED with outcome.interrupt — collect user reply:
/// await connector.resumeRun(
///   handle.runId,
///   interruptId: interrupt.id,
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

  String get _runsBase => '$baseUrl/api/v1/runs';

  // ── Run start ──────────────────────────────────────────────────────────────

  /// Starts a run for [entityId] (agent, team, or workflow) and returns a
  /// [AgUiRunHandle] containing the [AgUiRunHandle.runId] and
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

    final response = await _dio.post<Map<String, dynamic>>(_runsBase, data: body, options: Options(headers: {'Authorization': _authToken, 'Content-Type': 'application/json'}, receiveTimeout: const Duration(seconds: 60)));
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
    final url = (streamUrl != null && streamUrl.isNotEmpty) ? streamUrl : '$baseUrl/api/v1/streams/runs/$runId/events';
    return _getEventStream(url);
  }

  Stream<AgUiEvent> _getEventStream(String url) async* {
    final channel = AgUiSseChannel<AgUiEvent>(
      opener: (path, {lastEventId, cancelToken}) async {
        final response = await _dio.get<ResponseBody>(path, cancelToken: cancelToken, options: Options(responseType: ResponseType.stream, headers: {'Accept': 'text/event-stream', 'Authorization': _authToken, 'Cache-Control': 'no-cache', if (lastEventId != null) 'Last-Event-ID': lastEventId}, receiveTimeout: Duration.zero));
        final body = response.data;
        if (body == null) {
          throw StateError('AgentivityPlatformConnector: SSE stream returned no body for $url');
        }
        return body;
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

  // ── HIL resume ────────────────────────────────────────────────────────────

  /// Resumes [runId] after a HIL interrupt by submitting [responseText] for
  /// [interruptId].
  ///
  /// After a successful POST the backend emits `RUN_STARTED` on the open SSE
  /// channel and the run continues.
  ///
  /// Throws a [DioException] on non-2xx responses.
  Future<void> resumeRun(String runId, {required String interruptId, required String responseText}) async {
    await _dio.post<void>(
      '$_runsBase/$runId/resume',
      data: {
        'interruptId': interruptId,
        'response': {'text': responseText},
      },
      options: Options(headers: {'Authorization': _authToken, 'Content-Type': 'application/json'}),
    );
  }

  // ── Free-chat message ─────────────────────────────────────────────────────

  /// Sends a free-text [message] into an ongoing run.
  ///
  /// Use [options] to target a specific thread or attach an interaction request
  /// ID when responding to a specific HIL gate.
  ///
  /// Throws a [DioException] on non-2xx responses.
  Future<void> sendMessage(String runId, String message, {AgUiSendMessageOptions? options}) async {
    final body = <String, dynamic>{'message': message};
    final tid = options?.threadId?.trim();
    if (tid != null && tid.isNotEmpty) body['threadId'] = tid;
    final irid = options?.interactionRequestId?.trim();
    if (irid != null && irid.isNotEmpty) body['interactionRequestId'] = irid;

    await _dio.post<void>('$_runsBase/$runId/interactions', data: body, options: Options(headers: {'Authorization': _authToken, 'Content-Type': 'application/json'}));
  }

  // ── Thread management ─────────────────────────────────────────────────────

  /// Lists the chat threads for [runId].
  Future<List<AgUiRunThread>> listThreads(String runId) async {
    final response = await _dio.get<dynamic>('$_runsBase/$runId/threads', options: Options(headers: {'Authorization': _authToken}));
    final data = response.data;
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(AgUiRunThread.fromJson).toList();
    }
    return const [];
  }

  /// Lists messages in [threadId] for [runId].
  Future<List<AgUiThreadMessage>> listMessages(String runId, String threadId) async {
    final response = await _dio.get<dynamic>('$_runsBase/$runId/threads/$threadId/messages', options: Options(headers: {'Authorization': _authToken}));
    final data = response.data;
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(AgUiThreadMessage.fromJson).toList();
    }
    return const [];
  }
}
