import 'dart:async';

import 'package:flutter/material.dart';

import '../../../client/core/connection_monitor.dart';

/// How long "Connection restored" stays up after the server is back.
const _restoredFor = Duration(seconds: 3);

/// The words for each state, shared with any app that wants to word it itself. Null when there is nothing to say.
({String title, String detail, int? secondsLeft})? agUiDescribeConnection(ServerConnectionState state, DateTime now) {
  if (state.offline) {
    final next = state.nextRetryAt;
    final secondsLeft = next == null ? null : (next.difference(now).inMilliseconds / 1000).ceil().clamp(0, 1 << 30);
    final detail =
        state.retrying || secondsLeft == 0
            ? 'Trying to reconnect…'
            : secondsLeft != null
            ? 'Reconnecting automatically — next attempt in $secondsLeft s.'
            : 'Reconnecting automatically…';
    return (title: "Can't reach the server", detail: detail, secondsLeft: secondsLeft);
  }
  final restored = state.recoveredAt;
  if (restored != null && now.difference(restored) < _restoredFor) {
    return (title: 'Connection restored', detail: 'You are back online.', secondsLeft: null);
  }
  return null;
}

/// Says plainly that the server cannot be reached — and that the app is already trying again, with a countdown to the next
/// attempt and a "Retry now" button — instead of leaving a conversation that just looks stuck. [AgUiChatDiscussion] shows it when
/// given a `connection`; any other screen can render it with `client.connection`.
class AgUiConnectionNotice extends StatefulWidget {
  const AgUiConnectionNotice({super.key, required this.monitor});

  final ConnectionMonitor monitor;

  @override
  State<AgUiConnectionNotice> createState() => _AgUiConnectionNoticeState();
}

class _AgUiConnectionNoticeState extends State<AgUiConnectionNotice> {
  Timer? _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    widget.monitor.addListener(_onChange);
    _sync();
  }

  @override
  void didUpdateWidget(AgUiConnectionNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monitor != widget.monitor) {
      oldWidget.monitor.removeListener(_onChange);
      widget.monitor.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.monitor.removeListener(_onChange);
    _tick?.cancel();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() => _now = DateTime.now());
    _sync();
  }

  // Ticks once a second while there is something to count down or a "restored" message to retire.
  void _sync() {
    final state = widget.monitor.value;
    final restored = state.recoveredAt;
    final active = state.offline || (restored != null && DateTime.now().difference(restored) < _restoredFor);
    if (active && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
        final s = widget.monitor.value;
        final r = s.recoveredAt;
        if (!s.offline && (r == null || DateTime.now().difference(r) >= _restoredFor)) {
          _tick?.cancel();
          _tick = null;
        }
      });
    } else if (!active) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.monitor.value;
    final text = agUiDescribeConnection(state, _now);
    if (text == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = state.offline ? const Color(0xFFD97706) : const Color(0xFF10B981);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), border: Border.all(color: color.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text.title, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(state.offline && state.attempt > 0 ? '${text.detail} (attempt ${state.attempt})' : text.detail, style: textTheme.bodySmall),
                  if (state.offline && state.reason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(state.reason!, style: textTheme.bodySmall?.copyWith(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
            if (state.offline)
              OutlinedButton(onPressed: state.retrying ? null : widget.monitor.retryNow, child: const Text('Retry now')),
          ],
        ),
      ),
    );
  }
}
