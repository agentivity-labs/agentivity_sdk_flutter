import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';
import '../theme/ag_artifacts_theme.dart';

/// Confirmation / approval card.
///
/// Agent props:
/// ```json
/// {
///   "title": "Confirmation requise",
///   "message": "Voulez-vous procéder à la commande ?",
///   "context": "PC gaming RTX 4070, livraison 3-5 jours ouvrés",
///   "confirmLabel": "Confirmer",
///   "cancelLabel": "Annuler"
/// }
/// ```
///
/// Calls `props['__onSubmit']` with `"Confirmé"` or `"Annulé"`.
class AgConfirmCard extends StatefulWidget {
  const AgConfirmCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  State<AgConfirmCard> createState() => _AgConfirmCardState();
}

class _AgConfirmCardState extends State<AgConfirmCard> {
  String? _choice;

  void _choose(String value) {
    final onSubmit = widget.props['__onSubmit'] as Function?;
    if (onSubmit == null || _choice != null) return;
    setState(() => _choice = value);
    onSubmit(value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // A button's own Text label doesn't inherit AgArtifactCard's DefaultTextStyle.merge — see
    // ag_choice_card.dart's identical note.
    final fontFamily = AgArtifactsThemeData.of(context).fontFamily;
    final title = widget.props['title'] as String? ?? 'Confirmation';
    final message = widget.props['message'] as String? ?? '';
    final context_ = widget.props['context'] as String?;
    final confirmLabel = widget.props['confirmLabel'] as String? ?? 'Confirmer';
    final cancelLabel = widget.props['cancelLabel'] as String? ?? 'Annuler';

    final isDone = _choice != null;
    final confirmed = _choice == confirmLabel;

    return AgArtifactCard(
      title: title,
      icon: Icons.check_circle_outline_rounded,
      type: 'Confirmation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (context_ != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(
                context_,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
          if (isDone) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  confirmed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 16,
                  color: confirmed ? const Color(0xFF10b981) : cs.error,
                ),
                const SizedBox(width: 6),
                Text(
                  _choice!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: confirmed ? const Color(0xFF10b981) : cs.error,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _choose(cancelLabel),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      cancelLabel,
                      style: TextStyle(fontFamily: fontFamily, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _choose(confirmLabel),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: TextStyle(fontFamily: fontFamily, fontSize: 13),
                    ),
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
