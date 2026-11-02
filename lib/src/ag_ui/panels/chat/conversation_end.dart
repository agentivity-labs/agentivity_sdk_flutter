import 'package:flutter/material.dart';

/// The words of [AgUiChatConversationEnd].
class AgUiConversationEndTexts {
  const AgUiConversationEndTexts({
    this.finished = 'This job is finished. What next?',
    this.ended = 'This conversation has ended. Start a new one?',
    this.goOn = 'Continue',
    this.close = 'Close',
    this.startAnother = 'Start another',
    this.startNew = 'Start a new one',
  });

  final String finished;
  final String ended;
  final String goOn;
  final String close;
  final String startAnother;
  final String startNew;
}

/// What comes next when a job is finished, or when a conversation has ended: only a choice of the person starts or ends anything.
/// Shown by `AgUiChatDiscussion`. Mirrors the React SDK's `ChatConversationEnd`.
class AgUiChatConversationEnd extends StatelessWidget {
  const AgUiChatConversationEnd({super.key, required this.ended, this.onContinue, this.onClose, this.onStartNew, this.texts = const AgUiConversationEndTexts()});

  /// True when nothing goes on here any more; false when a job is finished and the conversation stays open.
  final bool ended;

  /// The person goes on here. Typing does the same.
  final VoidCallback? onContinue;

  /// Closes the conversation. No such choice when null.
  final VoidCallback? onClose;

  /// Starts a new conversation, from zero. No such choice when null.
  final VoidCallback? onStartNew;

  final AgUiConversationEndTexts texts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: Text(ended ? texts.ended : texts.finished, style: Theme.of(context).textTheme.bodySmall)),
          if (!ended && onContinue != null) TextButton(onPressed: onContinue, child: Text(texts.goOn)),
          if (!ended && onClose != null) TextButton(onPressed: onClose, child: Text(texts.close)),
          if (onStartNew != null) FilledButton.tonal(onPressed: onStartNew, child: Text(ended ? texts.startNew : texts.startAnother)),
        ],
      ),
    );
  }
}
