import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';
import '../theme/ag_artifacts_theme.dart';

/// Star or scale rating widget.
///
/// Agent props:
/// ```json
/// {
///   "title": "Satisfaction",
///   "question": "Comment évaluez-vous notre service ?",
///   "mode": "stars",
///   "max": 5,
///   "labels": ["Très mauvais", "Mauvais", "Correct", "Bien", "Excellent"]
/// }
/// ```
/// [mode] can be `"stars"` (default) or `"scale"` (numbered buttons).
/// Calls `props['__onSubmit']` with e.g. `"Note : 4/5 — Bien"`.
class AgRatingCard extends StatefulWidget {
  const AgRatingCard({super.key, required this.props});
  final Map<String, dynamic> props;
  @override
  State<AgRatingCard> createState() => _AgRatingCardState();
}

class _AgRatingCardState extends State<AgRatingCard> {
  int? _selected;
  bool _submitted = false;

  void _pick(int value) {
    if (_submitted) return;
    setState(() => _selected = value);
  }

  void _submit() {
    final onSubmit = widget.props['__onSubmit'] as Function?;
    if (onSubmit == null || _submitted || _selected == null) return;
    final max = widget.props['max'] as int? ?? 5;
    final labels =
        (widget.props['labels'] as List?)?.map((e) => e.toString()).toList();
    final label =
        (labels != null && _selected! - 1 < labels.length)
            ? ' — ${labels[_selected! - 1]}'
            : '';
    setState(() => _submitted = true);
    onSubmit('Note : $_selected/$max$label');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // A button's own Text label doesn't inherit AgArtifactCard's DefaultTextStyle.merge — see
    // ag_choice_card.dart's identical note.
    final fontFamily = AgArtifactsThemeData.of(context).fontFamily;
    final title = widget.props['title'] as String? ?? 'Évaluation';
    final question = widget.props['question'] as String?;
    final mode = widget.props['mode'] as String? ?? 'stars';
    final max = widget.props['max'] as int? ?? 5;
    final labels =
        (widget.props['labels'] as List?)?.map((e) => e.toString()).toList();
    final submitLabel = widget.props['submitLabel'] as String? ?? 'Envoyer';

    return AgArtifactCard(
      title: title,
      icon: Icons.star_outline_rounded,
      type: 'Rating',
      // Disabled/answered visual state is owned by the chat panel's message
      // bubble (_MessageBubble._dimIfDisabled), not here — see ag_choice_card.dart's
      // matching comment for why a second local dimming layer used to make
      // the picked rating look erased.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (question != null) ...[
            Text(question, style: TextStyle(fontSize: 13, color: cs.onSurface)),
            const SizedBox(height: 14),
          ],
          if (mode == 'stars')
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(max, (i) {
                final val = i + 1;
                final active = _selected != null && val <= _selected!;
                return GestureDetector(
                  onTap: () => _pick(val),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      active ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 32,
                      color:
                          active
                              ? const Color(0xFFf59e0b)
                              : cs.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                );
              }),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(max, (i) {
                final val = i + 1;
                final active = _selected == val;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => _pick(val),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: active ? cs.primary : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: active ? cs.primary : cs.outlineVariant,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$val',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: active ? cs.onPrimary : cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          if (_selected != null &&
              labels != null &&
              _selected! - 1 < labels.length) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                labels[_selected! - 1],
                style: TextStyle(
                  fontSize: 12,
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: (_submitted || _selected == null) ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              submitLabel,
              style: TextStyle(fontFamily: fontFamily, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
