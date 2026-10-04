import 'dart:async';

import 'package:flutter/foundation.dart';

/// Whether the app can reach the Agentivity server, and when it will try again. The one place the SDK keeps that answer — fed by
/// the HTTP transport (a request that never got an answer) and by the live streams (a stream that dropped and is reconnecting) —
/// so every widget can say so plainly ("can't reach the server, trying again in 12 s") instead of looking stuck.
///
/// While the HTTP side is unreachable the monitor probes the server itself, on a growing delay, and clears as soon as any answer
/// comes back. Streams reconnect on their own schedule; they report it here and can be told to retry at once.
class ServerConnectionState {
  const ServerConnectionState({required this.offline, this.attempt = 0, this.nextRetryAt, this.retrying = false, this.since, this.reason, this.recoveredAt});

  static const online = ServerConnectionState(offline: false);

  /// True while the server cannot be reached.
  final bool offline;

  /// Attempts made since the connection was lost (0 while online).
  final int attempt;

  /// Time of the next automatic attempt — null while one is under way, or while online.
  final DateTime? nextRetryAt;

  /// An attempt is under way right now.
  final bool retrying;

  /// When the connection was lost.
  final DateTime? since;

  /// What failed, as the transport reported it (for the details line).
  final String? reason;

  /// When the connection came back — kept for a few seconds so a notice can say "back online".
  final DateTime? recoveredAt;
}

/// What a live stream tells the monitor about itself.
class StreamConnection {
  const StreamConnection({required this.offline, this.attempt = 0, this.nextRetryAt, this.reason, this.retry});
  final bool offline;
  final int attempt;
  final DateTime? nextRetryAt;
  final String? reason;

  /// Reconnects the stream now instead of waiting for its schedule.
  final VoidCallback? retry;
}

class _Source {
  _Source({required this.since, this.attempt = 0, this.nextRetryAt, this.retrying = false, this.reason, this.retry});
  final DateTime since;
  int attempt;
  DateTime? nextRetryAt;
  bool retrying;
  String? reason;
  VoidCallback? retry;
}

class ConnectionMonitor extends ValueNotifier<ServerConnectionState> {
  /// [probe] asks the server for anything: true when ANY answer came back (even an error status), false when it could not be reached.
  /// [delays] are the waits between probes while unreachable; the last one repeats.
  ConnectionMonitor({this.probe, List<Duration>? delays, DateTime Function()? now})
    : _delays = (delays == null || delays.isEmpty) ? _defaultDelays : delays,
      _now = now ?? DateTime.now,
      super(ServerConnectionState.online);

  static const _defaultDelays = [Duration(seconds: 3), Duration(seconds: 5), Duration(seconds: 8), Duration(seconds: 12), Duration(seconds: 20), Duration(seconds: 30)];
  static const _http = 'http';

  Future<bool> Function()? probe;
  final List<Duration> _delays;
  final DateTime Function() _now;
  final Map<String, _Source> _sources = {};
  Timer? _probeTimer;

  /// A request got no answer at all (server down, network lost, DNS, timeout…).
  void httpFailed([String? reason]) {
    final existing = _sources[_http];
    if (existing != null) {
      if (reason != null) existing.reason = reason;
      return;
    }
    _sources[_http] = _Source(since: _now(), reason: reason, retry: () => unawaited(_runProbe()));
    _scheduleProbe();
    _recompute();
  }

  /// The server answered something — it is reachable.
  void httpReachable() {
    if (_sources.remove(_http) == null) return;
    _clearProbe();
    _recompute();
  }

  /// A live stream's state: offline while it is reconnecting, online once it is connected again (or has ended for good).
  void setStream(String id, StreamConnection stream) {
    final key = 'stream:$id';
    if (!stream.offline) {
      if (_sources.remove(key) != null) _recompute();
      return;
    }
    final previous = _sources[key];
    _sources[key] = _Source(since: previous?.since ?? _now(), attempt: stream.attempt, nextRetryAt: stream.nextRetryAt, retrying: stream.nextRetryAt == null, reason: stream.reason, retry: stream.retry);
    _recompute();
  }

  /// Forgets a stream (it was closed).
  void removeStream(String id) {
    if (_sources.remove('stream:$id') != null) _recompute();
  }

  /// The user asked to try again now: every unreachable source is retried at once.
  void retryNow() {
    for (final source in List.of(_sources.values)) {
      source.retry?.call();
    }
  }

  @override
  void dispose() {
    _clearProbe();
    super.dispose();
  }

  // ── probing ──────────────────────────────────────────────────────────────────────────────────

  void _scheduleProbe() {
    final source = _sources[_http];
    if (source == null || probe == null) return;
    _clearProbe();
    final delay = _delays[source.attempt < _delays.length ? source.attempt : _delays.length - 1];
    source.nextRetryAt = _now().add(delay);
    source.retrying = false;
    _probeTimer = Timer(delay, () => unawaited(_runProbe()));
  }

  Future<void> _runProbe() async {
    final source = _sources[_http];
    if (source == null || probe == null || source.retrying) return;
    _clearProbe();
    source.retrying = true;
    source.nextRetryAt = null;
    source.attempt += 1;
    _recompute();

    var reachable = false;
    try {
      reachable = await probe!();
    } catch (_) {
      reachable = false;
    }

    final current = _sources[_http];
    if (current == null) return;
    if (reachable) {
      httpReachable();
    } else {
      current.retrying = false;
      _scheduleProbe();
      _recompute();
    }
  }

  void _clearProbe() {
    _probeTimer?.cancel();
    _probeTimer = null;
  }

  // ── state ────────────────────────────────────────────────────────────────────────────────────

  void _recompute() {
    if (_sources.isEmpty) {
      value = value.offline ? ServerConnectionState(offline: false, recoveredAt: _now()) : ServerConnectionState(offline: false, recoveredAt: value.recoveredAt);
      return;
    }
    final all = _sources.values.toList();
    final waiting = all.map((s) => s.nextRetryAt).whereType<DateTime>().toList()..sort();
    final since = all.map((s) => s.since).reduce((a, b) => a.isBefore(b) ? a : b);
    value = ServerConnectionState(
      offline: true,
      attempt: all.map((s) => s.attempt).reduce((a, b) => a > b ? a : b),
      nextRetryAt: waiting.isEmpty ? null : waiting.first,
      retrying: all.any((s) => s.retrying),
      since: since,
      reason: all.map((s) => s.reason).whereType<String>().firstOrNull,
    );
  }
}
