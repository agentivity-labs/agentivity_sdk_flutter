import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The words of [AgUiWaitNotice], for an app to say them its way (its language, its tone). Nothing in them speaks of a server or
/// a workspace: the person only waits a moment.
class AgUiWaitTexts {
  const AgUiWaitTexts({
    this.title = 'Just a moment…',
    this.detail = 'Getting things ready.',
    this.later = 'Almost there…',
    this.long = 'Taking a bit longer than usual.',
    this.retry = 'Try again',
    this.laterAfter = const Duration(seconds: 15),
    this.longAfter = const Duration(seconds: 60),
  });

  final String title;
  final String detail;

  /// Said from [laterAfter] on.
  final String later;

  /// Said from [longAfter] on, with [retry] when the app gives a way to try again.
  final String long;
  final String retry;

  final Duration laterAfter;
  final Duration longAfter;
}

/// "Just a moment… Getting things ready." while a call waits for its answer (`client.waiting`): the first calls to a hosted
/// workspace that wakes up take most of a minute. No countdown (the wait is not known), a ring that turns, and words that change
/// if it lasts. Nothing shows while nothing waits.
class AgUiWaitNotice extends StatefulWidget {
  const AgUiWaitNotice({super.key, required this.waiting, this.texts = const AgUiWaitTexts(), this.onRetry});

  /// Since when a call waits, or null: `client.waiting`.
  final ValueListenable<DateTime?> waiting;

  final AgUiWaitTexts texts;

  /// Shown after [AgUiWaitTexts.longAfter] when given: what trying again means is the app's.
  final VoidCallback? onRetry;

  @override
  State<AgUiWaitNotice> createState() => _AgUiWaitNoticeState();
}

class _AgUiWaitNoticeState extends State<AgUiWaitNotice> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    widget.waiting.addListener(_onChange);
    _sync();
  }

  @override
  void didUpdateWidget(AgUiWaitNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.waiting != widget.waiting) {
      oldWidget.waiting.removeListener(_onChange);
      widget.waiting.addListener(_onChange);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.waiting.removeListener(_onChange);
    _tick?.cancel();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    _sync();
  }

  // The words change with the time waited: looked at again every second while something waits.
  void _sync() {
    if (widget.waiting.value != null) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.waiting.value;
    final texts = widget.texts;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget child = const SizedBox.shrink(key: ValueKey('nothing'));
    if (since != null) {
      final waited = DateTime.now().difference(since);
      final long = waited >= texts.longAfter;
      final detail = long ? texts.long : waited >= texts.laterAfter ? texts.later : texts.detail;
      child = Semantics(
        key: const ValueKey('waiting'),
        liveRegion: true,
        container: true,
        child: Material(
          color: scheme.surface,
          elevation: 3,
          shadowColor: scheme.shadow.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.primary)),
              const SizedBox(width: 14),
              Flexible(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(texts.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(detail, key: ValueKey(detail), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                ]),
              ),
              if (long && widget.onRetry != null) ...[
                const SizedBox(width: 12),
                TextButton(onPressed: widget.onRetry, child: Text(texts.retry)),
              ],
            ]),
          ),
        ),
      );
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: child);
  }
}

/// An app with [AgUiWaitNotice] floating at the top while a call waits, over everything, without stopping anyone from reading or
/// typing: wrap the app (or a screen) once.
class AgUiWaitOverlay extends StatelessWidget {
  const AgUiWaitOverlay({super.key, required this.waiting, required this.child, this.texts = const AgUiWaitTexts(), this.onRetry, this.alignment = Alignment.topCenter});

  final ValueListenable<DateTime?> waiting;
  final Widget child;
  final AgUiWaitTexts texts;
  final VoidCallback? onRetry;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Stack(children: [
        child,
        Positioned.fill(
          child: SafeArea(
            child: Align(
              alignment: alignment,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: AgUiWaitNotice(waiting: waiting, texts: texts, onRetry: onRetry)),
              ),
            ),
          ),
        ),
      ]);
}
