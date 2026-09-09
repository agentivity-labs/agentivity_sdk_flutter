import '../protocol/platform_stream.dart';

// -- Agentivity platform signals -----------------------------------------------

/// Base class for all signals emitted by the Agentivity platform adapter.
///
/// Consumers can filter with [Stream.whereType]:
/// ```dart
/// stream.signals.whereType<AgentivitySignal>().listen(_onSignal);
/// ```
abstract class AgentivitySignal extends PlatformSignal {
  const AgentivitySignal();
}

/// Signals that one or more data topics need to be refreshed.
///
/// Emitted by the Agentivity SSE adapter for two frame types:
/// - `event: change`        -> carries a specific [topic]
/// - `event: sync_required` -> [topic] is `null` (full resync)
///
/// When [topic] is `null`, consumers should treat all state as stale.
///
/// ```dart
/// stream.signals.whereType<AgentivitySyncSignal>().listen((signal) {
///   if (signal.topic == null || signal.topic == AgentivitySyncSignal.execution) {
///     _scheduleRefresh();
///   }
/// });
/// ```
final class AgentivitySyncSignal extends AgentivitySignal {
  const AgentivitySyncSignal({this.topic});

  /// Affected topic, or `null` to indicate a full resync is needed.
  final String? topic;

  /// Well-known topic values emitted by the Agentivity platform adapter.
  static const String chat = 'chat';
  static const String forms = 'forms';
  static const String interactions = 'interactions';
  static const String execution = 'execution';
}

// -- Decoder -------------------------------------------------------------------

/// Translates Agentivity-specific SSE frames into [AgentivitySignal]s.
///
/// Injected into [AgentivityRunStream] at construction time so it can be
/// replaced in tests or extended with custom signal types.
///
/// Return `null` for frames that carry standard AG-UI JSON payloads -- those
/// are decoded separately and emitted on [PlatformStream.agUiEvents].
abstract interface class AgentivitySignalDecoder {
  /// Decode an SSE frame.
  ///
  /// [sseEvent] is the raw `event:` field value (may be empty for default
  /// message frames). [data] is the raw `data:` payload string, or `null`.
  ///
  /// Returns an [AgentivitySignal] if the frame is a platform signal, or
  /// `null` if it should be treated as a standard AG-UI protocol event.
  AgentivitySignal? decode(String sseEvent, String? data);
}
