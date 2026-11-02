import 'package:flutter/material.dart';

/// What stands in for a custom widget this app does not have, when an agent uses one to ask something: an app may register its own
/// picture of it, but an agent's question must never silently vanish. Any list of items in the props is shown as options, each with
/// its name and what else it says, and choosing one answers like a choice card (`"Choice: Casa Llum"`).
///
/// [fromProps] gives null when the props hold no such list: a widget that only shows something stays out of the way.
class AgUnknownChoices extends StatefulWidget {
  const AgUnknownChoices._({required this.items, required this.props});

  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> props;

  static const _nameKeys = ['name', 'title', 'label'];
  static const _hiddenKeys = {'id', 'image', 'imageUrl', 'url', 'recommended', 'currency', ..._nameKeys};

  static Widget? fromProps(Map<String, dynamic> props) {
    for (final entry in props.entries) {
      if (entry.key.startsWith('__') || entry.value is! List) continue;
      final items = [for (final item in entry.value as List) if (item is Map) Map<String, dynamic>.from(item)];
      if (items.isNotEmpty && items.every((item) => _nameOf(item) != null)) return AgUnknownChoices._(items: items, props: props);
    }
    return null;
  }

  static String? _nameOf(Map<String, dynamic> item) {
    for (final key in _nameKeys) {
      final value = item[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  // Everything else an item says, in its own words: its figures carry its currency.
  static String _detailOf(Map<String, dynamic> item) {
    final currency = item['currency'] is String ? ' ${item['currency']}' : '';
    return [
      for (final entry in item.entries)
        if (!_hiddenKeys.contains(entry.key) && (entry.value is String || entry.value is num) && '${entry.value}'.trim().isNotEmpty) entry.value is num ? '${entry.value}$currency' : '${entry.value}',
    ].join(' · ');
  }

  @override
  State<AgUnknownChoices> createState() => _AgUnknownChoicesState();
}

class _AgUnknownChoicesState extends State<AgUnknownChoices> {
  String? _chosen;

  void _choose(String name) {
    final onSubmit = widget.props['__onSubmit'] as Function?;
    if (onSubmit == null || _chosen != null) return;
    setState(() => _chosen = name);
    onSubmit('Choice: $name');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      for (final item in widget.items)
        Builder(builder: (context) {
          final name = AgUnknownChoices._nameOf(item)!;
          final chosen = _chosen == name;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: chosen ? scheme.primaryContainer : scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: item['recommended'] == true ? scheme.primary : scheme.outlineVariant)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _choose(name),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    if (AgUnknownChoices._detailOf(item).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(AgUnknownChoices._detailOf(item), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ]),
                ),
              ),
            ),
          );
        }),
    ]);
  }
}
