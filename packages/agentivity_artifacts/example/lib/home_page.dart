import 'package:agentivity_artifacts/agentivity_artifacts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Overview / home page
// ---------------------------------------------------------------------------

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 48),
        children: [
          // ── Hero ──────────────────────────────────────────────────────────
          _Hero(cs: cs, tt: tt),
          const SizedBox(height: 40),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 32),

          // ── Widget catalogue ───────────────────────────────────────────────
          _SectionTitle('Widget catalogue', cs: cs, tt: tt),
          const SizedBox(height: 16),
          const _WidgetCatalogue(),
          const SizedBox(height: 36),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 32),

          // ── Demos ─────────────────────────────────────────────────────────
          _SectionTitle('The demos', cs: cs, tt: tt),
          const SizedBox(height: 4),
          Text(
            'Each demo runs a full agent streaming simulation '
            'and showcases a different theme preset.',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const _DemoTable(),
          const SizedBox(height: 36),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 32),

          // ── Quick start ───────────────────────────────────────────────────
          _SectionTitle('Quick start', cs: cs, tt: tt),
          const SizedBox(height: 16),
          const _QuickStart(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Hero
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge row
        Wrap(
          spacing: 8,
          children: [
            _Badge('pub.dev 0.1.0', cs.primary),
            _Badge('14 widgets', cs.secondary),
            _Badge('11 themes', cs.tertiary),
            _Badge('AG-UI protocol', cs.primary),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'agentivity_artifacts',
          style: tt.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Flutter widgets for AI agent artifacts.',
          style: tt.titleMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Drop AI agent output directly into Flutter. '
            'Charts, metrics, code blocks, JSON trees, mathematical formulas '
            'and status cards — all driven by theme presets, all streamable '
            'via the AG-UI protocol. Register the full widget vocabulary in '
            'one line and let your agent decide what to render.',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
              height: 1.65,
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SectionTitle
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.cs, required this.tt});
  final String text;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: tt.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WidgetCatalogue
// ---------------------------------------------------------------------------

class _WidgetCatalogue extends StatelessWidget {
  const _WidgetCatalogue();

  static const _groups = [
    _Group('Charts', Icons.bar_chart_rounded, [
      _Entry('BarChart',   'Grouped / stacked bar chart'),
      _Entry('LineChart',  'Multi-series line with smooth curves'),
      _Entry('PieChart',   'Pie or donut chart'),
      _Entry('AreaChart',  'Filled area chart'),
      _Entry('RadarChart', 'Spider / radar polygon chart'),
    ]),
    _Group('Data', Icons.table_chart_rounded, [
      _Entry('MetricCard', 'Single KPI with trend delta'),
      _Entry('StatGrid',   'Responsive grid of MetricCards'),
      _Entry('KeyValue',   'Structured key–value table'),
    ]),
    _Group('Code', Icons.code_rounded, [
      _Entry('CodeBlock',  'Syntax-highlighted code with copy'),
      _Entry('JsonViewer', 'Collapsible JSON tree'),
    ]),
    _Group('Status', Icons.check_circle_rounded, [
      _Entry('StatusCard', 'Success / error / warning / running'),
      _Entry('Timeline',   'Step timeline with status icons'),
    ]),
    _Group('Math & SVG', Icons.functions_rounded, [
      _Entry('Latex', 'Rendered LaTeX / MathML formula'),
      _Entry('Svg',   'Scalable vector graphic'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final g in _groups)
          _GroupCard(group: g, cs: cs),
      ],
    );
  }
}

class _Group {
  final String name;
  final IconData icon;
  final List<_Entry> entries;
  const _Group(this.name, this.icon, this.entries);
}

class _Entry {
  final String name;
  final String desc;
  const _Entry(this.name, this.desc);
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.cs});
  final _Group group;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                group.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final e in group.entries) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 4, right: 7),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        e.desc,
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurface.withValues(alpha: 0.5),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DemoTable
// ---------------------------------------------------------------------------

class _DemoTable extends StatelessWidget {
  const _DemoTable();

  static const _rows = [
    _DemoRow('Financial Intelligence', 'Noir', '🌑',
        'Price/MA line chart · volume bar · portfolio pie · '
        'radar risk profile · instrument key-value'),
    _DemoRow('Ops Dashboard', 'Ember', '🌑',
        'Platform KPIs · 4 StatusCard variants · '
        'error spike bar chart · incident timeline'),
    _DemoRow('E-commerce Burst', 'Candy', '☀️',
        'GMV/orders · category bar · intraday area · '
        'payment pie · fulfillment timeline'),
    _DemoRow('AI Code Review', 'Glacier', '☀️',
        'PR KPIs · CI StatusCard · before/after diff · '
        'Jest JSON results · PR lifecycle timeline'),
    _DemoRow('Scientific Report', 'Paper', '☀️',
        'Black-Scholes & Fourier LaTeX · trig function plot · '
        'Python pricer CodeBlock · model key-value'),
    _DemoRow('System Architecture', 'Brutalist', '☀️',
        'SVG microservices diagram · TypeScript + YAML code · '
        'tech stack key-value · Q1 roadmap'),
    _DemoRow('Agent Activity Log', 'Aurora', '🌑',
        'Run KPIs · task & warning StatusCards · '
        'execution timeline · write_file JSON · generated code'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            _DemoTableRow(row: _rows[i], cs: cs),
          ],
        ],
      ),
    );
  }
}

class _DemoRow {
  final String title;
  final String theme;
  final String moon;
  final String desc;
  const _DemoRow(this.title, this.theme, this.moon, this.desc);
}

class _DemoTableRow extends StatelessWidget {
  const _DemoTableRow({required this.row, required this.cs});
  final _DemoRow row;
  final ColorScheme cs;

  static Color _hex(String h) {
    try {
      final c = h.replaceFirst('#', '');
      return Color(int.parse(c.length == 6 ? 'FF$c' : c, radix: 16));
    } catch (_) {
      return const Color(0xFF6366f1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AgArtifactsThemes.all[row.theme] ?? AgArtifactsThemes.neutral;
    final accent = _hex(ext.effectivePalette().first);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent dot
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4, right: 12),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          // Title + theme badge
          SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        row.theme,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(row.moon, style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Description
          Expanded(
            child: Text(
              row.desc,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.55),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _QuickStart
// ---------------------------------------------------------------------------

class _QuickStart extends StatelessWidget {
  const _QuickStart();

  static const _pubspec = '''dependencies:
  agentivity_artifacts: ^0.1.0''';

  static const _agui = '''// With AG-UI — let the agent decide what to render:
AgUiGenerativeView(
  controller: AgUiGenerativeController(
    events: channel.events,
    widgetRegistry: AgArtifactsBundle.registry(),
  ),
)''';

  static const _standalone = '''// Standalone — render any widget directly:
AgArtifactViewer(
  type: 'BarChart',
  props: {
    'title': 'Weekly Revenue',
    'labels': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    'datasets': [
      {'label': 'Revenue', 'data': [42, 58, 75, 91, 84]},
    ],
  },
)''';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CodeSnippet(label: 'pubspec.yaml', code: _pubspec, cs: cs, tt: tt),
        const SizedBox(height: 12),
        _CodeSnippet(label: 'With AG-UI', code: _agui, cs: cs, tt: tt),
        const SizedBox(height: 12),
        _CodeSnippet(label: 'Standalone', code: _standalone, cs: cs, tt: tt),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: cs.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: cs.primary.withValues(alpha: 0.7)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Select a demo from the sidebar to see each widget type '
                  'in action. Use the theme picker at the bottom to try '
                  'every visual preset.',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.65),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CodeSnippet extends StatefulWidget {
  const _CodeSnippet({
    required this.label,
    required this.code,
    required this.cs,
    required this.tt,
  });
  final String label;
  final String code;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  State<_CodeSnippet> createState() => _CodeSnippetState();
}

class _CodeSnippetState extends State<_CodeSnippet> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _copy,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  key: ValueKey(_copied),
                  size: 14,
                  color: _copied
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Text(
            widget.code,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.85),
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
