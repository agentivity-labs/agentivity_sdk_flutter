import 'package:agentivity_artifacts/agentivity_artifacts.dart';
import 'package:flutter/material.dart';

import 'demos/demo_agent_log.dart';
import 'demos/demo_architecture.dart';
import 'demos/demo_code_review.dart';
import 'demos/demo_ecommerce.dart';
import 'demos/demo_financial.dart';
import 'demos/demo_ops.dart';
import 'demos/demo_scientific.dart';
import 'home_page.dart';

void main() => runApp(const ShowcaseApp());

// ---------------------------------------------------------------------------
// Demo registry
// ---------------------------------------------------------------------------

class _Demo {
  const _Demo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.suggestedTheme,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String suggestedTheme;
  final Widget Function() builder;
}

const _demos = [
  _Demo(
    title: 'Financial Intelligence',
    subtitle: 'Prices · portfolio · radar',
    icon: Icons.candlestick_chart_rounded,
    suggestedTheme: 'Noir',
    builder: DemoFinancial.new,
  ),
  _Demo(
    title: 'Ops Dashboard',
    subtitle: 'Alerts · incidents · metrics',
    icon: Icons.monitor_heart_rounded,
    suggestedTheme: 'Ember',
    builder: DemoOps.new,
  ),
  _Demo(
    title: 'E-commerce Burst',
    subtitle: 'GMV · orders · fulfillment',
    icon: Icons.shopping_bag_rounded,
    suggestedTheme: 'Candy',
    builder: DemoEcommerce.new,
  ),
  _Demo(
    title: 'AI Code Review',
    subtitle: 'Diff · tests · PR timeline',
    icon: Icons.code_rounded,
    suggestedTheme: 'Glacier',
    builder: DemoCodeReview.new,
  ),
  _Demo(
    title: 'Scientific Report',
    subtitle: 'LaTeX · plots · Black-Scholes',
    icon: Icons.science_rounded,
    suggestedTheme: 'Paper',
    builder: DemoScientific.new,
  ),
  _Demo(
    title: 'Architecture',
    subtitle: 'SVG · code · roadmap',
    icon: Icons.account_tree_rounded,
    suggestedTheme: 'Brutalist',
    builder: DemoArchitecture.new,
  ),
  _Demo(
    title: 'Agent Activity Log',
    subtitle: 'Steps · tools · cost',
    icon: Icons.smart_toy_rounded,
    suggestedTheme: 'Aurora',
    builder: DemoAgentLog.new,
  ),
];

// ---------------------------------------------------------------------------
// Root app — always uses the Agentivity light theme for the shell chrome.
// Each demo panel overrides the theme in its own Theme() wrapper.
// ---------------------------------------------------------------------------

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'agentivity_artifacts',
      debugShowCheckedModeBanner: false,
      theme: AgArtifactsThemes.themeDataFor('Agentivity'),
      home: const _Shell(),
    );
  }
}

// ---------------------------------------------------------------------------
// _Shell — persistent sidebar + content panel
// ---------------------------------------------------------------------------

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  /// 0 = Overview page, 1…N = demos[index - 1]
  int _selectedIndex = 0;
  String _themeName = 'Agentivity';

  void _selectIndex(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildContent() {
    final Widget child = _selectedIndex == 0
        ? const OverviewPage()
        : _demos[_selectedIndex - 1].builder();

    return Theme(
      data: AgArtifactsThemes.themeDataFor(_themeName),
      // ValueKey on the demo index restarts the streaming animation on
      // navigation while preserving state across theme-only changes.
      child: KeyedSubtree(
        key: ValueKey(_selectedIndex),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Row(
        children: [
          SizedBox(
            width: 224,
            child: _Sidebar(
              selectedIndex: _selectedIndex,
              themeName: _themeName,
              onSelectIndex: _selectIndex,
              onThemeChanged: (t) => setState(() => _themeName = t),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: cs.outlineVariant,
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Sidebar
// ---------------------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.themeName,
    required this.onSelectIndex,
    required this.onThemeChanged,
  });

  final int selectedIndex;
  final String themeName;
  final ValueChanged<int> onSelectIndex;
  final ValueChanged<String> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Brand header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: cs.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'artifacts',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'agentivity',
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.onSurface.withValues(alpha: 0.4),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Nav items ────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                // Overview
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Overview',
                  selected: selectedIndex == 0,
                  onTap: () => onSelectIndex(0),
                ),
                const SizedBox(height: 10),

                // Examples section
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                  child: Text(
                    'EXAMPLES',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: cs.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ),
                for (var i = 0; i < _demos.length; i++)
                  _NavItem(
                    icon: _demos[i].icon,
                    label: _demos[i].title,
                    subtitle: _demos[i].subtitle,
                    selected: selectedIndex == i + 1,
                    onTap: () => onSelectIndex(i + 1),
                  ),
              ],
            ),
          ),

          // ── Theme picker ─────────────────────────────────────────────────
          Divider(height: 1, thickness: 1, color: cs.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 6),
                  child: Text(
                    'THEME',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: cs.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ),
                _ThemePicker(
                  currentTheme: themeName,
                  onChanged: onThemeChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NavItem
// ---------------------------------------------------------------------------

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? accent
                      : cs.onSurface.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? accent
                              : cs.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withValues(alpha: 0.4),
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ThemePicker
// ---------------------------------------------------------------------------

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({
    required this.currentTheme,
    required this.onChanged,
  });

  final String currentTheme;
  final ValueChanged<String> onChanged;

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
    final cs = Theme.of(context).colorScheme;
    final ext =
        AgArtifactsThemes.all[currentTheme] ?? AgArtifactsThemes.neutral;
    final accentColor = _hex(ext.effectivePalette().first);

    return PopupMenuButton<String>(
      initialValue: currentTheme,
      onSelected: onChanged,
      tooltip: 'Change theme',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      // Pop upward so the menu doesn't clip at the bottom
      position: PopupMenuPosition.over,
      offset: const Offset(0, -16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                currentTheme,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 14,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) => AgArtifactsThemes.all.entries.map((e) {
        final name = e.key;
        final color = _hex(e.value.effectivePalette().first);
        final isDark =
            (AgArtifactsThemes.suggestedBrightness[name] ?? Brightness.light) ==
                Brightness.dark;
        return PopupMenuItem<String>(
          value: name,
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: name == currentTheme
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ),
              Text(
                isDark ? '🌑' : '☀️',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
