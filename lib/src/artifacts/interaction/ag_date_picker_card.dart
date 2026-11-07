import 'package:flutter/material.dart';

import '../shared/ag_calendar.dart';
import '../shell/ag_artifact_card.dart';
import '../theme/ag_artifacts_theme.dart';

/// Date or date-range picker widget.
///
/// Agent props:
/// ```json
/// {
///   "title": "Planification",
///   "question": "Quelle date vous convient pour la livraison ?",
///   "mode": "single",
///   "submitLabel": "Confirm"
/// }
/// ```
/// [mode] can be `"single"` (default) or `"range"`.
/// The selectable window defaults to today ± a few years — LLMs don't reliably know the
/// current date, so no min/max bounds are accepted from the agent (optional `minDate`/
/// `maxDate` ISO strings are still honoured if a trusted caller provides them).
/// Calls `props['__onSubmit']` with e.g. `"Date: 15 Mar 2025"` or
/// `"Period: 10 Mar 2025 → 20 Mar 2025"`.
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
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  (DateTime, DateTime) _window() {
    final now = DateTime.now();
    var minDate = _parseDate(widget.props['minDate'] as String?) ?? DateTime(now.year - 2);
    var maxDate = _parseDate(widget.props['maxDate'] as String?) ?? DateTime(now.year + 3);
    // The agent may send its bounds the wrong way round.
    if (maxDate.isBefore(minDate)) (minDate, maxDate) = (maxDate, minDate);
    return (minDate, maxDate);
  }

  void _submit() {
    final onSubmit = widget.props['__onSubmit'] as Function?;
    if (onSubmit == null || _submitted || _start == null) return;
    final mode = widget.props['mode'] as String? ?? 'single';
    final response =
        mode == 'range' && _end != null
            ? 'Period: ${_fmt(_start!)} → ${_fmt(_end!)}'
            : 'Date: ${_fmt(_start!)}';
    setState(() => _submitted = true);
    onSubmit(response);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // A button's own Text label doesn't inherit AgArtifactCard's DefaultTextStyle.merge — see
    // ag_choice_card.dart's identical note.
    final fontFamily = AgArtifactsThemeData.of(context).fontFamily;
    final title = widget.props['title'] as String? ?? 'Date';
    final question = widget.props['question'] as String?;
    final mode = widget.props['mode'] as String? ?? 'single';
    final submitLabel = widget.props['submitLabel'] as String? ?? 'Confirm';

    String selectionText =
        mode == 'range' ? 'Choose the first day, then the last' : 'Choose a day';
    if (_start != null) {
      selectionText =
          mode == 'range' && _end != null
              ? '${_fmt(_start!)} → ${_fmt(_end!)}'
              : mode == 'range' ? '${_fmt(_start!)} → choose the last day' : _fmt(_start!);
    }

    return AgArtifactCard(
      title: title,
      icon: Icons.calendar_today_rounded,
      type: mode == 'range' ? 'Period' : 'Date',
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
          // The calendar of Agentivity, in the card: a tap chooses the day (a period: its first day, then its last).
          Builder(builder: (context) {
            final (minDate, maxDate) = _window();
            return AgCalendar(
              value: _start,
              rangeMode: mode == 'range',
              rangeStart: _start,
              rangeEnd: _end,
              firstDate: minDate,
              lastDate: maxDate,
              enabled: !_submitted,
              onChanged: (d) => setState(() {
                _start = d;
                _end = null;
              }),
              onRangeChanged: (start, end) => setState(() {
                _start = start;
                _end = end;
              }),
            );
          }),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.event_available_rounded, size: 16, color: _start != null ? cs.primary : cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectionText,
                  style: TextStyle(fontSize: 13, fontWeight: _start != null ? FontWeight.w600 : FontWeight.w400, color: _start != null ? cs.onSurface : cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (_submitted || _start == null || mode == 'range' && _end == null) ? null : _submit,
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
