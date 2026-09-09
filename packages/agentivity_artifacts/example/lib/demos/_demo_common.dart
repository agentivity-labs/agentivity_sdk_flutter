import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

/// One logical block that the agent "streams" into view.
class DemoSection {
  final String? label;
  final Widget child;

  /// Milliseconds to wait *after the previous section appears* before showing
  /// this one. Simulates the agent producing content incrementally.
  final int delayMs;

  const DemoSection({
    this.label,
    required this.child,
    this.delayMs = 800,
  });
}

// ---------------------------------------------------------------------------
// StreamingDemoPage
// ---------------------------------------------------------------------------

/// Scaffold that reveals [sections] one by one with a streaming animation,
/// simulating a real agent generating artifact widgets in sequence.
///
/// The theme is inherited from the widget tree — the showcase shell applies
/// a [Theme] wrapper before building this page.
///
/// A replay button appears in the AppBar once streaming finishes.
class StreamingDemoPage extends StatefulWidget {
  const StreamingDemoPage({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<DemoSection> sections;

  @override
  State<StreamingDemoPage> createState() => _StreamingDemoPageState();
}

class _StreamingDemoPageState extends State<StreamingDemoPage> {
  int _visible = 0;
  bool _streaming = false;
  int _replayCount = 0;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  Future<void> _startStream() async {
    if (!mounted) return;
    setState(() {
      _streaming = true;
      _visible = 0;
    });
    for (var i = 0; i < widget.sections.length; i++) {
      await Future.delayed(Duration(milliseconds: widget.sections[i].delayMs));
      if (!mounted) return;
      setState(() => _visible = i + 1);
    }
    if (!mounted) return;
    setState(() => _streaming = false);
  }

  void _replay() {
    setState(() => _replayCount++);
    _startStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: false,
          actions: [
            if (!_streaming)
              IconButton(
                icon: const Icon(Icons.replay_rounded),
                tooltip: 'Replay',
                onPressed: _replay,
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AgentStatusBar(streaming: _streaming),
            for (var i = 0; i < _visible; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              _FadeSlideSection(
                key: ValueKey('s-$i-$_replayCount'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.sections[i].label != null) ...[
                      DemoSectionLabel(widget.sections[i].label!),
                      const SizedBox(height: 8),
                    ],
                    widget.sections[i].child,
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AgentStatusBar
// ---------------------------------------------------------------------------

class _AgentStatusBar extends StatefulWidget {
  const _AgentStatusBar({required this.streaming});
  final bool streaming;

  @override
  State<_AgentStatusBar> createState() => _AgentStatusBarState();
}

class _AgentStatusBarState extends State<_AgentStatusBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(
            alpha: widget.streaming ? 0.35 : 0.18,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.streaming)
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color:
                      color.withValues(alpha: 0.35 + 0.65 * _pulse.value),
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: color.withValues(alpha: 0.75),
            ),
          const SizedBox(width: 8),
          Text(
            widget.streaming ? 'Agent generating…' : 'Response complete',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          if (!widget.streaming) ...[
            const Spacer(),
            Text(
              'tap ↺ to replay',
              style: TextStyle(
                fontSize: 10,
                color: cs.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FadeSlideSection
// ---------------------------------------------------------------------------

/// Fades + slides a widget in from slightly below when first built.
/// Using a unique [key] tied to the replay count re-triggers the animation.
class _FadeSlideSection extends StatefulWidget {
  const _FadeSlideSection({super.key, required this.child});
  final Widget child;

  @override
  State<_FadeSlideSection> createState() => _FadeSlideSectionState();
}

class _FadeSlideSectionState extends State<_FadeSlideSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DemoSectionLabel
// ---------------------------------------------------------------------------

/// Small all-caps label used as a section heading inside demos.
class DemoSectionLabel extends StatelessWidget {
  const DemoSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
