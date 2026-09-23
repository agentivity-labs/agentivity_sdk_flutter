import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../protocol/ag_ui_protocol.dart';
import '../protocol/ag_ui_sse_channel.dart';
import '../protocol/platform_stream.dart';
import 'agentivity_signals.dart';

/// Default [AgentivitySignalDecoder] — handles the standard Agentivity frame
/// types (`sync_required`, `change`) and delegates everything else to the
/// AG-UI JSON parser.
final class _DefaultDecoder implements AgentivitySignalDecoder {
  const _DefaultDecoder();

  @override
  AgentivitySignal? decode(String sseEvent, String? data) {
    switch (sseEvent.trim()) {
      case 'sync_required':
        return const AgentivitySyncSignal();
      case 'change':
        return AgentivitySyncSignal(topic: _parseTopic(data));
      default:
        return null;
    }
  }

  static String? _parseTopic(String? rawData) {
    final trimmed = rawData?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      final map =
          decoded is Map<String, dynamic>
              ? decoded
              : decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : null;
      final topic = map?['topic'];
      if (topic is String && topic.trim().isNotEmpty) return topic.trim();
    } catch (_) {}
    return null;
  }
}

// ── _AgentivityFrame (internal union for the SSE channel parser) ──────────────

sealed class _AgentivityFrame {}

final class _ProtocolFrame extends _AgentivityFrame {
  _ProtocolFrame(this.event);
  final AgUiEvent event;
}

final class _SignalFrame extends _AgentivityFrame {
  _SignalFrame(this.signal);
  final AgentivitySignal signal;
}

// ── AgentivityRunStream ───────────────────────────────────────────────────────

/// Agentivity-platform [PlatformStream] adapter.
///
/// The Agentivity SSE transport emits three kinds of frames on the same
/// connection:
///
/// | SSE `event` field | Meaning                           | Routed to         |
/// |-------------------|-----------------------------------|-------------------|
/// | `change`          | Platform change notification       | [signals]         |
/// | `sync_required`   | Full-resync requested by backend  | [signals]         |
/// | anything else     | Standard AG-UI protocol event      | [agUiEvents]      |
///
/// The underlying [AgUiSseChannel] handles reconnection with exponential
/// back-off, a watchdog timer, and `Last-Event-ID` resume.
///
/// ## Usage
///
/// ```dart
/// final stream = AgentivityRunStream(
///   opener: apiClient.openEventStream,
///   path: '/api/v1/streams/runs/$runId/events',
/// )..start();
///
/// stream.agUiEvents.listen(chatController.feedEvent);
/// stream.signals.whereType<AgentivitySyncSignal>().listen(_onSync);
/// ```
class AgentivityRunStream implements PlatformStream {
  AgentivityRunStream._({required AgUiSseChannel<_AgentivityFrame> channel, required Stream<AgUiEvent> agUiStream, required StreamController<PlatformSignal> signalController}) : _channel = channel, _agUiStream = agUiStream, _signalController = signalController;

  factory AgentivityRunStream({required AgUiSseOpener opener, required String path, AgentivitySignalDecoder? decoder}) {
    final effectiveDecoder = decoder ?? const _DefaultDecoder();

    // Replay buffer: accumulates every AG-UI event received from the SSE
    // channel so that late subscribers (e.g. a ChatController created after
    // the tab opens) get all past events replayed synchronously before
    // receiving live ones. This makes the stream behave like an RxJS
    // ReplaySubject — transparent to all consumers, no backend cooperation
    // needed.
    final agUiBuffer = <AgUiEvent>[];
    var agUiDone = false;
    final agUiListeners = <MultiStreamController<AgUiEvent>>[];

    final agUiStream = Stream<AgUiEvent>.multi((controller) {
      // Replay buffered events synchronously to the new subscriber.
      for (final event in agUiBuffer) {
        controller.add(event);
      }
      if (agUiDone) {
        controller.close();
        return;
      }
      agUiListeners.add(controller);
      controller.onCancel = () => agUiListeners.remove(controller);
    });

    final signalController = StreamController<PlatformSignal>.broadcast();

    AgUiSseParser<_AgentivityFrame> parser = (event, id, data) => _parseFrame(event, id, data, effectiveDecoder);

    final channel = AgUiSseChannel<_AgentivityFrame>(opener: opener, path: path, parser: parser);

    final stream = AgentivityRunStream._(channel: channel, agUiStream: agUiStream, signalController: signalController);

    channel.stream.listen(
      (frame) {
        switch (frame) {
          case _ProtocolFrame(:final event):
            agUiBuffer.add(event);
            for (final c in List.of(agUiListeners)) {
              c.add(event);
            }
            // Mark the channel as terminated on clean run end so it does not
            // reconnect and re-deliver RUN_STARTED (which would reset isAwaitingResponse).
            // A RunFinishedEvent with isInterrupted means a HIL gate opened, not that the
            // run is over — terminating here would permanently block reconnection on the
            // next disconnect, however healthy the server is.
            if (event is RunErrorEvent || (event is RunFinishedEvent && !event.isInterrupted)) {
              channel.markTerminated();
            }
          case _SignalFrame(:final signal):
            if (!signalController.isClosed) signalController.add(signal);
        }
      },
      onDone: () {
        agUiDone = true;
        for (final c in List.of(agUiListeners)) {
          c.close();
        }
        agUiListeners.clear();
        signalController.close();
      },
    );

    return stream;
  }

  /// Stream for a single agent run (`/api/v1/streams/runs/{runId}/events`).
  factory AgentivityRunStream.forRun({required AgUiSseOpener opener, required String runId, AgentivitySignalDecoder? decoder}) => AgentivityRunStream(opener: opener, path: '/api/v1/streams/runs/${runId.trim()}/events', decoder: decoder);

  /// Execution-level stream aggregating all runs in an execution chain
  /// (`/api/v1/streams/runs/executions/{executionId}/events`).
  factory AgentivityRunStream.forExecution({required AgUiSseOpener opener, required String executionId, AgentivitySignalDecoder? decoder}) => AgentivityRunStream(opener: opener, path: '/api/v1/streams/runs/executions/${executionId.trim()}/events', decoder: decoder);

  /// Workspace-level collection stream covering all runs
  /// (`/api/v1/streams/runs/events`).
  factory AgentivityRunStream.forCollection({required AgUiSseOpener opener, AgentivitySignalDecoder? decoder}) => AgentivityRunStream(opener: opener, path: '/api/v1/streams/runs/events', decoder: decoder);

  final AgUiSseChannel<_AgentivityFrame> _channel;
  final Stream<AgUiEvent> _agUiStream;
  final StreamController<PlatformSignal> _signalController;

  @override
  Stream<AgUiEvent> get agUiEvents => _agUiStream;

  @override
  Stream<PlatformSignal> get signals => _signalController.stream;

  @override
  ValueListenable<bool> get connected => _channel.connectedNotifier;

  /// Structured connection state — see [AgUiConnectionState]. Prefer this over [connected]
  /// to show an honest "reconnecting, attempt 3, retrying in 12s" status instead of a
  /// generic error.
  ValueListenable<AgUiConnectionState> get connectionState => _channel.connectionStateNotifier;

  @override
  void start() => _channel.start();

  @override
  Future<void> dispose() async {
    await _channel.dispose();
    await _signalController.close();
  }

  // ── Frame parser ────────────────────────────────────────────────────────────

  static _AgentivityFrame? _parseFrame(String event, String? id, String? data, AgentivitySignalDecoder decoder) {
    final normalized = event.trim().isEmpty ? 'message' : event.trim();

    final signal = decoder.decode(normalized, data);
    if (signal != null) return _SignalFrame(signal);

    // Standard AG-UI JSON frame.
    final raw = data?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        // Mirror agUiEventParser: if the JSON has no 'type' field, use the
        // SSE event name as the discriminator so backends that use SSE event
        // names (e.g. event: CUSTOM) instead of a JSON 'type' field work too.
        final json = (!decoded.containsKey('type') && normalized != 'message') ? (Map<String, dynamic>.from(decoded)..['type'] = normalized) : decoded;
        final agUiEvent = AgUiEvent.fromJson(json);
        debugPrint('AgentivityRunStream[$normalized]: parsed ${agUiEvent.type}');
        return _ProtocolFrame(agUiEvent);
      }
    } catch (_) {
      debugPrint('AgentivityRunStream: failed to parse frame (event=$normalized, data=$raw)');
    }
    return null;
  }
}
