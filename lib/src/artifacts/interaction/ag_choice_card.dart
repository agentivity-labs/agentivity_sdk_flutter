import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';
import '../theme/ag_artifacts_theme.dart';

/// Single or multi-select choice widget.
///
/// Agent props:
/// ```json
/// {
///   "title": "Type de demande",
///   "question": "S'agit-il d'un achat professionnel ou personnel ?",
///   "multiple": false,
///   "options": [
///     {"id": "pro", "label": "Professionnel", "description": "Achat pour l'entreprise"},
///     {"id": "perso", "label": "Personnel", "description": "Usage privé"},
///     {"id": "gaming", "label": "Gaming", "description": "Jeux vidéo"}
///   ],
///   "submitLabel": "Confirmer"
/// }
/// ```
///
/// Calls `props['__onSubmit']` with selected label(s):
/// - Single: `"Choix : Gaming"`
/// - Multiple: `"Choix : Gaming, Professionnel"`
class AgChoiceCard extends StatefulWidget {
  const AgChoiceCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  State<AgChoiceCard> createState() => _AgChoiceCardState();
}

class _AgChoiceCardState extends State<AgChoiceCard> {
  late final List<Map<String, dynamic>> _options;
  late final bool _multiple;
  final Set<String> _selected = {};
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final raw = widget.props['options'];
    _options =
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
    _multiple = widget.props['multiple'] as bool? ?? false;
  }

  void _toggle(String id) {
    if (_submitted) return;
    setState(() {
      if (_multiple) {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      } else {
        _selected
          ..clear()
          ..add(id);
      }
    });
  }

  void _submit() {
    final onSubmit = widget.props['__onSubmit'] as Function?;
    if (onSubmit == null || _submitted || _selected.isEmpty) return;

    final labels = _selected
        .map((id) {
          final opt = _options.firstWhere(
            (o) => o['id'] == id,
            orElse: () => {'label': id},
          );
          return opt['label'] as String? ?? id;
        })
        .join(', ');

    setState(() => _submitted = true);
    onSubmit('Choix : $labels');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // A button's own child Text does not inherit AgArtifactCard's DefaultTextStyle.merge (a
    // button resolves its label style from its own ButtonStyle, not the ambient DefaultTextStyle)
    // — confirmed by test, and the reason every FilledButton/OutlinedButton label below sets
    // fontFamily explicitly instead of relying on inheritance like the plain Text widgets here do.
    final fontFamily = AgArtifactsThemeData.of(context).fontFamily;
    final title = widget.props['title'] as String? ?? 'Choix';
    final question = widget.props['question'] as String?;
    final submitLabel = widget.props['submitLabel'] as String? ?? 'Confirmer';

    return AgArtifactCard(
      title: title,
      icon: Icons.tune_rounded,
      type: _multiple ? 'Multi-select' : 'Select',
      // Disabled/answered visual state is owned by the chat panel's message
      // bubble (_MessageBubble._dimIfDisabled), not here. _toggle/_submit
      // already guard on _submitted, so no IgnorePointer/Opacity is needed
      // locally — a second, stacked dimming layer here used to render the
      // already-selected option at ~10% effective opacity, close enough to
      // invisible to look like the selection had been cleared.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (question != null) ...[
            Text(
              question,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ..._options.map((opt) {
            final id = opt['id'] as String? ?? '';
            final label = opt['label'] as String? ?? id;
            final description = opt['description'] as String?;
            final isSelected = _selected.contains(id);

            return GestureDetector(
              onTap: () => _toggle(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? cs.primaryContainer.withValues(alpha: 0.5)
                          : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? cs.primary : cs.outlineVariant,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _multiple
                          ? (isSelected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded)
                          : (isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded),
                      size: 18,
                      color:
                          isSelected
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                          if (description != null)
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: (_submitted || _selected.isEmpty) ? null : _submit,
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
