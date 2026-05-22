import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';

/// Vertical event timeline.
///
/// Agent props:
/// ```json
/// {
///   "title": "Deployment pipeline",
///   "events": [
///     { "label": "Build",    "time": "09:12", "status": "success" },
///     { "label": "Test",     "time": "09:18", "status": "success" },
///     { "label": "Deploy",   "time": "09:25", "status": "running" },
///     { "label": "Verify",   "time": "",      "status": "pending" }
///   ]
/// }
/// ```
/// Event [status]: "success", "error", "warning", "running", "pending" (default).
class AgTimeline extends StatelessWidget {
  const AgTimeline({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = props['title'] as String? ?? 'Timeline';
    final events = (props['events'] as List?) ?? [];

    return AgArtifactCard(
      title: title,
      type: 'Timeline',
      icon: Icons.timeline_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < events.length; i++)
            _TimelineEvent(
              event: events[i] as Map<String, dynamic>,
              isLast: i == events.length - 1,
              cs: cs,
            ),
        ],
      ),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({
    required this.event,
    required this.isLast,
    required this.cs,
  });

  final Map<String, dynamic> event;
  final bool isLast;
  final ColorScheme cs;

  (Color, IconData, bool) _style(String? status) {
    return switch (status) {
      'success' => (const Color(0xFF10b981), Icons.check_circle_rounded,   false),
      'error'   => (const Color(0xFFef4444), Icons.cancel_rounded,         false),
      'warning' => (const Color(0xFFf59e0b), Icons.warning_rounded,        false),
      'running' => (cs.primary,              Icons.radio_button_on_rounded, true),
      _          => (cs.outline,             Icons.radio_button_off_rounded, false),
    };
  }

  @override
  Widget build(BuildContext context) {
    final label  = event['label']?.toString() ?? '';
    final time   = event['time']?.toString() ?? '';
    final status = event['status'] as String?;
    final note   = event['note']?.toString();

    final (color, icon, pulse) = _style(status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dot + line
          SizedBox(
            width: 28,
            child: Column(
              children: [
                _PulsingDot(icon: icon, color: color, pulse: pulse),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.icon, required this.color, required this.pulse});
  final IconData icon;
  final Color color;
  final bool pulse;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) {
      return Icon(widget.icon, size: 18, color: widget.color);
    }
    return FadeTransition(
      opacity: _anim,
      child: Icon(widget.icon, size: 18, color: widget.color),
    );
  }
}
