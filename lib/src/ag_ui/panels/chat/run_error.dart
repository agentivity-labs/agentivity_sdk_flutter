import 'package:flutter/material.dart';

import 'chat_controller.dart';

/// What each error code the platform reports means for the person using the app: a headline, and the next step when there is one.
({String title, String? hint}) agUiDescribeRunError(AgUiRunError error) => switch (error.code) {
  'llm_billing' => (title: 'The AI service is out of credit', hint: 'Add credit to the AI provider account, then send your message again.'),
  'llm_auth' => (title: 'The AI service rejected its API key', hint: 'Check the API key configured for the model, then send your message again.'),
  'llm_rate_limited' => (title: 'The AI service is busy', hint: 'Wait a moment, then send your message again.'),
  'llm_unavailable' => (title: 'The AI service is unavailable', hint: 'Try again in a few minutes.'),
  _ => (title: 'Something went wrong', hint: null),
};

/// The run stopped on an error: what happened, in plain words, and what the provider or platform said. Shown by
/// [AgUiChatDiscussion] whenever the run ends with an error ([ChatController.runError]) — an account out of credit, a rejected
/// API key or an unavailable AI service must never leave the conversation looking stuck.
class AgUiChatRunError extends StatelessWidget {
  const AgUiChatRunError({super.key, required this.error, this.onDismiss});

  final AgUiRunError error;

  /// Called when the user dismisses the notice. The notice has no dismiss button when null.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final described = agUiDescribeRunError(error);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.07),
          border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(described.title, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: scheme.error)),
                  if (described.hint != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(described.hint!, style: text.bodySmall)),
                  if (error.message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(error.message, style: text.bodySmall?.copyWith(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}
