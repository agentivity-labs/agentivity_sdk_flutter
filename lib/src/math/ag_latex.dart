import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../shell/ag_artifact_card.dart';

/// LaTeX math rendering via flutter_math_fork.
///
/// Agent props:
/// ```json
/// {
///   "title": "Euler's identity",
///   "tex": "e^{i\\pi} + 1 = 0",
///   "display": true
/// }
/// ```
/// [display] — true renders as a display block (centred, larger);
///             false renders inline-style (default: true).
///
/// Supports full KaTeX-compatible LaTeX syntax.
class AgLatex extends StatelessWidget {
  const AgLatex({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = props['title'] as String? ?? 'Math';
    final tex = props['tex']?.toString() ?? r'\text{(no expression)}';
    final display = props['display'] as bool? ?? true;

    return AgArtifactCard(
      title: title,
      type: 'LaTeX',
      icon: Icons.functions_rounded,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Math.tex(
              tex,
              mathStyle: display ? MathStyle.display : MathStyle.text,
              textStyle: TextStyle(
                fontSize: display ? 20 : 16,
                color: cs.onSurface,
              ),
              onErrorFallback: (e) => Text(
                'LaTeX error: ${e.message}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFef4444),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
