import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';

/// Structured summary / recap card shown before a confirmation step.
///
/// Agent props:
/// ```json
/// {
///   "title": "Récapitulatif de commande",
///   "sections": [
///     {
///       "label": "Produit",
///       "items": [
///         {"key": "Modèle", "value": "PC Gaming RTX 4070"},
///         {"key": "Prix", "value": "1 499 €"},
///         {"key": "Délai", "value": "3-5 jours ouvrés"}
///       ]
///     },
///     {
///       "label": "Livraison",
///       "items": [
///         {"key": "Adresse", "value": "12 rue de la Paix, Paris"},
///         {"key": "Mode", "value": "Standard"}
///       ]
///     }
///   ],
///   "note": "Frais de port offerts dès 500 €"
/// }
/// ```
/// Display-only — no submit callback. Pair with a ConfirmCard below it.
class AgSummaryCard extends StatelessWidget {
  const AgSummaryCard({super.key, required this.props});
  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = props['title'] as String? ?? 'Récapitulatif';
    final note = props['note'] as String?;
    final rawSections = props['sections'] as List? ?? [];
    final sections = rawSections
        .whereType<Map<dynamic, dynamic>>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();

    return AgArtifactCard(
      title: title,
      icon: Icons.receipt_long_rounded,
      type: 'Récap',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...sections.asMap().entries.map((entry) {
            final i = entry.key;
            final section = entry.value;
            final label = section['label'] as String?;
            final rawItems = section['items'] as List? ?? [];
            final items = rawItems
                .whereType<Map<dynamic, dynamic>>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (i > 0) const SizedBox(height: 12),
                if (label != null) ...[
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.asMap().entries.map((e) {
                      final isLast = e.key == items.length - 1;
                      final key = e.value['key'] as String? ?? '';
                      final value = e.value['value']?.toString() ?? '';
                      final highlight = e.value['highlight'] as bool? ?? false;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            child: Row(
                              children: [
                                Text(
                                  key,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  value,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                                    color: highlight ? cs.primary : cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          }),
          if (note != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 13, color: cs.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note,
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55)),
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
