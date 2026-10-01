import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../protocol/ag_ui_protocol.dart';
import '../../protocol/api_contract.dart';
import 'chat_models.dart';
import 'i_chat_provider.dart';

/// Controls the state of an [AgUiChatDiscussion].
///
/// ## Pull-based (REST)
///
/// The classic mode: provide an [IChatProvider] and call [loadThreads].
///
/// ```dart
/// final controller = ChatController(
///   provider: MyRestChatProvider(),
///   contextId: runId,
/// );
/// controller.loadThreads();
/// ```
///
/// ## Push-based (AG-UI events)
///
/// Preferred for real-time backends: provide a [Stream<AgUiEvent>] and the
/// controller drives itself from SSE events — no polling needed.
///
/// ```dart
/// final controller = ChatController.fromStream(
///   events: sseChannel.stream,
///   contextId: runId,
/// );
/// ```
///
/// You can also mix both: provide [provider] for the initial load and
/// [events] for live updates.
///
/// ## Supported AG-UI events
///
/// | Event | Effect |
/// |---|---|
/// | `CUSTOM(CHAT_THREAD_CREATED)` | Adds / upserts the thread |
/// | `CUSTOM(CHAT_MESSAGE_RECEIVED)` | Appends a message to its thread |
/// | `CUSTOM(CHAT_HIL_GATE_REACHED)` | Sets [pendingHilGate] |
/// | `CUSTOM(CHAT_HIL_RESOLVED)` | Clears [pendingHilGate] |
/// | `TEXT_MESSAGE_START/CONTENT/END` | Streams an assistant message into the active thread |
/// | `RunFinishedEvent(interrupted, reason:'chat_hil_gate')` | Sets [pendingHilGate] from the interrupt |
/// | `StepStartedEvent`/`StepFinishedEvent` (Team member identity present) | Sets/clears [activeMember], updates [memberStatuses] |
///
/// ## Injecting events manually
///
/// Use [feedEvent] to push any [AgUiEvent] into the controller from an
/// external source (e.g. a shared SSE channel that carries multiple event types).
///
/// ```dart
/// sseChannel.stream.listen((raw) {
///   if (raw is AgUiEvent) controller.feedEvent(raw);
/// });
/// ```
/// Where a Team member stands in the conversation, from its own `StepStartedEvent`/`StepFinishedEvent`:
/// [working] while it takes its turn, [waiting] if the run paused (a human question) while it was mid-turn,
/// [done] once its turn ended. A member that has not appeared yet has no entry.
enum TeamMemberStatus { working, waiting, done, failed }

/// Where a Workflow node stands in the run, from its own `StepStartedEvent`/`StepFinishedEvent`'s
/// `stepName` (the node's id) — same three states as [TeamMemberStatus], kept as its own type
/// since the two are unrelated concepts that happen to share a shape. A node not reached yet has
/// no entry.
enum WorkflowStepStatus { working, waiting, done, failed }

/// The Team member currently taking its turn — set from [StepStartedEvent], cleared on [StepFinishedEvent].
class ActiveChatMember {
  const ActiveChatMember({this.memberEntityId, this.displayName});
  final String? memberEntityId;
  final String? displayName;
}

class ChatController extends ChangeNotifier {
  /// Pull-based constructor: delegates to [provider] for all data.
  ChatController({required IChatProvider provider, required String contextId})
    : _provider = provider,
      _contextId = contextId;

  /// Push-based constructor: state is driven entirely by [events].
  ///
  /// [provider] is optional — when provided it is used for [sendMessage] and
  /// the initial [loadThreads] call. Omit it when the backend is purely
  /// event-driven and responses are sent via an [onHilResponse] callback on
  /// the panel.
  ChatController.fromStream({
    required Stream<AgUiEvent> events,
    IChatProvider? provider,
    String contextId = '',
  }) : _provider = provider ?? const NullChatProvider(),
       _contextId = contextId {
    _eventSub = events.listen(
      _onAgUiEvent,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  final IChatProvider _provider;
  final String _contextId;
  StreamSubscription<AgUiEvent>? _eventSub;

  List<ChatThread> _threads = const [];
  // thread-id → messages list
  final Map<String, List<ChatMessage>> _messagesByThread = {};
  // message-id → in-progress text (for TEXT_MESSAGE_START/CONTENT/END)
  final Map<String, StringBuffer> _inProgress = {};
  // message-id → threadId (to route TEXT_MESSAGE_CONTENT to the right thread)
  final Map<String, String> _inProgressThreadId = {};

  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  ChatHilGate? _pendingHilGate;
  bool _isAwaitingResponse = false;
  ActiveChatMember? _activeMember;
  Map<String, TeamMemberStatus> _memberStatuses = const {};
  Map<String, WorkflowStepStatus> _stepStatuses = const {};

  List<ChatThread> get threads => _threads;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get contextId => _contextId;

  /// True while the agent/workflow run is processing and hasn't yet produced
  /// a reply or a HIL gate.
  ///
  /// Driven entirely by AG-UI SSE events ([RunStartedEvent] sets it, any
  /// terminal event or HIL gate clears it) — no polling required. Reflects in
  /// [AgUiChatInput]'s loading indicator via [AgUiChatDiscussion]'s default input,
  /// and is available to custom [AgUiChatDiscussion.inputBuilder]s too.
  bool get isAwaitingResponse => _isAwaitingResponse;

  /// Set when a `CHAT_HIL_GATE_REACHED` event or an AG-UI interrupt with
  /// `reason == 'chat_hil_gate'` is received. Cleared by [clearHilGate].
  ChatHilGate? get pendingHilGate => _pendingHilGate;

  /// The Team member currently taking its turn, or `null` when nobody is (a
  /// standalone Agent run, or between turns). Powers `AgUiChatActiveMemberIndicator`.
  ActiveChatMember? get activeMember => _activeMember;

  /// Status of every Team member seen so far, keyed by `memberEntityId` — empty for a standalone Agent.
  /// Powers `AgUiTeamRoster` and `AgUiTeamGraph`. A new unmodifiable map on every change.
  Map<String, TeamMemberStatus> get memberStatuses => _memberStatuses;

  /// Status of every Workflow node reached so far, keyed by `stepName` (its node id) — empty for
  /// a Team/Agent run. Powers `AgUiWorkflowGraph`. A new unmodifiable map on every change.
  Map<String, WorkflowStepStatus> get stepStatuses => _stepStatuses;

  void _setMemberStatus(String memberEntityId, TeamMemberStatus status) {
    _memberStatuses = Map.unmodifiable({
      ..._memberStatuses,
      memberEntityId: status,
    });
  }

  void _setStepStatus(String stepName, WorkflowStepStatus status) {
    _stepStatuses = Map.unmodifiable({..._stepStatuses, stepName: status});
  }

  // A run that ends mid-turn leaves its member 'working' with nothing to show for it: paused on a human
  // question it is 'waiting', otherwise (finished, errored) its turn is over.
  void _settleWorkingMembers({required bool interrupted}) {
    if (!_memberStatuses.containsValue(TeamMemberStatus.working)) return;
    _memberStatuses = Map.unmodifiable({
      for (final entry in _memberStatuses.entries)
        entry.key:
            entry.value == TeamMemberStatus.working
                ? (interrupted
                    ? TeamMemberStatus.waiting
                    : TeamMemberStatus.done)
                : entry.value,
    });
  }

  /// Same idea as [_settleWorkingMembers], for [_stepStatuses].
  void _settleWorkingSteps({required bool interrupted}) {
    if (!_stepStatuses.containsValue(WorkflowStepStatus.working)) return;
    _stepStatuses = Map.unmodifiable({
      for (final entry in _stepStatuses.entries)
        entry.key:
            entry.value == WorkflowStepStatus.working
                ? (interrupted
                    ? WorkflowStepStatus.waiting
                    : WorkflowStepStatus.done)
                : entry.value,
    });
  }

  List<ChatThread> get filteredThreads {
    if (_searchQuery.isEmpty) return _threads;
    final q = _searchQuery.toLowerCase();
    return _threads
        .where(
          (t) =>
              t.threadId.toLowerCase().contains(q) ||
              t.title.toLowerCase().contains(q) ||
              t.status.toLowerCase().contains(q),
        )
        .toList();
  }

  // ── Push-based event handling ──────────────────────────────────────────────

  /// Injects an [AgUiEvent] into the controller.
  ///
  /// Call this when you manage your own SSE channel and want to forward
  /// relevant events without rewiring [fromStream].
  void feedEvent(AgUiEvent event) => _onAgUiEvent(event);

  /// Directly registers [thread] without a network call.
  void addThread(ChatThread thread) {
    final idx = _threads.indexWhere((t) => t.threadId == thread.threadId);
    if (idx >= 0) {
      final updated = List<ChatThread>.from(_threads);
      updated[idx] = thread;
      _threads = updated;
    } else {
      _threads = [..._threads, thread];
    }
    notifyListeners();
  }

  /// Appends [message] to [threadId]'s local message list.
  void addMessage({required String threadId, required ChatMessage message}) {
    final existing = List<ChatMessage>.from(_messagesByThread[threadId] ?? []);
    final idx = existing.indexWhere((m) => m.id == message.id);
    if (idx >= 0) {
      existing[idx] = message;
    } else {
      existing.add(message);
    }
    _messagesByThread[threadId] = existing;
    notifyListeners();
  }

  /// Returns locally-cached messages for [threadId].
  List<ChatMessage> localMessages(String threadId) =>
      List.unmodifiable(_messagesByThread[threadId] ?? []);

  /// Directly sets the pending HIL gate.
  ///
  /// Use this when the HIL signal arrives through an external channel
  /// (e.g. an `isAwaitingHil` flag from a Riverpod provider) rather than
  /// via a fed AG-UI event.
  void setHilGate(ChatHilGate gate) {
    _pendingHilGate = gate;
    notifyListeners();
  }

  /// Clears [pendingHilGate].
  void clearHilGate() {
    if (_pendingHilGate == null) return;
    _pendingHilGate = null;
    notifyListeners();
  }

  /// Resets all conversation state — threads, messages, HIL gate, error.
  /// Use when starting a new execution so the panel shows a clean slate
  /// without disposing and recreating the controller (which would break listeners).
  void clear() {
    _threads = const [];
    _messagesByThread.clear();
    _pendingHilGate = null;
    _isAwaitingResponse = false;
    _activeMember = null;
    _memberStatuses = const {};
    _stepStatuses = const {};
    _errorMessage = null;
    _inProgressThreadId.clear();
    notifyListeners();
  }

  void _onAgUiEvent(AgUiEvent event) {
    switch (event) {
      // ── Run lifecycle → drive isAwaitingResponse ────────────────────────
      case RunStartedEvent _:
        _isAwaitingResponse = true;
        notifyListeners();

      case RunFinishedEvent e:
        _isAwaitingResponse = false;
        _activeMember = null;
        _settleWorkingMembers(interrupted: e.isInterrupted);
        _settleWorkingSteps(interrupted: e.isInterrupted);
        if (e.isInterrupted) {
          final interrupts = (e.outcome as AgUiInterruptOutcome).interrupts;
          for (final interrupt in interrupts) {
            if (interrupt.reason == 'chat_hil_gate' ||
                interrupt.reason.startsWith('chat')) {
              final meta = interrupt.metadata ?? {};
              _pendingHilGate = ChatHilGate(
                requestId: interrupt.id,
                threadId: (meta['threadId'] as String? ?? '').trim(),
                question: interrupt.message ?? interrupt.reason,
                title: (meta['title'] as String? ?? 'Input required').trim(),
              );
              break;
            }
          }
        }
        notifyListeners();

      case RunErrorEvent _:
        _isAwaitingResponse = false;
        _activeMember = null;
        _settleWorkingMembers(interrupted: false);
        _settleWorkingSteps(interrupted: false);
        notifyListeners();

      // ── CUSTOM events ───────────────────────────────────────────────────
      case CustomEvent e:
        _handleCustomEvent(e);

      // ── Turn boundaries → drive activeMember (Team runs only — needs member
      // identity) and stepStatuses (any run — stepName is always present, so this
      // fires for a Workflow's node-by-node progress too, not just Team turns). ──
      case StepStartedEvent e:
        if (e.stepName.isNotEmpty)
          _setStepStatus(e.stepName, WorkflowStepStatus.working);
        var changedMember = false;
        if (e.memberEntityId != null || e.displayName != null) {
          _activeMember = ActiveChatMember(
            memberEntityId: e.memberEntityId,
            displayName: e.displayName,
          );
          if (e.memberEntityId != null)
            _setMemberStatus(e.memberEntityId!, TeamMemberStatus.working);
          changedMember = true;
        }
        if (e.stepName.isNotEmpty || changedMember) notifyListeners();

      case StepFinishedEvent e:
        if (e.stepName.isNotEmpty)
          _setStepStatus(e.stepName, WorkflowStepStatus.done);
        final hadActiveMember = _activeMember != null || e.memberEntityId != null;
        if (hadActiveMember) {
          _activeMember = null;
          if (e.memberEntityId != null)
            _setMemberStatus(e.memberEntityId!, TeamMemberStatus.done);
        }
        if (e.stepName.isNotEmpty || hadActiveMember) notifyListeners();

      // ── Streaming text messages → accumulate into thread ────────────────
      case TextMessageStartEvent e:
        // Associate the in-progress message with the active thread (last thread).
        final threadId =
            _pendingHilGate?.threadId ?? _threads.lastOrNull?.threadId;
        if (threadId != null) {
          _inProgress[e.messageId] = StringBuffer();
          _inProgressThreadId[e.messageId] = threadId;
        }

      case TextMessageContentEvent e:
        _inProgress[e.messageId]?.write(e.delta);
        notifyListeners();

      case TextMessageChunkEvent e:
        if (e.messageId != null && e.delta != null) {
          _inProgress
              .putIfAbsent(e.messageId!, StringBuffer.new)
              .write(e.delta);
          notifyListeners();
        }

      case TextMessageEndEvent e:
        final buffer = _inProgress.remove(e.messageId);
        final threadId = _inProgressThreadId.remove(e.messageId);
        if (buffer != null && threadId != null && buffer.isNotEmpty) {
          addMessage(
            threadId: threadId,
            message: ChatMessage(
              id: e.messageId,
              role: ChatMessageRole.assistant,
              contextId: _contextId,
              threadId: threadId,
              runId: '',
              text: buffer.toString(),
              createdAt: DateTime.now(),
            ),
          );
        }

      default:
        break;
    }
  }

  void _handleCustomEvent(CustomEvent event) {
    final value = event.value;
    final data =
        value is Map<String, dynamic>
            ? value
            : value is Map
            ? Map<String, dynamic>.from(value)
            : const <String, dynamic>{};

    switch (event.name) {
      case 'CHAT_THREAD_CREATED':
        final threadId = (data['threadId'] as String? ?? '').trim();
        if (threadId.isEmpty) return;
        addThread(
          ChatThread(
            threadId: threadId,
            contextId: _contextId,
            runId: (data['runId'] as String? ?? '').trim(),
            title: (data['title'] as String? ?? '').trim(),
            isDefault: data['isDefault'] as bool? ?? false,
            status: (data['status'] as String? ?? 'active').trim(),
          ),
        );

      case 'CHAT_MESSAGE_RECEIVED':
        final threadId = (data['threadId'] as String? ?? '').trim();
        final messageId = (data['messageId'] as String? ?? '').trim();
        if (threadId.isEmpty || messageId.isEmpty) return;
        // Auto-create the thread if a CHAT_THREAD_CREATED was never received.
        if (!_threads.any((t) => t.threadId == threadId)) {
          addThread(
            ChatThread(
              threadId: threadId,
              contextId: _contextId,
              runId: (data['runId'] as String? ?? '').trim(),
              title: '',
              isDefault: true,
              status: 'active',
            ),
          );
        }
        addMessage(
          threadId: threadId,
          message: ChatMessage(
            id: messageId,
            role: ChatMessageRole.fromRaw(
              data['role'] as String? ?? 'assistant',
            ),
            contextId: _contextId,
            threadId: threadId,
            runId: (data['runId'] as String? ?? '').trim(),
            text: (data['text'] as String? ?? '').trim(),
            blocks: ChatContentBlock.listFromRaw(data['blocks']),
            authorId: data['memberEntityId'] as String?,
            authorName: data['displayName'] as String?,
            metadata:
                data['source'] is String
                    ? {'interaction.source': data['source']}
                    : null,
            createdAt: DateTime.now(),
          ),
        );

      case 'CHAT_HIL_GATE_REACHED':
      // Also tolerate the legacy name used in agentivity_studio, but only
      // when the channelType is chat or unspecified (forms HIL uses forms channel).
      case 'HIL_GATE_REACHED':
        final requestId = (data['requestId'] as String? ?? '').trim();
        final threadId = (data['threadId'] as String? ?? '').trim();
        final channelType =
            (data['channelType'] as String? ?? '').trim().toLowerCase();
        if (requestId.isEmpty) return;
        // Skip HIL gates for non-chat channels (e.g. "forms") — they are handled by their own UI.
        if (channelType.isNotEmpty && channelType != 'chat') return;
        // The widget itself (if any) already arrived as its own CUSTOM event and is rendered
        // via the widget registry (see the `default` branch below) — this gate only records
        // which request/thread a widget's `__onSubmit` (or a plain-text reply) should resume.
        _pendingHilGate = ChatHilGate(
          requestId: requestId,
          threadId: threadId,
          question:
              (data['question'] as String? ?? data['message'] as String? ?? '')
                  .trim(),
          title: (data['title'] as String? ?? 'Input required').trim(),
        );
        _isAwaitingResponse = false;

        notifyListeners();

      case 'CHAT_HIL_RESOLVED':
        clearHilGate();

      default:
        // Any CUSTOM event that is not a CHAT_* / HIL_* control event is treated
        // as a widget invocation from the agent. Store it as a ChatMessage so the
        // panel can render it via the widget registry.
        if (!event.name.startsWith('CHAT_') && !event.name.startsWith('HIL_')) {
          final threadId =
              _pendingHilGate?.threadId ?? _threads.lastOrNull?.threadId;
          if (threadId != null) {
            final props =
                value is Map<String, dynamic>
                    ? value
                    : value is Map
                    ? Map<String, dynamic>.from(value)
                    : <String, dynamic>{};
            addMessage(
              threadId: threadId,
              message: ChatMessage(
                id: '${event.name}_${DateTime.now().millisecondsSinceEpoch}',
                role: ChatMessageRole.assistant,
                contextId: _contextId,
                threadId: threadId,
                runId: '',
                text: '',
                metadata: {'widgetType': event.name, 'widgetProps': props},
                createdAt: DateTime.now(),
              ),
            );
          }
        }
    }
  }

  // ── Pull-based REST operations ─────────────────────────────────────────────

  Future<void> loadThreads({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final loaded = await _provider.listThreads(contextId: _contextId);
      // Merge: keep push-injected threads that REST didn't return.
      final merged = Map<String, ChatThread>.fromEntries(
        _threads.map((t) => MapEntry(t.threadId, t)),
      );
      for (final t in loaded) {
        merged[t.threadId] = t;
      }
      _threads = merged.values.toList();
    } on Object catch (e) {
      debugLogApiIssue(e, operation: 'ChatController.loadThreads');
      _errorMessage = userFacingErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ChatThreadDetail> openThread({required String threadId}) async {
    // Prefer locally cached messages (populated by push events).
    final cached = _messagesByThread[threadId];
    if (cached != null && cached.isNotEmpty) {
      final thread = _threads.firstWhere(
        (t) => t.threadId == threadId,
        orElse:
            () => ChatThread(
              threadId: threadId,
              contextId: _contextId,
              runId: '',
              title: '',
              isDefault: false,
              status: 'active',
            ),
      );
      return ChatThreadDetail(thread: thread, messages: cached);
    }
    // Fall back to REST.
    final thread = await _provider.fetchThread(
      contextId: _contextId,
      threadId: threadId,
    );
    final messages = await _provider.listMessages(
      contextId: _contextId,
      threadId: threadId,
    );
    // Push events may have populated the cache while the REST call was in flight.
    // Prefer push messages over REST response to avoid overwriting them.
    if ((_messagesByThread[threadId] ?? []).isEmpty) {
      _messagesByThread[threadId] = messages;
    }
    final finalMessages = _messagesByThread[threadId] ?? messages;
    return ChatThreadDetail(thread: thread, messages: finalMessages);
  }

  Future<List<ChatMessage>> loadMessages({required String threadId}) async {
    final cached = _messagesByThread[threadId];
    if (cached != null && cached.isNotEmpty) return cached;
    final messages = await _provider.listMessages(
      contextId: _contextId,
      threadId: threadId,
    );
    _messagesByThread[threadId] = messages;
    return messages;
  }

  Future<void> sendMessage({
    String? threadId,
    required String text,
    List<ChatAttachment>? attachments,
  }) async {
    await _provider.sendMessage(
      contextId: _contextId,
      threadId: threadId,
      text: text,
      attachments: attachments,
    );
    await loadThreads(forceRefresh: true);
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }
}
