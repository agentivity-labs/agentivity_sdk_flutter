import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../client/app_client/domain/workflow_graph_models.dart';
import 'chat_controller.dart';
import 'execution_statuses_controller.dart';
import 'workflow_graph_layout.dart';

/// Status/kind colors for [AgUiWorkflowGraph]. Override to retheme — same idea as [AgUiTeamPalette].
class AgUiWorkflowPalette {
  const AgUiWorkflowPalette({
    this.working = const Color(0xFFF1633B),
    this.waiting = const Color(0xFFE3A94F),
    this.done = const Color(0xFF10B981),
    this.failed = const Color(0xFFDC2626),
    this.start = const Color(0xFF10B981),
    this.decision = const Color(0xFFF59E0B),
    this.human = const Color(0xFF2563EB),
    this.ai = const Color(0xFF8B5CF6),
    this.end = const Color(0xFF334155),
    this.action = const Color(0xFF64748B),
  });
  final Color working;
  final Color waiting;
  final Color done;
  final Color failed;

  /// One color per node kind — the graph's own visual grammar (what a node DOES), independent of
  /// the working/waiting/done ring (what it's currently DOING).
  final Color start;
  final Color decision;
  final Color human;
  final Color ai;
  final Color end;
  final Color action;

  Color statusColor(WorkflowStepStatus? status) => switch (status) {
    WorkflowStepStatus.working => working,
    WorkflowStepStatus.waiting => waiting,
    WorkflowStepStatus.done => done,
    WorkflowStepStatus.failed => failed,
    null => const Color(0x00000000),
  };

  Color kindColor(WorkflowNodeKind kind) => switch (kind) {
    WorkflowNodeKind.start => start,
    WorkflowNodeKind.decision => decision,
    WorkflowNodeKind.human => human,
    WorkflowNodeKind.ai => ai,
    WorkflowNodeKind.end => end,
    WorkflowNodeKind.action => action,
  };
}

/// Text for a node's status, shared by the widget's tooltips and screen-reader labels.
String workflowStepStatusText(WorkflowStepStatus? status) => switch (status) {
  WorkflowStepStatus.working => 'in progress',
  WorkflowStepStatus.waiting => 'waiting on you',
  WorkflowStepStatus.done => 'done',
  WorkflowStepStatus.failed => 'failed',
  null => 'not reached yet',
};

IconData _kindIcon(WorkflowNodeKind kind) => switch (kind) {
  WorkflowNodeKind.start => Icons.play_arrow,
  WorkflowNodeKind.decision => Icons.call_split,
  WorkflowNodeKind.human => Icons.chat_bubble,
  WorkflowNodeKind.ai => Icons.memory,
  WorkflowNodeKind.end => Icons.check,
  WorkflowNodeKind.action => Icons.settings,
};

const _nodeRadius = 20.0;
const _labelMax = 18;

/// How much of the diagram (in [workflow_graph_layout.dart]'s own layout units, i.e. [colGap])
/// stays in view once the camera focuses a node — about one neighbor's worth on either side, not
/// the whole diagram. The zoom level that achieves that depends on how sprawling this particular
/// workflow's layout is, so it's computed from the layout's own width, not a constant.
const _focusSpan = 360.0;
const _minScale = 0.4;
const _maxScale = 6.0;

/// A Workflow's node graph as a flow diagram — same live-status idea as [AgUiTeamGraph] (driven
/// by [ChatController], lights up as the run reaches each node) but for a Workflow's actual node
/// graph instead of a Team's member constellation: circles left-to-right, one per node, linked by
/// the workflow's real execution-flow edges (a decision node's branches carry their condition's
/// label, same as the workflow editor). The camera opens centered on the start node and glides to
/// follow whichever node is currently running — dragging or zooming by hand takes over until the
/// "Recenter" button hands control back. Mirrors the React SDK's `WorkflowGraph` exactly.
class AgUiWorkflowGraph extends StatefulWidget {
  const AgUiWorkflowGraph({
    super.key,
    required this.controller,
    required this.structure,
    this.statusSource,
    this.palette = const AgUiWorkflowPalette(),
  });

  final ChatController controller;

  /// Where node statuses come from — an [ExecutionStatusesController] reading the execution's own
  /// status API (right on a fresh run, after a reconnect and when reopening an old execution). When
  /// omitted the graph falls back to what [controller] has seen on the stream ([ChatController.stepStatuses]),
  /// which is empty for anything that happened before this screen was open.
  final ExecutionStatusesController? statusSource;

  /// The workflow's flow structure — from `client.entities.fetchWorkflowGraph(workflowId)`.
  final WorkflowGraphStructure structure;
  final AgUiWorkflowPalette palette;

  @override
  State<AgUiWorkflowGraph> createState() => _AgUiWorkflowGraphState();
}

class _AgUiWorkflowGraphState extends State<AgUiWorkflowGraph>
    with TickerProviderStateMixin {
  final TransformationController _view = TransformationController();
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  AnimationController? _followAnim;

  late WorkflowLayout _layout;
  Size _viewportSize = Size.zero;
  bool _following = true;
  String? _lastActive;
  String? _seenActive;
  bool _didInitialFocus = false;

  @override
  void initState() {
    super.initState();
    _layout = layoutWorkflowGraph(widget.structure);
    widget.controller.addListener(_onControllerChanged);
    widget.statusSource?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(AgUiWorkflowGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.statusSource != widget.statusSource) {
      oldWidget.statusSource?.removeListener(_onControllerChanged);
      widget.statusSource?.addListener(_onControllerChanged);
    }
    if (oldWidget.structure != widget.structure) {
      _layout = layoutWorkflowGraph(widget.structure);
      _didInitialFocus = false;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.statusSource?.removeListener(_onControllerChanged);
    _view.dispose();
    _flow.dispose();
    _blink.dispose();
    _followAnim?.dispose();
    super.dispose();
  }

  Map<String, WorkflowStepStatus> get _stepStatuses => widget.statusSource?.nodeStatuses ?? widget.controller.stepStatuses;

  String _truncate(String text) =>
      text.length > _labelMax ? '${text.substring(0, _labelMax - 1)}…' : text;

  /// The node the camera should be looking at: whichever is currently working (or, failing
  /// that, waiting on the user) — or, once it's done and nothing new has started yet, wherever
  /// that last one was, so the view holds steady between two steps instead of snapping back to
  /// the start. Before anything has run at all, that's the entry node.
  String? _activeNodeId() {
    final statuses = _stepStatuses;
    String? working;
    String? waiting;
    for (final n in widget.structure.nodes) {
      final s = statuses[n.id];
      if (s == WorkflowStepStatus.working) {
        working = n.id;
        break;
      }
      if (s == WorkflowStepStatus.waiting) waiting ??= n.id;
    }
    final found = working ?? waiting;
    if (found != null) _lastActive = found;
    return found ??
        _lastActive ??
        widget.structure.entryNodeId ??
        (widget.structure.nodes.isNotEmpty
            ? widget.structure.nodes.first.id
            : null);
  }

  void _onControllerChanged() {
    final working = _stepStatuses.containsValue(
      WorkflowStepStatus.working,
    );
    if (working && !_flow.isAnimating) {
      _flow.repeat();
      _blink.repeat(reverse: true);
    } else if (!working && _flow.isAnimating) {
      _flow
        ..stop()
        ..value = 0;
      _blink
        ..stop()
        ..value = 0;
    }
    final active = _activeNodeId();
    if (_following && active != null && active != _seenActive) {
      _seenActive = active;
      _focusOn(active, animate: true);
    }
    setState(() {});
  }

  double _focusScale() =>
      _layout.width > 0
          ? (_layout.width / _focusSpan).clamp(_minScale, _maxScale)
          : 1.0;

  Matrix4 _matrixFor(Offset point, double scale) {
    final tx = _viewportSize.width / 2 - point.dx * scale;
    final ty = _viewportSize.height / 2 - point.dy * scale;
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _focusOn(String nodeId, {required bool animate}) {
    final at = _layout.positions[nodeId];
    if (at == null || _viewportSize == Size.zero) return;
    final target = _matrixFor(at, _focusScale());
    if (!animate) {
      _view.value = target;
      return;
    }
    _followAnim?.dispose();
    final begin = _view.value.clone();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    final curved = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    curved.addListener(() {
      _view.value = _lerpMatrix(begin, target, curved.value);
    });
    _followAnim = controller;
    controller.forward();
  }

  static Matrix4 _lerpMatrix(Matrix4 a, Matrix4 b, double t) {
    final sa = a.getMaxScaleOnAxis();
    final sb = b.getMaxScaleOnAxis();
    final s = sa + (sb - sa) * t;
    final ta = Offset(a.storage[12], a.storage[13]);
    final tb = Offset(b.storage[12], b.storage[13]);
    final tr = Offset.lerp(ta, tb, t)!;
    return Matrix4.identity()
      ..translateByDouble(tr.dx, tr.dy, 0, 1)
      ..scaleByDouble(s, s, s, 1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, outer) {
        final width = outer.hasBoundedWidth
            ? outer.maxWidth
            : _layout.width + 80;
        final height = outer.hasBoundedHeight
            ? outer.maxHeight
            : _layout.height + 80;
        _viewportSize = Size(width, height);

        if (!_didInitialFocus) {
          _didInitialFocus = true;
          final active = _activeNodeId();
          _seenActive = active;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (active != null && mounted) _focusOn(active, animate: true);
          });
        }

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _view,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  onInteractionStart: (_) => _following = false,
                  child: SizedBox(
                    width: math.max(_layout.width, 1),
                    height: math.max(_layout.height, 1),
                    child: ListenableBuilder(
                      listenable: Listenable.merge([widget.controller, if (widget.statusSource != null) widget.statusSource!, _flow, _blink]),
                      builder: (context, _) {
                        final statuses = _stepStatuses;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _EdgePainter(
                                  structure: widget.structure,
                                  layout: _layout,
                                  statuses: statuses,
                                  palette: widget.palette,
                                  flow: _flow.value,
                                  mutedColor: scheme.outline,
                                  bgColor: scheme.surface,
                                ),
                              ),
                            ),
                            for (final n in widget.structure.nodes)
                              if (_layout.positions[n.id] case final at?)
                                _node(context, scheme, n, at, statuses[n.id]),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: _RecenterButton(
                  onPressed: () {
                    _following = true;
                    final active = _activeNodeId();
                    if (active != null) _focusOn(active, animate: true);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _node(
    BuildContext context,
    ColorScheme scheme,
    WorkflowGraphNode n,
    Offset at,
    WorkflowStepStatus? status,
  ) {
    final idle = status == null;
    final kindColor = widget.palette.kindColor(n.kind);
    final ringColor = idle ? null : widget.palette.statusColor(status);
    const size = _nodeRadius * 2;
    return Positioned(
      left: at.dx - size / 2 - 10,
      top: at.dy - size / 2,
      width: size + 20,
      child: Tooltip(
        message: '${n.displayName} — ${workflowStepStatusText(status)}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: idle
                  ? 0.62
                  : (status == WorkflowStepStatus.working ? 1 - 0.45 * _blink.value : 1),
              child: SizedBox(
                width: size + 8,
                height: size + 8,
                child: CustomPaint(
                  painter: _NodeCirclePainter(
                    fill: scheme.surfaceContainerLow,
                    border: kindColor,
                    ring: ringColor,
                  ),
                  child: Center(
                    child: Icon(_kindIcon(n.kind), size: size * 0.55, color: kindColor),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _truncate(n.displayName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Recenter on the active step',
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(Icons.center_focus_strong, size: 18, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _NodeCirclePainter extends CustomPainter {
  const _NodeCirclePainter({required this.fill, required this.border, this.ring});
  final Color fill;
  final Color border;
  final Color? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 5;
    canvas.drawCircle(center, radius, Paint()..color = fill);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = border,
    );
    if (ring != null) {
      canvas.drawCircle(
        center,
        radius + 3.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = ring!,
      );
    }
  }

  @override
  bool shouldRepaint(_NodeCirclePainter old) =>
      old.fill != fill || old.border != border || old.ring != ring;
}

/// Draws the diagram's connectors: faint and dotted until the run reaches their source node,
/// solid once done, animated (a moving dash) while their source node is actively running — same
/// idea as `_BranchPainter` in `team_views.dart`. A branch condition's label (e.g. "Yes"/"No")
/// is drawn at the curve's midpoint, clear of the link itself.
class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.structure,
    required this.layout,
    required this.statuses,
    required this.palette,
    required this.flow,
    required this.mutedColor,
    required this.bgColor,
  });

  final WorkflowGraphStructure structure;
  final WorkflowLayout layout;
  final Map<String, WorkflowStepStatus> statuses;
  final AgUiWorkflowPalette palette;
  final double flow;
  final Color mutedColor;
  final Color bgColor;

  static void _dashed(Canvas canvas, Path path, Paint paint, double dash, double gap, double flow) {
    for (final metric in path.computeMetrics()) {
      var travelled = -flow * (dash + gap) * 2;
      while (travelled < metric.length) {
        final start = math.max(travelled, 0.0);
        final end = math.min(travelled + dash, metric.length);
        if (end > start) canvas.drawPath(metric.extractPath(start, end), paint);
        travelled += dash + gap;
      }
    }
  }

  void _label(Canvas canvas, Offset a, Offset b, String text, bool loop) {
    final mx = (a.dx + b.dx) / 2;
    final my = loop ? math.max(a.dy, b.dy) + 54 : (a.dy + b.dy) / 2;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: mutedColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = painter.width + 14;
    const h = 18.0;
    final rect = Rect.fromCenter(center: Offset(mx, my), width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(9));
    canvas.drawRRect(rrect, Paint()..color = bgColor);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = mutedColor,
    );
    painter.paint(canvas, Offset(mx - painter.width / 2, my - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in structure.edges) {
      final a = layout.positions[e.from];
      final b = layout.positions[e.to];
      if (a == null || b == null) continue;
      final isBack = layout.backEdges.contains(edgeKey(e.from, e.to));
      final from = Offset(a.dx + _nodeRadius, a.dy);
      final to = Offset(b.dx - _nodeRadius, b.dy);
      final path = isBack ? loopCurve(a, b) : flowCurve(from, to);

      final sFrom = statuses[e.from];
      final sTo = statuses[e.to];
      final status =
          (sFrom == WorkflowStepStatus.done || sFrom == WorkflowStepStatus.waiting)
              ? sTo
              : (sFrom == WorkflowStepStatus.working ? WorkflowStepStatus.working : null);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      switch (status) {
        case WorkflowStepStatus.working:
          paint
            ..color = palette.working
            ..strokeWidth = 2.4;
          _dashed(canvas, path, paint, 6, 4, flow);
        case WorkflowStepStatus.failed:
          paint
            ..color = palette.failed
            ..strokeWidth = 2;
          canvas.drawPath(path, paint);
        case WorkflowStepStatus.done:
        case WorkflowStepStatus.waiting:
          paint
            ..color = palette.done
            ..strokeWidth = 2;
          canvas.drawPath(path, paint);
        case null:
          paint
            ..color = mutedColor.withValues(alpha: 0.8)
            ..strokeWidth = 1.5;
          _dashed(canvas, path, paint, 1.5, 4, 0);
      }

      if (e.label != null) _label(canvas, from, to, e.label!, isBack);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.statuses != statuses || old.flow != flow || old.layout != layout;
}
