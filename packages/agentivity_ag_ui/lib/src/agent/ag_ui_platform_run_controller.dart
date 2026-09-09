import 'dart:async';

import 'package:flutter/foundation.dart';

import '../protocol/ag_ui_protocol.dart';
import '../connectors/agentivity_platform_connector.dart';

// ── Status ────────────────────────────────────────────────────────────────────

/// Lifecycle status of a [AgUiPlatformRunController].
enum AgUiPlatformRunStatus {
  /// No run has been started.
  idle,

  /// A run is active and the agent is producing output.
  running,

  /// The run is paused at a HIL gate — awaiting a [AgUiPlatformRunController.resume] call.
  waitingForInput,

  /// The run finished successfully.
  completed,

  /// The run terminated with an error.
  failed,
}

// ── Message ───────────────────────────────────────────────────────────────────

/// A fully-assembled text message produced by an agent run.
///
/// Built from the `TEXT_MESSAGE_START → TEXT_MESSAGE_CONTENT → TEXT_MESSAGE_END`
/// event sequence streamed by the backend.
class AgUiRunMessage {
  const AgUiRunMessage({required this.messageId, required this.role, required this.text, required this.createdAt});

  final String messageId;

  /// `"assistant"` | `"user"` | `"system"` | `"tool"`
  final String role;

  final String text;
  final DateTime createdAt;
}

// ── Controller ────────────────────────────────────────────────────────────────

/// [ChangeNotifier]-based controller that manages the full lifecycle of an
/// Agentivity platform run, including HIL interrupt handling.
///
/// This is the Dart/Flutter equivalent of the `useAgentivityRun` React hook
/// described in the EPIC-0449 frontend spec.
///
/// ## Typical usage
///
/// ```dart
/// final connector = AgentivityPlatformConnector(
///   baseUrl: 'https://api.agentivity.com',
///   authToken: 'Bearer ag_live_...',
/// );
///
/// final controller = AgUiPlatformRunController(connector: connector);
///
/// // Start a run
/// await controller.start(
///   'my-workflow-id',
///   'Analyse this document',
///   options: const AgUiStartRunOptions(enableHil: true),
/// );
///
/// // Inside your widget:
/// ListenableBuilder(
///   listenable: controller,
///   builder: (context, _) {
///     if (controller.status == AgUiPlatformRunStatus.waitingForInput) {
///       return HilPrompt(
///         message: controller.interrupt!.message ?? '',
///         onSubmit: (text) => controller.resume(text),
///       );
///     }
///     return MessageList(messages: controller.messages);
///   },
/// );
/// ```
class AgUiPlatformRunController extends ChangeNotifier {
  AgUiPlatformRunController({required AgentivityPlatformConnector connector}) : _connector = connector;

  final AgentivityPlatformConnector _connector;

  // ── Public state ───────────────────────────────────────────────────────────

  AgUiPlatformRunStatus get status => _status;
  List<AgUiRunMessage> get messages => List.unmodifiable(_messages);

  /// The active HIL interrupt, present when [status] is
  /// [AgUiPlatformRunStatus.waitingForInput].
  AgUiInterrupt? get interrupt => _interrupt;

  /// Error message when [status] is [AgUiPlatformRunStatus.failed].
  String? get error => _error;

  /// The current run ID, set after [start] completes successfully.
  String? get runId => _runId;

  // ── Private state ──────────────────────────────────────────────────────────

  AgUiPlatformRunStatus _status = AgUiPlatformRunStatus.idle;
  final List<AgUiRunMessage> _messages = [];
  AgUiInterrupt? _interrupt;
  String? _error;
  String? _runId;

  StreamSubscription<AgUiEvent>? _sub;

  // In-progress streaming message buffer
  String? _inProgressMessageId;
  String _inProgressRole = 'assistant';
  final StringBuffer _inProgressBuffer = StringBuffer();

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Starts a new run for [entityId] with [input].
  ///
  /// Any previously running run is cancelled first ([reset] is called). The
  /// [status] transitions to [AgUiPlatformRunStatus.running] immediately, then
  /// the controller subscribes to the SSE event stream.
  ///
  /// Errors from [AgentivityPlatformConnector.startRun] set [status] to
  /// [AgUiPlatformRunStatus.failed] and populate [error].
  Future<void> start(String entityId, String input, {AgUiStartRunOptions? options}) async {
    reset();
    _status = AgUiPlatformRunStatus.running;
    notifyListeners();

    try {
      final handle = await _connector.startRun(entityId, input, options: options);
      _runId = handle.runId;
      notifyListeners();

      final stream = _connector.openRunStream(handle.runId, streamUrl: handle.streamUrl);
      _sub = stream.listen(_handleEvent, onError: _handleStreamError, onDone: _handleStreamDone, cancelOnError: false);
    } catch (e) {
      _status = AgUiPlatformRunStatus.failed;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Resumes the current run after a HIL interrupt.
  ///
  /// [responseText] is sent to the backend as the user's response. The [interrupt]
  /// is cleared and [status] is set back to [AgUiPlatformRunStatus.running] in
  /// anticipation of the `RUN_STARTED` event on the SSE channel.
  ///
  /// Does nothing if there is no active [interrupt] or no [runId].
  Future<void> resume(String responseText) async {
    final rid = _runId;
    final activeInterrupt = _interrupt;
    if (rid == null || activeInterrupt == null) return;

    _interrupt = null;
    _status = AgUiPlatformRunStatus.running;
    notifyListeners();

    try {
      await _connector.resumeRun(rid, interruptId: activeInterrupt.id, responseText: responseText);
    } catch (e) {
      _status = AgUiPlatformRunStatus.failed;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Sends a free-text [message] into the current run.
  ///
  /// Does nothing if there is no active [runId].
  Future<void> send(String message, {AgUiSendMessageOptions? options}) async {
    final rid = _runId;
    if (rid == null) return;
    await _connector.sendMessage(rid, message, options: options);
  }

  /// Cancels the active run stream and resets all state back to
  /// [AgUiPlatformRunStatus.idle].
  void reset() {
    _sub?.cancel();
    _sub = null;
    _status = AgUiPlatformRunStatus.idle;
    _messages.clear();
    _interrupt = null;
    _error = null;
    _runId = null;
    _clearInProgress();
    notifyListeners();
  }

  // ── Event handling ─────────────────────────────────────────────────────────

  void _handleEvent(AgUiEvent event) {
    if (event is RunStartedEvent) {
      // Run (re)started — could be the initial start or a resume.
      _status = AgUiPlatformRunStatus.running;
      notifyListeners();
    } else if (event is TextMessageStartEvent) {
      _inProgressMessageId = event.messageId;
      _inProgressRole = event.role;
      _inProgressBuffer.clear();
    } else if (event is TextMessageContentEvent) {
      if (event.messageId == _inProgressMessageId) {
        _inProgressBuffer.write(event.delta);
      }
    } else if (event is TextMessageEndEvent) {
      if (event.messageId == _inProgressMessageId && _inProgressBuffer.isNotEmpty) {
        _messages.add(AgUiRunMessage(messageId: event.messageId, role: _inProgressRole, text: _inProgressBuffer.toString(), createdAt: DateTime.now()));
        _clearInProgress();
        notifyListeners();
      }
    } else if (event is RunFinishedEvent) {
      final outcome = event.outcome;
      if (outcome is AgUiInterruptOutcome && outcome.interrupts.isNotEmpty) {
        _interrupt = outcome.interrupts.first;
        _status = AgUiPlatformRunStatus.waitingForInput;
        // Stream stays open — the backend emits RUN_STARTED after resume.
      } else {
        _status = AgUiPlatformRunStatus.completed;
      }
      notifyListeners();
    } else if (event is RunErrorEvent) {
      _status = AgUiPlatformRunStatus.failed;
      _error = event.message;
      notifyListeners();
    }
    // All other event types (STEP_STARTED, TOOL_CALL_*, STATE_SNAPSHOT, etc.)
    // are intentionally ignored by this controller. Wire additional controllers
    // (e.g. AgUiActivityController, AgUiStateController) to the same stream
    // for richer observability.
  }

  void _handleStreamError(Object error) {
    _status = AgUiPlatformRunStatus.failed;
    _error = error.toString();
    notifyListeners();
  }

  void _handleStreamDone() {
    // Stream closed without a terminal event — treat as completed if still running.
    if (_status == AgUiPlatformRunStatus.running) {
      _status = AgUiPlatformRunStatus.completed;
      notifyListeners();
    }
  }

  void _clearInProgress() {
    _inProgressMessageId = null;
    _inProgressBuffer.clear();
    _inProgressRole = 'assistant';
  }

  // ── Disposal ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
