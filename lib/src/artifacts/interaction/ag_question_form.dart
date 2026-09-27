import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shell/ag_artifact_card.dart';
import '../theme/ag_artifacts_theme.dart';

/// Multi-question form widget.
///
/// Agent props:
/// ```json
/// {
///   "title": "A few questions",
///   "questions": [
///     {"id": "dest", "label": "Destination", "hint": "e.g. Barcelona"},
///     {"id": "start", "label": "Departure date", "type": "date"},
///     {"id": "travelers", "label": "Travelers", "type": "number"},
///     {"id": "car", "label": "Need a rental car?", "type": "boolean"},
///     {"id": "budget", "label": "Budget", "hint": "e.g. 1500", "required": false}
///   ],
///   "submitLabel": "Send"
/// }
/// ```
///
/// `type` is `'text'` (default), `'date'` (a native date picker — always use this for a question about
/// a date, never a free-text field), `'number'`, or `'boolean'` (Yes/No).
///
/// When submitted, calls `props['__onSubmit']` with a structured text response — a boolean answer reads
/// as "Yes"/"No", a date answer as its ISO date (`2027-07-01`):
/// ```
/// • Destination → Barcelona
/// • Departure date → 2027-07-01
/// • Travelers → 2
/// • Need a rental car? → No
/// ```
class AgQuestionForm extends StatefulWidget {
  const AgQuestionForm({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  State<AgQuestionForm> createState() => _AgQuestionFormState();
}

enum _QuestionType { text, date, number, boolean }

_QuestionType _typeOf(Map<String, dynamic> q) => switch (q['type']) {
  'date' => _QuestionType.date,
  'number' => _QuestionType.number,
  'boolean' => _QuestionType.boolean,
  _ =>
    _QuestionType
        .text, // covers 'text' and anything an older/unknown SDK might send.
};

class _AgQuestionFormState extends State<AgQuestionForm> {
  late final List<Map<String, dynamic>> _questions;
  late final List<_QuestionType> _types;
  late final List<TextEditingController> _controllers;
  // Canonical answer per question — what is actually submitted. For text/number it mirrors the
  // controller; for date it is the ISO date the controller only displays formatted; for boolean
  // there is no controller at all.
  late final List<String?> _answers;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final raw = widget.props['questions'];
    _questions =
        raw is List
            ? raw
                .map(
                  (e) =>
                      e is Map
                          ? Map<String, dynamic>.from(e)
                          : <String, dynamic>{},
                )
                .toList()
            : <Map<String, dynamic>>[];
    _types = _questions.map(_typeOf).toList();
    _controllers = List.generate(
      _questions.length,
      (_) => TextEditingController(),
    );
    _answers = List.generate(_questions.length, (_) => null);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(int i) async {
    if (_submitted) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      _answers[i] = iso;
      _controllers[i].text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    });
  }

  void _submit() {
    final onSubmit = widget.props['__onSubmit'] as Function?;
    if (onSubmit == null || _submitted) return;

    final lines = <String>[];
    for (var i = 0; i < _questions.length; i++) {
      final label = _questions[i]['label'] as String? ?? 'Q${i + 1}';
      final answer = (_answers[i] ?? _controllers[i].text).trim();
      if (answer.isNotEmpty) {
        lines.add('• $label → $answer');
      }
    }

    if (lines.isEmpty) return;

    setState(() => _submitted = true);
    onSubmit(lines.join('\n'));
  }

  InputDecoration _decoration(
    ColorScheme cs, {
    String? hint,
    Widget? suffixIcon,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 12,
      color: cs.onSurface.withValues(alpha: 0.4),
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    suffixIcon: suffixIcon,
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
  );

  // TextField resolves its own rendered style straight from Theme.of(context) — unlike a plain
  // Text, it does NOT merge with an ancestor DefaultTextStyle, so AgArtifactCard's
  // DefaultTextStyle.merge(fontFamily: ...) never reaches it (confirmed: a themed fontFamily
  // rendered every Text in this form correctly but left every TextField at the Material default,
  // Roboto, regardless of theme). Every TextField below must set fontFamily explicitly.
  Widget _field(
    ColorScheme cs,
    String? fontFamily,
    int i,
    String? hint,
    bool isLast,
  ) {
    switch (_types[i]) {
      case _QuestionType.boolean:
        Widget option(String label) {
          final selected = _answers[i] == label;
          return Expanded(
            child: OutlinedButton(
              onPressed:
                  _submitted ? null : () => setState(() => _answers[i] = label),
              style: OutlinedButton.styleFrom(
                backgroundColor: selected ? cs.primary : null,
                foregroundColor: selected ? cs.onPrimary : cs.onSurface,
                side: BorderSide(
                  color: selected ? cs.primary : cs.outlineVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                minimumSize: const Size.fromHeight(34),
              ),
              child: Text(
                label,
                style: TextStyle(fontFamily: fontFamily, fontSize: 13),
              ),
            ),
          );
        }

        return Row(
          children: [option('Yes'), const SizedBox(width: 8), option('No')],
        );

      case _QuestionType.date:
        return TextField(
          controller: _controllers[i],
          enabled: !_submitted,
          readOnly: true,
          onTap: () => _pickDate(i),
          decoration: _decoration(
            cs,
            hint: hint ?? 'Select a date',
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
          ),
          style: TextStyle(fontFamily: fontFamily, fontSize: 13),
        );

      case _QuestionType.number:
        return TextField(
          controller: _controllers[i],
          enabled: !_submitted,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: _decoration(cs, hint: hint),
          style: TextStyle(fontFamily: fontFamily, fontSize: 13),
          onChanged: (v) => _answers[i] = v,
          onSubmitted: (_) {
            if (isLast) _submit();
          },
        );

      case _QuestionType.text:
        return TextField(
          controller: _controllers[i],
          enabled: !_submitted,
          decoration: _decoration(cs, hint: hint),
          style: TextStyle(fontFamily: fontFamily, fontSize: 13),
          onChanged: (v) => _answers[i] = v,
          onSubmitted: (_) {
            if (isLast) _submit();
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fontFamily = AgArtifactsThemeData.of(context).fontFamily;
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
                  _field(cs, fontFamily, i, hint, i == _questions.length - 1),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: _submitted ? null : _submit,
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
