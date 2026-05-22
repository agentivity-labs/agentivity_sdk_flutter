import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';

/// Key → value property list, useful for structured entity display.
///
/// Agent props:
/// ```json
/// {
///   "title": "Order details",
///   "items": [
///     { "key": "Order ID",   "value": "#ORD-9182" },
///     { "key": "Status",     "value": "Shipped",  "highlight": true },
///     { "key": "Customer",   "value": "Alice Martin" },
///     { "key": "Total",      "value": "€ 249.00" }
///   ],
///   "dividers": true
/// }
/// ```
class AgKeyValue extends StatelessWidget {
  const AgKeyValue({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = props['title'] as String? ?? 'Properties';
    final items = (props['items'] as List?) ?? [];
    final showDividers = props['dividers'] as bool? ?? true;

    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      final key = item['key']?.toString() ?? '';
      final value = item['value']?.toString() ?? '';
      final highlight = item['highlight'] as bool? ?? false;

      if (showDividers && i > 0) {
        rows.add(Divider(
          height: 1,
          thickness: 1,
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ));
      }
      rows.add(_KeyValueRow(
        keyText: key,
        valueText: value,
        highlight: highlight,
        cs: cs,
      ));
    }

    return AgArtifactCard(
      title: title,
      type: 'Key–Value',
      icon: Icons.list_alt_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.keyText,
    required this.valueText,
    required this.highlight,
    required this.cs,
  });

  final String keyText;
  final String valueText;
  final bool highlight;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              keyText,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              valueText,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: highlight ? cs.primary : cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
