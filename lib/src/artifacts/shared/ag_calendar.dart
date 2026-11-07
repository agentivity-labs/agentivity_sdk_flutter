import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The calendar of Agentivity: a month at a time, the weeks from Monday, today ringed, the day chosen filled in the primary colour
/// (a period: its two ends filled and the days between tinted), the days outside the window greyed. The name of the month opens
/// the twelve months and the years, to go far quickly; a few shortcuts (today, tomorrow, next week…) choose in one tap. Inline in
/// a card or a form, or in a dialog ([showAgDatePicker], [showAgDateRangePicker]); the same in the React SDK (`Calendar`).
class AgCalendar extends StatefulWidget {
  const AgCalendar({
    super.key,
    this.value,
    this.rangeStart,
    this.rangeEnd,
    this.rangeMode = false,
    DateTime? firstDate,
    DateTime? lastDate,
    this.onChanged,
    this.onRangeChanged,
    this.shortcuts = true,
    this.enabled = true,
  })  : _firstDate = firstDate,
        _lastDate = lastDate;

  /// The day chosen (one day).
  final DateTime? value;

  /// The period chosen ([rangeMode]): its first day, and its last once chosen.
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final bool rangeMode;
  final DateTime? _firstDate;
  final DateTime? _lastDate;
  final ValueChanged<DateTime>? onChanged;

  /// A period chosen: its end is null until the second day is.
  final void Function(DateTime start, DateTime? end)? onRangeChanged;

  /// Today, tomorrow, next week… above the days.
  final bool shortcuts;
  final bool enabled;

  DateTime get firstDate => _day(_firstDate ?? DateTime(1900));
  DateTime get lastDate => _day(_lastDate ?? DateTime(2200));

  @override
  State<AgCalendar> createState() => _AgCalendarState();
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

bool _same(DateTime? a, DateTime? b) => a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

/// A day said shortly: "Sat 7 Nov 2026".
String agDateText(DateTime d) => '${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1]} ${d.day} ${_monthShort[d.month - 1]} ${d.year}';

/// A day as an ISO date: 2026-11-07.
String agIsoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _AgCalendarState extends State<AgCalendar> {
  late DateTime _month = _startMonth();
  bool _months = false;
  int _direction = 1;
  DateTime? _hovered;

  DateTime _startMonth() {
    final shown = widget.rangeMode ? widget.rangeStart : widget.value;
    final today = _day(DateTime.now());
    final at = shown ?? (today.isBefore(widget.firstDate) ? widget.firstDate : today.isAfter(widget.lastDate) ? widget.lastDate : today);
    return DateTime(at.year, at.month);
  }

  bool _allowed(DateTime d) => !d.isBefore(widget.firstDate) && !d.isAfter(widget.lastDate);

  void _go(int months) {
    final next = DateTime(_month.year, _month.month + months);
    if (DateTime(next.year, next.month + 1).isBefore(DateTime(widget.firstDate.year, widget.firstDate.month + 1)) && months < 0) return;
    if (next.isAfter(widget.lastDate) && months > 0) return;
    setState(() {
      _direction = months.sign;
      _month = next;
    });
  }

  void _choose(DateTime d) {
    if (!widget.enabled || !_allowed(d)) return;
    HapticFeedback.selectionClick();
    if (!widget.rangeMode) {
      widget.onChanged?.call(d);
      return;
    }
    final start = widget.rangeStart;
    // A first day, or a new period once one is whole: it starts here. Otherwise the second day ends it, either way round.
    if (start == null || widget.rangeEnd != null) {
      widget.onRangeChanged?.call(d, null);
    } else if (d.isBefore(start)) {
      widget.onRangeChanged?.call(d, start);
    } else {
      widget.onRangeChanged?.call(start, d);
    }
  }

  List<(String, DateTime?, DateTimeRange?)> _shortcuts() {
    final today = _day(DateTime.now());
    final nextMonday = today.add(Duration(days: 8 - today.weekday));
    if (widget.rangeMode) {
      final monday = today.subtract(Duration(days: today.weekday - 1));
      return [
        ('This week', null, DateTimeRange(start: monday, end: monday.add(const Duration(days: 6)))),
        ('Next 7 days', null, DateTimeRange(start: today, end: today.add(const Duration(days: 6)))),
        ('This month', null, DateTimeRange(start: DateTime(today.year, today.month), end: DateTime(today.year, today.month + 1, 0))),
        ('Next month', null, DateTimeRange(start: DateTime(today.year, today.month + 1), end: DateTime(today.year, today.month + 2, 0))),
      ];
    }
    return [
      ('Today', today, null),
      ('Tomorrow', today.add(const Duration(days: 1)), null),
      ('Next Monday', nextMonday, null),
      ('In a month', DateTime(today.year, today.month + 1, today.day), null),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final shortcuts = widget.shortcuts
        ? _shortcuts().where((s) => s.$2 != null ? _allowed(s.$2!) : _allowed(s.$3!.start) && _allowed(s.$3!.end)).toList()
        : const <(String, DateTime?, DateTimeRange?)>[];
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite ? constraints.maxWidth.clamp(252.0, 400.0) : 308.0;
      final cell = width / 7;
      return SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (shortcuts.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (label, day, range) in shortcuts)
                    _Shortcut(
                      label: label,
                      selected: day != null ? _same(day, widget.value) : _same(range!.start, widget.rangeStart) && _same(range.end, widget.rangeEnd),
                      onTap: !widget.enabled
                          ? null
                          : () {
                              if (day != null) {
                                widget.onChanged?.call(day);
                              } else {
                                widget.onRangeChanged?.call(range!.start, range.end);
                              }
                              setState(() => _month = DateTime((day ?? range!.start).year, (day ?? range!.start).month));
                            },
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _months = !_months),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_monthNames[_month.month - 1], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cs.onSurface)),
                            const SizedBox(width: 6),
                            Text('${_month.year}', style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)),
                            const SizedBox(width: 2),
                            Icon(_months ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: cs.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _Arrow(icon: Icons.chevron_left_rounded, tooltip: _months ? 'Previous year' : 'Previous month', onTap: () => _go(_months ? -12 : -1)),
                const SizedBox(width: 4),
                _Arrow(icon: Icons.chevron_right_rounded, tooltip: _months ? 'Next year' : 'Next month', onTap: () => _go(_months ? 12 : 1)),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(position: Tween(begin: Offset(0.06 * _direction, 0), end: Offset.zero).animate(animation), child: child),
              ),
              child: _months ? _monthGrid(cs, width) : _dayGrid(cs, cell),
            ),
          ],
        ),
      );
    });
  }

  Widget _monthGrid(ColorScheme cs, double width) {
    final today = DateTime.now();
    return SizedBox(
      key: ValueKey('months-${_month.year}'),
      width: width,
      child: Wrap(
        children: [
          for (var m = 1; m <= 12; m++)
            SizedBox(
              width: width / 3,
              height: 48,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _Cell(
                  label: _monthShort[m - 1],
                  selected: _month.month == m,
                  today: today.year == _month.year && today.month == m,
                  enabled: !DateTime(_month.year, m + 1, 0).isBefore(widget.firstDate) && !DateTime(_month.year, m).isAfter(widget.lastDate),
                  onTap: () => setState(() {
                    _month = DateTime(_month.year, m);
                    _months = false;
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayGrid(ColorScheme cs, double cell) {
    final first = DateTime(_month.year, _month.month);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final today = _day(DateTime.now());
    final start = widget.rangeStart;
    // While the last day of a period is not chosen, the period follows the pointer.
    final end = start == null ? null : widget.rangeEnd ?? _hovered ?? start;
    final lo = start == null || end == null ? null : (end.isBefore(start) ? end : start);
    final hi = start == null || end == null ? null : (end.isBefore(start) ? start : end);
    final rows = ((lead + days) / 7).ceil();
    return Column(
      key: ValueKey('days-${_month.year}-${_month.month}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              SizedBox(width: cell, height: 28, child: Center(child: Text(w, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: cs.onSurfaceVariant)))),
          ],
        ),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Builder(builder: (context) {
                  final n = r * 7 + c - lead + 1;
                  if (n < 1 || n > days) return SizedBox(width: cell, height: cell.clamp(34, 44));
                  final d = DateTime(_month.year, _month.month, n);
                  final isEnd = widget.rangeMode ? (_same(d, lo) || _same(d, hi)) : _same(d, widget.value);
                  final inside = widget.rangeMode && lo != null && hi != null && d.isAfter(lo) && d.isBefore(hi);
                  return MouseRegion(
                    onEnter: (_) => widget.rangeMode ? setState(() => _hovered = d) : null,
                    child: SizedBox(
                      width: cell,
                      height: cell.clamp(34, 44),
                      child: Stack(
                        children: [
                          // The band of a period, under its days: from the middle of its first day to the middle of its last.
                          if (widget.rangeMode && lo != null && hi != null && !_same(lo, hi) && (inside || isEnd))
                            Positioned.fill(
                              top: 3,
                              bottom: 3,
                              left: _same(d, lo) ? cell / 2 : 0,
                              right: _same(d, hi) ? cell / 2 : 0,
                              child: ColoredBox(color: cs.primary.withValues(alpha: 0.12)),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(3),
                            child: _Cell(
                              label: '$n',
                              selected: isEnd,
                              today: _same(d, today),
                              enabled: widget.enabled && _allowed(d),
                              weekend: d.weekday >= 6,
                              onTap: () => _choose(d),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
      ],
    );
  }
}

class _Cell extends StatefulWidget {
  const _Cell({required this.label, required this.selected, required this.today, required this.enabled, required this.onTap, this.weekend = false});

  final String label;
  final bool selected;
  final bool today;
  final bool enabled;
  final bool weekend;
  final VoidCallback onTap;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colour = widget.selected
        ? cs.onPrimary
        : !widget.enabled
            ? cs.onSurface.withValues(alpha: 0.28)
            : widget.weekend
                ? cs.onSurfaceVariant
                : cs.onSurface;
    return Semantics(
      button: true,
      selected: widget.selected,
      enabled: widget.enabled,
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.selected ? cs.primary : (_hover && widget.enabled ? cs.surfaceContainerHighest : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: widget.today && !widget.selected ? Border.all(color: cs.primary, width: 1.5) : null,
            ),
            child: Text(
              widget.label,
              style: TextStyle(fontSize: 14, fontWeight: widget.selected || widget.today ? FontWeight.w700 : FontWeight.w500, color: colour),
            ),
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        shape: const CircleBorder(),
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 32, height: 32, child: Icon(icon, size: 20, color: cs.onSurface))),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primary.withValues(alpha: 0.14) : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: selected ? cs.primary : cs.outlineVariant)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? cs.primary : cs.onSurface)),
        ),
      ),
    );
  }
}

/// Asks for a day, in a dialog of the calendar of Agentivity: a tap on a day chooses it. Null when nothing was chosen.
Future<DateTime?> showAgDatePicker(BuildContext context, {DateTime? initialDate, DateTime? firstDate, DateTime? lastDate, String title = 'Choose a date'}) =>
    showDialog<DateTime>(
      context: context,
      builder: (context) => _CalendarDialog(title: title, initialDate: initialDate, firstDate: firstDate, lastDate: lastDate),
    );

/// Asks for a period: its first day, then its last; then it is confirmed. Null when nothing was chosen.
Future<DateTimeRange?> showAgDateRangePicker(BuildContext context, {DateTimeRange? initialRange, DateTime? firstDate, DateTime? lastDate, String title = 'Choose a period'}) =>
    showDialog<DateTimeRange>(
      context: context,
      builder: (context) => _CalendarDialog(title: title, range: true, initialRange: initialRange, firstDate: firstDate, lastDate: lastDate),
    );

class _CalendarDialog extends StatefulWidget {
  const _CalendarDialog({required this.title, this.range = false, this.initialDate, this.initialRange, this.firstDate, this.lastDate});

  final String title;
  final bool range;
  final DateTime? initialDate;
  final DateTimeRange? initialRange;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late DateTime? _start = widget.initialRange?.start;
  late DateTime? _end = widget.initialRange?.end;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chosen = widget.range
        ? (_start == null ? 'Choose the first day' : _end == null ? '${agDateText(_start!)} → choose the last day' : '${agDateText(_start!)} → ${agDateText(_end!)}')
        : (widget.initialDate == null ? 'Tap a day' : agDateText(widget.initialDate!));
    return Dialog(
      backgroundColor: cs.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(chosen, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 16),
              AgCalendar(
                value: widget.initialDate,
                rangeMode: widget.range,
                rangeStart: _start,
                rangeEnd: _end,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                onChanged: (d) => Navigator.of(context).pop(d),
                onRangeChanged: (start, end) => setState(() {
                  _start = start;
                  _end = end;
                }),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  if (widget.range) ...[
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: _start != null && _end != null ? () => Navigator.of(context).pop(DateTimeRange(start: _start!, end: _end!)) : null,
                      child: const Text('Choose these days'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A field of a form that holds a day: what is chosen (or [hint]), a calendar icon, and the calendar on a tap.
class AgDateField extends StatelessWidget {
  const AgDateField({super.key, required this.value, required this.onChanged, this.hint = 'Choose a date', this.firstDate, this.lastDate, this.enabled = true});

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String hint;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: value == null ? hint : agDateText(value!),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: !enabled
            ? null
            : () async {
                final picked = await showAgDatePicker(context, initialDate: value, firstDate: firstDate, lastDate: lastDate);
                if (picked != null) onChanged(picked);
              },
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: value != null ? cs.primary : cs.outlineVariant, width: value != null ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 18, color: value != null ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: Text(value == null ? hint : agDateText(value!), style: TextStyle(fontSize: 14, color: value != null ? cs.onSurface : cs.onSurfaceVariant))),
              if (enabled) Icon(Icons.expand_more_rounded, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
