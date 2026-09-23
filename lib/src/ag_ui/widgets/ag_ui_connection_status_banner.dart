import 'dart:async';

import 'package:flutter/material.dart';

import '../protocol/ag_ui_sse_channel.dart';

/// Honest connection status for an AG-UI run stream (e.g. [AgentivityRunStream.connectionState])
/// — replaces a generic error with what's actually happening: still connecting,
/// reconnecting (with attempt count and a live countdown to the next try), or done
/// because the run finished. Renders nothing once actually connected or terminated, so
/// it never clutters the normal case.
///
/// Unstyled beyond a small default text/dot look driven by [ThemeData] — pass [textStyle]
/// or [buildMessage] to restyle/localize.
class AgUiConnectionStatusBanner extends StatefulWidget {
  const AgUiConnectionStatusBanner({super.key, required this.state, this.buildMessage, this.textStyle});

  final AgUiConnectionState state;

  /// Overrides the default English copy — e.g. for localization. Receives the raw state
  /// and the live-computed seconds left until the next retry (when known); return `null`
  /// to suppress the banner for that state.
  final String? Function(AgUiConnectionState state, int? secondsLeft)? buildMessage;

  final TextStyle? textStyle;

  @override
  State<AgUiConnectionStatusBanner> createState() => _AgUiConnectionStatusBannerState();
}

class _AgUiConnectionStatusBannerState extends State<AgUiConnectionStatusBanner> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(AgUiConnectionStatusBanner old) {
    super.didUpdateWidget(old);
    if (old.state.status != widget.state.status) _syncTicker();
  }

  void _syncTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (widget.state.status == AgUiConnectionStatus.reconnecting) {
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() => _now = DateTime.now()));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String? _defaultMessage(AgUiConnectionState state, int? secondsLeft) {
    if (state.status == AgUiConnectionStatus.connecting) return 'Connecting…';
    final suffix = secondsLeft != null && secondsLeft > 0 ? ' in ${secondsLeft}s…' : '…';
    return 'Connection lost — reconnecting (attempt ${state.attempt})$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.status == AgUiConnectionStatus.connected || state.status == AgUiConnectionStatus.terminated) {
      return const SizedBox.shrink();
    }

    final secondsLeft = state.nextRetryAt != null ? state.nextRetryAt!.difference(_now).inSeconds.clamp(0, 1 << 30) : null;
    final message = (widget.buildMessage ?? _defaultMessage)(state, secondsLeft);
    if (message == null) return const SizedBox.shrink();

    final color = state.status == AgUiConnectionStatus.reconnecting ? const Color(0xFFB45309) : Theme.of(context).colorScheme.onSurfaceVariant;
    final style = widget.textStyle ?? Theme.of(context).textTheme.bodySmall?.copyWith(color: color) ?? TextStyle(fontSize: 11, color: color);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: color, pulsing: state.status == AgUiConnectionStatus.reconnecting),
          const SizedBox(width: 6),
          Flexible(child: Text(message, style: style)),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.pulsing});

  final Color color;
  final bool pulsing;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle));
    if (!widget.pulsing) return dot;
    return FadeTransition(opacity: Tween(begin: 0.35, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)), child: dot);
  }
}
