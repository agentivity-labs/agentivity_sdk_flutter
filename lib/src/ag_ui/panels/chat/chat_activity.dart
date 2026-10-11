import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// What the conversation is busy with while a run is in progress and nothing has been said yet. Given to
/// [AgUiChatActivityStyle.label] and to a custom `activityBuilder`, so each can say it its own way.
@immutable
class AgUiChatActivity {
  const AgUiChatActivity({this.label, this.stepName, this.memberEntityId, this.memberName});

  /// What the app says is going on ("Reading your files"), when it knows better than the stream does.
  final String? label;

  /// The step of the run in progress, as the stream names it (a node id for a workflow): for apps that can turn it into words.
  final String? stepName;

  /// The Team member taking its turn, when there is one.
  final String? memberEntityId;
  final String? memberName;

  @override
  bool operator ==(Object other) =>
      other is AgUiChatActivity && other.label == label && other.stepName == stepName && other.memberEntityId == memberEntityId && other.memberName == memberName;

  @override
  int get hashCode => Object.hash(label, stepName, memberEntityId, memberName);
}

/// How the mark beside the text moves.
enum AgUiChatActivityAnimation {
  /// Three dots lighting up one after the other.
  dots,

  /// One mark (a dot, or [AgUiChatActivityStyle.icon]) breathing.
  pulse,

  /// One mark turning (a ring, or [AgUiChatActivityStyle.icon]).
  spin,

  /// A still mark: nothing moves.
  none,
}

/// The look of the activity indicator. Everything is optional: what is left out comes from the app's theme.
@immutable
class AgUiChatActivityStyle {
  const AgUiChatActivityStyle({
    this.animation = AgUiChatActivityAnimation.dots,
    this.icon,
    this.color,
    this.textStyle,
    this.size = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.delay = const Duration(milliseconds: 300),
    this.period = const Duration(milliseconds: 1200),
    this.thinkingLabel = 'Thinking…',
    this.label,
    this.showLabel = true,
  });

  final AgUiChatActivityAnimation animation;

  /// The mark that pulses or spins, instead of the default dot or ring. Not used by [AgUiChatActivityAnimation.dots].
  final IconData? icon;

  /// The colour of the mark. Defaults to the theme's primary colour.
  final Color? color;

  /// The style of the text. Defaults to a small, muted text.
  final TextStyle? textStyle;

  /// The height of the mark.
  final double size;

  final EdgeInsetsGeometry padding;

  /// How long the run must have been busy before the indicator shows: a quick answer shows none at all.
  final Duration delay;

  /// The length of one cycle of the animation.
  final Duration period;

  /// What is said when nothing more is known.
  final String thinkingLabel;

  /// Turns what is going on into the text shown. Defaults to the app's own label, then "<member> is working on it…", then
  /// [thinkingLabel].
  final String Function(AgUiChatActivity activity)? label;

  /// False shows the mark alone.
  final bool showLabel;

  String labelOf(AgUiChatActivity activity) {
    if (label != null) return label!(activity);
    final said = activity.label?.trim();
    if (said != null && said.isNotEmpty) return said;
    final member = (activity.memberName ?? activity.memberEntityId)?.trim();
    if (member != null && member.isNotEmpty) return '$member is working on it…';
    return thinkingLabel;
  }
}

/// A discreet "it is working" line: a small moving mark and a short text. It is shown while [activity] is not null, after
/// [AgUiChatActivityStyle.delay], and gone the moment it is null again. It holds no timer of its own beyond that delay: what
/// it shows is only ever what it is given.
///
/// [AgUiChatDiscussion] places it above the input on its own (`showActivityIndicator`); it is public for layouts that put it
/// elsewhere.
class AgUiChatActivityIndicator extends StatefulWidget {
  const AgUiChatActivityIndicator({super.key, required this.activity, this.style = const AgUiChatActivityStyle(), this.builder});

  /// What is going on; null when nothing is.
  final AgUiChatActivity? activity;
  final AgUiChatActivityStyle style;

  /// Draws the indicator instead of the default one; the delay and the disappearance still apply.
  final Widget Function(BuildContext context, AgUiChatActivity activity)? builder;

  @override
  State<AgUiChatActivityIndicator> createState() => _AgUiChatActivityIndicatorState();
}

class _AgUiChatActivityIndicatorState extends State<AgUiChatActivityIndicator> {
  Timer? _timer;
  bool _due = false;

  @override
  void initState() {
    super.initState();
    _sync(wasBusy: false);
  }

  @override
  void didUpdateWidget(AgUiChatActivityIndicator old) {
    super.didUpdateWidget(old);
    _sync(wasBusy: old.activity != null);
  }

  void _sync({required bool wasBusy}) {
    final busy = widget.activity != null;
    // Only starting and stopping matter: a change of what is said while busy does not restart the delay.
    if (busy == wasBusy) return;
    _timer?.cancel();
    _timer = null;
    if (!busy) {
      _due = false;
      return;
    }

    if (widget.style.delay <= Duration.zero) {
      _due = true;
      return;
    }

    _due = false;
    _timer = Timer(widget.style.delay, () {
      _timer = null;
      if (mounted) setState(() => _due = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    if (activity == null || !_due) return const SizedBox.shrink();
    if (widget.builder != null) return widget.builder!(context, activity);

    final theme = Theme.of(context);
    final style = widget.style;
    final color = style.color ?? theme.colorScheme.primary;
    final textStyle = style.textStyle ?? theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final text = style.labelOf(activity);
    // People who asked their system for less motion get a still mark.
    final animation = (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ? AgUiChatActivityAnimation.none : style.animation;

    return Semantics(
      liveRegion: true,
      label: text,
      child: Padding(
        padding: style.padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: _ActivityMark(animation: animation, icon: style.icon, color: color, size: style.size, period: style.period)),
            if (style.showLabel) ...[
              const SizedBox(width: 8),
              Flexible(child: ExcludeSemantics(child: Text(text, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis))),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityMark extends StatefulWidget {
  const _ActivityMark({required this.animation, required this.icon, required this.color, required this.size, required this.period});

  final AgUiChatActivityAnimation animation;
  final IconData? icon;
  final Color color;
  final double size;
  final Duration period;

  @override
  State<_ActivityMark> createState() => _ActivityMarkState();
}

class _ActivityMarkState extends State<_ActivityMark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(_ActivityMark old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period) _controller.duration = widget.period;
    if (old.animation != widget.animation || old.period != widget.period) _run();
  }

  void _run() {
    if (widget.animation == AgUiChatActivityAnimation.none) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _still() => widget.icon != null
      ? Icon(widget.icon, size: widget.size, color: widget.color)
      : Container(width: widget.size * 0.5, height: widget.size * 0.5, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle));

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    switch (widget.animation) {
      case AgUiChatActivityAnimation.none:
        return SizedBox(height: size, child: Center(widthFactor: 1, child: _still()));

      case AgUiChatActivityAnimation.pulse:
        return SizedBox(
          height: size,
          child: Center(
            widthFactor: 1,
            child: AnimatedBuilder(
              animation: _controller,
              child: _still(),
              builder: (context, child) {
                // One breath per cycle: in and out.
                final wave = 0.5 - 0.5 * math.cos(_controller.value * 2 * math.pi);
                return Opacity(opacity: 0.35 + 0.65 * wave, child: Transform.scale(scale: 0.8 + 0.2 * wave, child: child));
              },
            ),
          ),
        );

      case AgUiChatActivityAnimation.spin:
        return SizedBox(
          width: size,
          height: size,
          child: widget.icon != null
              ? RotationTransition(turns: _controller, child: Icon(widget.icon, size: size, color: widget.color))
              : AnimatedBuilder(animation: _controller, builder: (context, _) => CustomPaint(painter: _RingPainter(turn: _controller.value, color: widget.color))),
        );

      case AgUiChatActivityAnimation.dots:
        final dot = size * 0.32;
        return SizedBox(
          height: size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) SizedBox(width: dot * 0.75),
                  Opacity(
                    // Each dot lights up a little after the one before it.
                    opacity: 0.25 + 0.75 * math.max(0.0, math.sin((_controller.value - i * 0.16) * 2 * math.pi)),
                    child: Container(width: dot, height: dot, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
                  ),
                ],
              ],
            ),
          ),
        );
    }
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.turn, required this.color});

  final double turn;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(1.5, size.shortestSide * 0.14);
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = color.withValues(alpha: 0.2));
    canvas.drawArc(rect, turn * 2 * math.pi, math.pi * 0.6, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.turn != turn || old.color != color;
}
