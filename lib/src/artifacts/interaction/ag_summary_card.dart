import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';
import '../shell/ag_artifact_image.dart';

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
/// Pictures turn a section into a "product sheet": a card with three sections is three products, each with its
/// photo, its facts and an optional badge and link. `imageUrl` on the card is a banner above all sections.
/// ```json
/// {
///   "title": "Top picks",
///   "imageUrl": "https://…",
///   "sections": [
///     {
///       "label": "Roomba Combo", "badge": "Best overall",
///       "imageUrl": "https://…", "imageAlt": "Roomba Combo", "url": "https://shop.example/roomba",
///       "items": [{"key": "Price", "value": "$499", "highlight": true}]
///     }
///   ]
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
    final bannerUrl = agSafeImageUrl(props['imageUrl']);
    final bannerAlt = props['imageAlt'] as String? ?? title;
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
          if (bannerUrl != null) ...[
            AgArtifactImage(src: bannerUrl, alt: bannerAlt, aspectRatio: 16 / 7, fit: BoxFit.cover),
            const SizedBox(height: 12),
          ],
          ...sections.asMap().entries.map((entry) {
            final i = entry.key;
            final section = entry.value;
            final label = section['label'] as String?;
            final imageUrl = agSafeImageUrl(section['imageUrl']);
            final imageAlt = section['imageAlt'] as String? ?? label;
            final badgeRaw = section['badge'];
            final badge = badgeRaw is String && badgeRaw.trim().isNotEmpty ? badgeRaw : null;
            final link = agSafeHttpUrl(section['url']);
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
                if (label != null || badge != null) ...[
                  Row(
                    children: [
                      if (label != null)
                        Flexible(
                          child: GestureDetector(
                            onTap: link == null ? null : () => AgArtifactLinks.open(context, link),
                            child: Text(
                              label.toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                                color: cs.onSurface.withValues(alpha: link == null ? 0.45 : 0.7),
                                decoration: link == null ? null : TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(3)),
                          child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.primary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                _SectionBody(
                  image: imageUrl == null
                      ? null
                      : GestureDetector(
                          onTap: link == null ? null : () => AgArtifactLinks.open(context, link),
                          child: AgArtifactImage(src: imageUrl, alt: imageAlt, aspectRatio: 1),
                        ),
                  facts: Container(
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                  value,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                                    color: highlight ? cs.primary : cs.onSurface,
                                  ),
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

/// A section's picture beside its facts — or above them when the card is too narrow for both.
class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.image, required this.facts});

  final Widget? image;
  final Widget facts;

  static const double _imageSize = 120;

  @override
  Widget build(BuildContext context) {
    final picture = image;
    if (picture == null) return facts;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: SizedBox(width: _imageSize, child: picture)),
              const SizedBox(height: 10),
              facts,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: _imageSize, child: picture),
            const SizedBox(width: 10),
            Expanded(child: facts),
          ],
        );
      },
    );
  }
}
