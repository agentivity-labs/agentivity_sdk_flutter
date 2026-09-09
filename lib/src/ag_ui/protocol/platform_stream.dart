import 'package:flutter/foundation.dart';

import 'ag_ui_protocol.dart';

// ── Platform signal ───────────────────────────────────────────────────────────

/// An out-of-band signal emitted by a platform adapter on the same transport
/// as AG-UI events.
///
/// Platform signals carry platform-specific information (cache invalidation,
/// control commands, etc.) that is not part of the AG-UI protocol itself.
/// Consumers that only care about AG-UI events can ignore this stream entirely.
///
/// Platform adapters extend this class to define their own signal types.
abstract class PlatformSignal {
  const PlatformSignal();
}

// ── Interface ─────────────────────────────────────────────────────────────────

/// Generic interface for a live agent run stream that multiplexes AG-UI
/// protocol events and platform-specific signals on a single transport.
///
/// Implementations connect to a specific backend (Agentivity, LangGraph, …)
/// and expose two separate streams so consumers can subscribe only to what
/// they need.
///
/// ## Lifecycle
///
/// ```dart
/// final stream = connector.openStream(runId)..start();
/// stream.agUiEvents.listen(chatController.feedEvent);
/// stream.signals.listen(_onPlatformSignal);
/// // on dispose:
/// await stream.dispose();
/// ```
///
/// ## Consuming events
///
/// ```dart
/// // AG-UI only — fully cross-platform
/// stream.agUiEvents.listen((event) {
///   chatController.feedEvent(event);
/// });
///
/// // Platform signals — cast to the concrete type for the platform in use
/// stream.signals.whereType<AgentivitySyncSignal>().listen((signal) {
///   _scheduleRefresh(signal.topic);
/// });
/// ```
abstract interface class PlatformStream {
  /// Standard AG-UI protocol events emitted by this run.
  ///
  /// Route to a [ChatController] via `feedEvent(event)` or any AG-UI-aware
  /// controller. This stream is cross-platform — consumers have no knowledge
  /// of SSE, HTTP, or platform-specific wire formats.
  Stream<AgUiEvent> get agUiEvents;

  /// Platform-specific signals emitted alongside AG-UI events.
  ///
  /// The concrete type depends on the platform adapter in use. Cast with
  /// [Stream.whereType] to handle specific signal types:
  ///
  /// ```dart
  /// stream.signals.whereType<AgentivitySyncSignal>().listen(_onSync);
  /// ```
  ///
  /// Platforms that have no out-of-band signals expose an empty stream.
  Stream<PlatformSignal> get signals;

  /// Whether the underlying transport is currently connected.
  ///
  /// Listen with [ValueListenableBuilder] or [ValueListenable.addListener]
  /// to react to reconnection state changes.
  ValueListenable<bool> get connected;

  /// Starts the transport. No-op after the first call.
  void start();

  /// Terminates the transport and releases all resources.
  Future<void> dispose();
}
