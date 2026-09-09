import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';

/// Multi-question form widget.
///
/// Agent props:
/// ```json
/// {
///   "title": "Quelques questions",
///   "questions": [
///     {"id": "type", "label": "S'agit-il d'un achat pro ou perso ?", "hint": "Ex: Personnel"},
///     {"id": "budget", "label": "Quel est votre budget ?", "hint": "Ex: 1500€", "required": false}
///   ],
///   "submitLabel": "Envoyer"
/// }
/// ```
///
/// When submitted, calls `props['__onSubmit']` with a structured text response:
/// ```
/// • S'agit-il d'un achat pro ou perso ? → Personnel, gaming
/// • Quel est votre budget ? → 1500€
/// ```
class AgQuestionForm extends StatefulWidget {
  const AgQuestionForm({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  State<AgQuestionForm> createState() => _AgQuestionFormState();
}

class _AgQuestionFormState extends State<AgQuestionForm> {
  late final List<Map<String, dynamic>> _questions;
  late final List<TextEditingController> _controllers;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final raw = widget.props['questions'];
    _questions = raw is List
        ? raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList()
        : <Map<String, dynamic>>[];
    _controllers = List.generate(_questions.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final onSubmit = widget.props['__onSubmit'] as Function?;
    if (onSubmit == null || _submitted) return;

    final lines = <String>[];
    for (var i = 0; i < _questions.length; i++) {
      final label = _questions[i]['label'] as String? ?? 'Q${i + 1}';
      final answer = _controllers[i].text.trim();
      if (answer.isNotEmpty) {
        lines.add('• $label → $answer');
      }
    }

    if (lines.isEmpty) return;

    setState(() => _submitted = true);
    onSubmit(lines.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.props['title'] as String? ?? 'Questions';
    final submitLabel = widget.props['submitLabel'] as String? ?? 'Envoyer';

    // Disabled/answered visual state is owned by the chat panel's message
    // bubble (_MessageBubble._dimIfDisabled), not here — this widget only
    // guards against a second submit while the parent's rebuild is in
    // flight (TextField.enabled / button onPressed below), with no opacity
    // or IgnorePointer of its own. Two independent dimming layers used to
    // stack (this one plus the panel's), rendering the submitted answer at
    // ~10% effective opacity — close enough to invisible to look like the
    // typed text had been erased.
    return AgArtifactCard(
      title: title,
      icon: Icons.help_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._questions.asMap().entries.map((entry) {
            final i = entry.key;
            final q = entry.value;
            final label = q['label'] as String? ?? 'Question ${i + 1}';
            final hint = q['hint'] as String?;
            final required = q['required'] as bool? ?? true;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (!required)
                        Text(
                          'Optionnel',
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _controllers[i],
                    enabled: !_submitted,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: cs.primary, width: 1.5),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) {
                      if (i == _questions.length - 1) _submit();
                    },
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: _submitted ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text(submitLabel, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
