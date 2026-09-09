import 'package:flutter/material.dart';

import '../../theme/ag_theme_data.dart';
import '../../tools/ag_ui_widget_registry.dart';
import '../../widgets/ag_ui_markdown_body.dart';
import 'ag_ui_chat_input.dart';
import 'chat_controller.dart';
import 'chat_models.dart';

/// A complete chat discussion — message list + composer, orchestrated as one
/// widget — backed by a [ChatController].
///
/// ## Pull-based (REST) usage
///
/// ```dart
/// AgUiChatDiscussion(
///   controller: ChatController(provider: myProvider, contextId: runId),
///   threadId: threadId,
/// )
/// ```
///
/// ## Push-based (AG-UI events) — zero boilerplate
///
/// Pass `null` for [threadId] to let the panel auto-select the first available
/// thread (populated by `CHAT_THREAD_CREATED` events). Provide [onHilResponse]
/// so the panel can send the user's reply to the backend when a HIL gate is
/// active.
///
/// ```dart
/// AgUiChatDiscussion(
///   controller: ChatController.fromStream(
///     events: sseChannel.stream,
///     contextId: runId,
///   ),
///   threadId: null,          // auto-selects default thread from events
///   onHilResponse: (gate, text, source) async {
///     await api.postInteraction(
///       runId: runId,
///       threadId: gate.threadId,
///       requestId: gate.requestId,
///       text: text,
///     );
///   },
/// )
/// ```
///
/// Styling: add [AgThemeData] to your [ThemeData.extensions], or pass
/// [style] for a one-off override. Override individual parts with builders.
class AgUiChatDiscussion extends StatefulWidget {
  const AgUiChatDiscussion({
    super.key,
    required this.controller,
    this.threadId,
    this.style,
    this.widgetRegistry,
    this.messageBuilder,
    this.inputBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
    this.inputHint = 'Type a message…',
    this.hilInputHint = 'Type your response…',
    this.autoLoad = true,
    this.onAttach,
    this.onHilResponse,
    // AgUiChatInput passthrough
    this.enableVoice = false,
    this.enableAttachments = true,
    this.acceptedAttachmentExtensions,
    this.inputActionBar,
    this.inputLeadingActions,
    this.inputTrailingActions,
  });

  final ChatController controller;

  /// The thread to display.
  ///
  /// - Pass a specific `threadId` string to pin the panel to that thread.
  /// - Pass `null` to let the panel auto-select the default thread from
  ///   [ChatController.threads] (the first thread marked `isDefault`, or
  ///   else the first available thread). The panel stays empty until a thread
  ///   arrives via a `CHAT_THREAD_CREATED` event or [ChatController.loadThreads].
  final String? threadId;

  /// Visual overrides on top of [AgThemeData].
  final AgThemeData? style;

  /// Widget registry for rendering agent-produced artifact widgets
  /// (e.g. BarChart, StatusCard) inline in the conversation.
  /// When null, artifact messages fall back to rendering their metadata as text.
  final AgUiWidgetRegistry? widgetRegistry;

  /// Replace the default message bubble entirely.
  final Widget Function(ChatMessage message)? messageBuilder;

  /// Replace the default text input row.
  final Widget Function(void Function(String text) onSend)? inputBuilder;

  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? loadingBuilder;
  final String inputHint;

  /// Hint text shown in the input field when a HIL gate is active.
  final String hilInputHint;

  /// Call [ChatController.loadThreads] on first build.
  final bool autoLoad;

  /// Called when the user taps the attachment button. Should return a list of
  /// attachments chosen by the user, or `null` if the picker was cancelled.
  final Future<List<ChatAttachment>?> Function(BuildContext context)? onAttach;

  /// Called when the user submits a response to a pending HIL gate.
  ///
  /// [gate] contains `requestId`, `threadId`, `question`, and `title`.
  /// [text] is the user's response text.
  ///
  /// Post this to the backend interaction endpoint, then the run resumes and
  /// subsequent SSE events will clear [ChatController.pendingHilGate]
  /// automatically via a `CHAT_HIL_RESOLVED` event (or you can call
  /// [ChatController.clearHilGate] after a successful POST).
  ///
  /// When `null`, the HIL gate banner is shown as read-only (no input).
  /// [source] is `'text'` when the user typed the response in the input box, or
  /// `'widget'` when it was submitted through an interaction widget (ChoiceCard,
  /// QuestionForm…). Forward it to the backend so widget-sourced responses are stored
  /// for history but not rendered as a redundant user bubble.
  final Future<void> Function(ChatHilGate gate, String text, String source)? onHilResponse;

  // ── AgUiChatInput passthrough ──────────────────────────────────────────────

  /// Shows a microphone button in [AgUiChatInput]. Forwarded to [AgUiChatInput.enableVoice].
  final bool enableVoice;

  /// Shows the file attachment button in [AgUiChatInput]. Forwarded to [AgUiChatInput.enableAttachments].
  final bool enableAttachments;

  /// File extensions accepted by the input picker. Forwarded to [AgUiChatInput.acceptedExtensions].
  final List<String>? acceptedAttachmentExtensions;

  /// Full-width widget above the text field row. Forwarded to [AgUiChatInput.actionBar].
  final Widget? inputActionBar;

  /// Leading icon buttons in [AgUiChatInput]. Forwarded to [AgUiChatInput.leadingActions].
  final List<Widget>? inputLeadingActions;

  /// Trailing widgets after the send button. Forwarded to [AgUiChatInput.trailingActions].
  final List<Widget>? inputTrailingActions;

  @override
  State<AgUiChatDiscussion> createState() => _AgUiChatDiscussionState();
}

class _AgUiChatDiscussionState extends State<AgUiChatDiscussion> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = const [];
  bool _loadingMessages = false;
  bool _submittingHil = false;

  /// Resolved thread: [widget.threadId] if set, otherwise auto-selected.
  String? get _activeThreadId {
    if (widget.threadId != null) return widget.threadId;
    final threads = widget.controller.threads;
    if (threads.isEmpty) return null;
    return (threads.firstWhere((t) => t.isDefault, orElse: () => threads.first)).threadId;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMessages();
      });
    }
  }

  @override
  void didUpdateWidget(AgUiChatDiscussion old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
    }
    if (old.threadId != widget.threadId) _loadMessages();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    // When a new thread is discovered via events, load its messages.
    final threadId = _activeThreadId;
    if (threadId != null && _messages.isEmpty && !_loadingMessages) {
      _loadMessages();
    }
    // Merge locally-cached messages from push events. Reassign on ANY real
    // change, not just a length change — an in-place upsert (e.g.
    // ChatController replacing an existing message by id, same list length)
    // used to be skipped by the old `local.length != _messages.length`
    // check, so updated content/metadata on an existing message (like an
    // "answered" flag on an interactive widget) could silently fail to
    // reach this panel's own _messages snapshot. Only auto-scroll when the
    // list actually grew (a genuinely new message) — an in-place update to
    // an existing message shouldn't yank the view if the user has scrolled
    // up to read history.
    if (threadId != null) {
      final local = widget.controller.localMessages(threadId);
      if (local.isNotEmpty && !_sameMessages(local, _messages)) {
        final grew = local.length > _messages.length;
        setState(() => _messages = local);
        if (grew) _scrollToBottom();
        return;
      }
    }
    setState(() {});
  }

  /// Cheap, id/updatedAt/text-based comparison — enough to detect both a
  /// newly-appended message (length differs) and an in-place upsert of an
  /// existing one (same length, some entry's fields differ), without a full
  /// deep-equality check on every controller notification.
  static bool _sameMessages(List<ChatMessage> a, List<ChatMessage> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i], y = b[i];
      if (x.id != y.id || x.updatedAt != y.updatedAt || x.text != y.text) return false;
    }
    return true;
  }

  Future<void> _loadMessages() async {
    final threadId = _activeThreadId;
    if (threadId == null) return;
    // Use locally-cached messages first (push-based).
    final cached = widget.controller.localMessages(threadId);
    if (cached.isNotEmpty) {
      setState(() => _messages = cached);
      _scrollToBottom();
      return;
    }
    setState(() => _loadingMessages = true);
    try {
      final detail = await widget.controller.openThread(threadId: threadId);
      if (mounted) {
        // After the async gap, prefer push-injected messages that may have
        // arrived while the REST call was in flight — never overwrite them.
        final local = widget.controller.localMessages(threadId);
        setState(() => _messages = local.isNotEmpty ? local : detail.messages);
      }
    } finally {
      if (mounted) setState(() => _loadingMessages = false);
    }
    _scrollToBottom();
  }

  /// True when [message] carries at least one interactive widget block (a multi-block
  /// widget, or a standalone artifact message) — used to find the single most recent
  /// widget message that may still accept a response.
  static bool _hasInteractiveWidget(ChatMessage message) {
    final blocks = message.blocks;
    if (blocks != null && blocks.any((b) => b.type != 'text')) return true;
    return message.metadata?['widgetType'] != null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _inputController.clear();
    await widget.controller.sendMessage(threadId: _activeThreadId, text: trimmed);
    await _loadMessages();
  }

  Future<void> _submitHilResponse(String text, {String source = 'text'}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _submittingHil) return;
    final gate = widget.controller.pendingHilGate;
    if (gate == null) return;
    _inputController.clear();
    setState(() => _submittingHil = true);
    try {
      // The server adds the user's response to the thread and echoes it back
      // via CHAT_MESSAGE_RECEIVED(role=user) SSE — no local optimistic add needed.
      // (Widget-sourced responses are flagged so the echo is not rendered.)
      await widget.onHilResponse?.call(gate, trimmed, source);
      widget.controller.clearHilGate();
    } finally {
      if (mounted) setState(() => _submittingHil = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final theme = AgThemeData.of(context).copyWith(bubbleUserColor: s?.bubbleUserColor, bubbleAgentColor: s?.bubbleAgentColor, bubbleSystemColor: s?.bubbleSystemColor, bubbleUserTextStyle: s?.bubbleUserTextStyle, bubbleAgentTextStyle: s?.bubbleAgentTextStyle, bubbleRadius: s?.bubbleRadius, inputDecoration: s?.inputDecoration, sendIconColor: s?.sendIconColor);

    final hilGate = widget.controller.pendingHilGate;
    final isHilActive = hilGate != null;

    // ── Messages area ──────────────────────────────────────────────────────
    // Always build the Column so the input is always visible at the bottom.
    // The messages area shows the appropriate state (empty, loading, list).
    final Widget messagesArea;
    if (_loadingMessages || (widget.controller.isLoading && _activeThreadId == null && _messages.isEmpty)) {
      messagesArea = widget.loadingBuilder?.call(context) ?? const Center(child: CircularProgressIndicator());
    } else if (_activeThreadId == null && _messages.isEmpty && !isHilActive) {
      messagesArea = widget.emptyBuilder?.call(context) ?? const SizedBox.shrink();
    } else {
      // Only the most recent message carrying an interactive widget may still be answered —
      // every earlier widget (already resolved, or superseded by a later gate) renders read-only.
      // Keying off "last widget-bearing message" rather than "last message in the list" keeps
      // trailing plain-text messages (which are not answers) from wrongly re-enabling an old widget.
      final lastWidgetIndex = _messages.lastIndexWhere(_hasInteractiveWidget);
      messagesArea = ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _messages.length,
        itemBuilder: (context, i) {
          final msg = _messages[i];
          if (widget.messageBuilder != null) return widget.messageBuilder!(msg);
          final isActiveWidget = isHilActive && i == lastWidgetIndex;
          return _MessageBubble(
            key: ValueKey(msg.id),
            message: msg,
            theme: theme,
            widgetRegistry: widget.widgetRegistry,
            enabled: isActiveWidget,
            onWidgetSubmit: isActiveWidget && widget.onHilResponse != null
                ? (response) {
                    final gate = widget.controller.pendingHilGate;
                    if (gate != null) _submitHilResponse(response, source: 'widget');
                  }
                : null,
          );
        },
      );
    }

    return Column(
      children: [
        Expanded(child: messagesArea),

        // No HIL gate banner: the agent's question (with questions_to_ask) is already
        // published as a chat message, so the thread itself is the source of truth.
        // We only switch the input field to HIL mode so the response is routed correctly.

        // Input: HIL response field OR normal send input (always visible).
        if (isHilActive && widget.onHilResponse != null)
          Padding(padding: const EdgeInsets.all(8), child: AgUiChatInput(controller: _inputController, hint: widget.hilInputHint, hilHint: widget.hilInputHint, isHil: true, loading: _submittingHil, enableAttachments: false, onSend: (text, _) => _submitHilResponse(text)))
        else
          Padding(
            padding: const EdgeInsets.all(8),
            child:
                widget.inputBuilder?.call(_send) ??
                AgUiChatInput(
                  controller: _inputController,
                  hint: widget.inputHint,
                  hilHint: widget.hilInputHint,
                  enableVoice: widget.enableVoice,
                  enableAttachments: widget.enableAttachments,
                  acceptedExtensions: widget.acceptedAttachmentExtensions,
                  actionBar: widget.inputActionBar,
                  leadingActions: widget.inputLeadingActions,
                  trailingActions: widget.inputTrailingActions,
                  onSend: (text, attachments) => _send(text),
                ),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({super.key, required this.message, required this.theme, this.widgetRegistry, this.onWidgetSubmit, this.enabled = false});

  final ChatMessage message;
  final AgThemeData theme;
  final AgUiWidgetRegistry? widgetRegistry;
  final void Function(String response)? onWidgetSubmit;

  /// Whether this message's widget (if any) is still awaiting a response.
  /// When `false`, the widget is rendered read-only (dimmed, inputs ignored) —
  /// it belongs to a resolved or superseded HIL gate.
  final bool enabled;

  /// Wraps an already-resolved/superseded widget so it reads as inert history:
  /// dimmed and unclickable, without needing each widget implementation to know
  /// about gates or track "was I the one that got answered".
  ///
  /// Always wraps with the SAME widget shape regardless of [enabled], only
  /// varying the ignoring/opacity values — conditionally including/excluding
  /// the wrapper (`enabled ? built : IgnorePointer(...)`) changes the widget
  /// type at this Element slot the instant a HIL gate resolves, which forces
  /// Flutter to dispose the old Element (and its State — the typed answer's
  /// TextEditingControllers) and mount a fresh one, so the answer text
  /// silently disappeared right when the form flipped to read-only.
  Widget _dimIfDisabled(Widget built) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(opacity: enabled ? 1.0 : 0.55, child: built),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Widget-sourced HIL responses are persisted for history but not rendered:
    // the interaction widget itself already displays the user's answer.
    if (message.metadata?['interaction.source'] == 'widget') {
      return const SizedBox.shrink();
    }

    final isUser = message.role == ChatMessageRole.user;
    final isSystem = message.role == ChatMessageRole.system;

    // User messages: right-aligned bubble with background, compact spacing.
    if (isUser) {
      final colorScheme = Theme.of(context).colorScheme;
      final bg = theme.bubbleUserColor ?? colorScheme.primaryContainer;
      final textStyle = theme.bubbleUserTextStyle;
      return Align(
        alignment: Alignment.centerRight,
        child: Container(margin: const EdgeInsets.symmetric(vertical: 2), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(theme.bubbleRadius)), child: Text(message.text, style: textStyle)),
      );
    }

    // System messages: subtle italicised label, no background.
    if (isSystem) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(message.text, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurfaceVariant)));
    }

    // Multi-block messages (e.g. interact_with_human: intro text + a widget in one call).
    // Rendered front-to-back in a single bubble — text blocks as markdown, widget blocks
    // through the same registry/submit wiring as standalone widget messages below.
    final blocks = message.blocks;
    if (blocks != null && blocks.isNotEmpty) {
      final textStyle = theme.bubbleAgentTextStyle;
      final textColor = textStyle?.color ?? Theme.of(context).colorScheme.onSurface;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final block in blocks)
              if (block.type == 'text')
                if ((block.text ?? '').isNotEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: AgUiMarkdownBody(data: block.text!, textColor: textColor, textStyle: textStyle))
                else
                  const SizedBox.shrink()
              else if (widgetRegistry != null)
                Builder(
                  builder: (context) {
                    final props = {
                      ...?block.widgetProps,
                      if (onWidgetSubmit != null) '__onSubmit': onWidgetSubmit,
                    };
                    final built = widgetRegistry!.build(context, block.type, props);
                    if (built == null) return const SizedBox.shrink();
                    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: _dimIfDisabled(built));
                  },
                ),
          ],
        ),
      );
    }

    // Widget messages: agent produced an artifact (e.g. BarChart, StatusCard).
    // The widgetType and widgetProps are stored in message.metadata by ChatController.
    final widgetType = message.metadata?['widgetType'] as String?;
    if (widgetType != null && widgetRegistry != null) {
      final rawProps = message.metadata?['widgetProps'];
      final baseProps = rawProps is Map<String, dynamic>
          ? rawProps
          : rawProps is Map
              ? Map<String, dynamic>.from(rawProps)
              : <String, dynamic>{};
      // Inject the submit callback so interactive widgets (QuestionForm, ChoiceCard,
      // ConfirmCard) can send their response back via onHilResponse.
      final props = {
        ...baseProps,
        if (onWidgetSubmit != null) '__onSubmit': onWidgetSubmit,
      };
      final built = widgetRegistry!.build(context, widgetType, props);
      if (built != null) {
        return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: _dimIfDisabled(built));
      }
    }

    // Assistant messages: plain text / markdown, no box, left-aligned.
    final textStyle = theme.bubbleAgentTextStyle;
    final textColor = textStyle?.color ?? Theme.of(context).colorScheme.onSurface;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: message.text.isNotEmpty ? AgUiMarkdownBody(data: message.text, textColor: textColor, textStyle: textStyle) : const SizedBox.shrink());
  }
}

/// Deprecated name for [AgUiChatDiscussion] — "Panel" undersold that this widget
/// already orchestrates both the message list and the composer as one component.
/// Kept as a source-compatible alias; migrate to [AgUiChatDiscussion] directly.
@Deprecated('Renamed to AgUiChatDiscussion — same widget, clearer name.')
typedef AgUiChatPanel = AgUiChatDiscussion;
