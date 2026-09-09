import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';

/// Date or date-range picker widget.
///
/// Agent props:
/// ```json
/// {
///   "title": "Planification",
///   "question": "Quelle date vous convient pour la livraison ?",
///   "mode": "single",
///   "submitLabel": "Confirmer"
/// }
/// ```
/// [mode] can be `"single"` (default) or `"range"`.
/// The selectable window defaults to today ± a few years — LLMs don't reliably know the
/// current date, so no min/max bounds are accepted from the agent (optional `minDate`/
/// `maxDate` ISO strings are still honoured if a trusted caller provides them).
/// Calls `props['__onSubmit']` with e.g. `"Date : 15 mars 2025"` or
/// `"Période : 10 mars 2025 → 20 mars 2025"`.
class AgDatePickerCard extends StatefulWidget {
  const AgDatePickerCard({super.key, required this.props});
  final Map<String, dynamic> props;
  @override
  State<AgDatePickerCard> createState() => _AgDatePickerCardState();
}

class _AgDatePickerCardState extends State<AgDatePickerCard> {
  DateTime? _start;
  DateTime? _end;
  bool _submitted = false;

  DateTime? _parseDate(String? s) {
    if (s == null) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }

  static const _months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// Clamps [date] inside [min, max] — the agent may send stale or inconsistent
  /// minDate/maxDate bounds, and showDatePicker asserts (silently killing the dialog)
  /// when initialDate falls outside [firstDate, lastDate].
  static DateTime _clamp(DateTime date, DateTime min, DateTime max) =>
      date.isBefore(min) ? min : (date.isAfter(max) ? max : date);

  Future<void> _pickDate() async {
    final mode = widget.props['mode'] as String? ?? 'single';
    final now = DateTime.now();
    var minDate = _parseDate(widget.props['minDate'] as String?) ?? DateTime(now.year - 2);
    var maxDate = _parseDate(widget.props['maxDate'] as String?) ?? DateTime(now.year + 3);
    if (maxDate.isBefore(minDate)) (minDate, maxDate) = (maxDate, minDate);

    if (mode == 'range') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: minDate,
        lastDate: maxDate,
        initialDateRange: (_start != null && _end != null)
            ? DateTimeRange(start: _clamp(_start!, minDate, maxDate), end: _clamp(_end!, minDate, maxDate))
            : null,
      );
      if (picked != null) setState(() { _start = picked.start; _end = picked.end; });
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: _clamp(_start ?? DateTime.now(), minDate, maxDate),
        firstDate: minDate,
        lastDate: maxDate,
      );
      if (picked != null) setState(() { _start = picked; _end = null; });
    }
  }

  void _submit() {
    final onSubmit = widget.props['__onSubmit'] as Function?;
    if (onSubmit == null || _submitted || _start == null) return;
    final mode = widget.props['mode'] as String? ?? 'single';
    final response = mode == 'range' && _end != null
        ? 'Période : ${_fmt(_start!)} → ${_fmt(_end!)}'
        : 'Date : ${_fmt(_start!)}';
    setState(() => _submitted = true);
    onSubmit(response);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.props['title'] as String? ?? 'Date';
    final question = widget.props['question'] as String?;
    final mode = widget.props['mode'] as String? ?? 'single';
    final submitLabel = widget.props['submitLabel'] as String? ?? 'Confirmer';

    String selectionText = mode == 'range' ? 'Sélectionner une période' : 'Sélectionner une date';
    if (_start != null) {
      selectionText = mode == 'range' && _end != null
          ? '${_fmt(_start!)} → ${_fmt(_end!)}'
          : _fmt(_start!);
    }

    return AgArtifactCard(
      title: title,
      icon: Icons.calendar_today_rounded,
      type: mode == 'range' ? 'Période' : 'Date',
      // Disabled/answered visual state is owned by the chat panel's message
      // bubble (_MessageBubble._dimIfDisabled), not here — see ag_choice_card.dart's
      // matching comment for why a second local dimming layer used to make
      // the picked date look erased.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (question != null) ...[
            Text(question, style: TextStyle(fontSize: 13, color: cs.onSurface)),
            const SizedBox(height: 12),
          ],
          GestureDetector(
            onTap: _submitted ? null : _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _start != null ? cs.primary : cs.outlineVariant,
                  width: _start != null ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18,
                      color: _start != null ? cs.primary : cs.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectionText,
                      style: TextStyle(
                        fontSize: 13,
                        color: _start != null ? cs.onSurface : cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  if (!_submitted)
                    Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (_submitted || _start == null) ? null : _submit,
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
