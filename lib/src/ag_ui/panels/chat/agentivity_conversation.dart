import 'dart:async';

import '../../../client/app_client/agentivity_client.dart';
import '../../../client/app_client/domain/chat_models.dart' show ThreadAuthorType;
import '../../../client/app_client/domain/desk_models.dart';
import '../../../client/core/api_contract.dart';
import '../../connectors/agentivity_run_stream.dart';
import '../../protocol/ag_ui_protocol.dart';
import 'attachment_images.dart';
import 'chat_controller.dart';
import 'chat_models.dart';
import 'i_chat_provider.dart';

/// One conversation with an agent, a team or a workflow of the workspace: what an agent, a team or a workflow says, in the chat of the SDK. Its first message starts
/// the execution; every next one goes on with it. A conversation opened again gets its stored messages back, then follows
/// its stream.
///
/// A team or a workflow keeps its conversation (its threads, sent on the stream as they are written). An agent alone keeps
/// only its answer, on its run: the Desk writes what the person said and puts the answer under it when the run ends.
class AgentivityConversation implements IChatProvider {
  AgentivityConversation({required this.client, required this.entityId, required this.entityKind, this.executionId, this.onStarted}) {
    chat = ChatController(provider: this, contextId: executionId ?? entityId);
  }

  final AgentivityClient client;
  final String entityId;

  /// Told once the first message has started the execution, with its id.
  final void Function(String executionId)? onStarted;

  /// `agent`, `team` or `workflow`.
  final String entityKind;
  late final ChatController chat;

  bool get _alone => entityKind == 'agent';

  int _written = 0;

  /// Null until the first message starts it.
  String? executionId;

  /// Whether the caller may write in it: not in a conversation shared to read only, nor in one of someone else's where only a
  /// question is asked to them.
  bool mayWrite = true;

  AgentivityRunStream? _stream;
  StreamSubscription<AgUiEvent>? _events;
  String? _followed;

  /// Puts back what an existing conversation said, then follows it while it goes on. [asked] is the question it was opened
  /// for, to answer it there.
  Future<void> reopen({bool mayWrite = true, DeskQuestion? asked}) async {
    final id = executionId;
    if (id == null) return;
    this.mayWrite = mayWrite;
    final threads = await client.conversations.fetchExecutionThreads(id);
    for (final thread in threads) {
      chat.addThread(ChatThread(threadId: thread.threadId, contextId: chat.contextId, runId: thread.runId ?? '', title: thread.title, isDefault: thread.isDefault, status: thread.status));
      final messages = await client.conversations.fetchExecutionThreadMessages(executionId: id, threadId: thread.threadId);
      for (final message in messages) {
        chat.addMessage(
          threadId: thread.threadId,
          message: ChatMessage(
            id: message.messageId,
            role: message.authorType == ThreadAuthorType.user ? ChatMessageRole.user : ChatMessageRole.assistant,
            contextId: chat.contextId,
            threadId: message.threadId,
            runId: message.runId ?? '',
            text: message.text,
            authorId: message.authorId,
            authorName: message.authorName,
            metadata: message.metadata,
            createdAt: message.createdAt,
            updatedAt: message.updatedAt,
          ),
        );
      }
      // Its last message still waits for an answer: it may be answered again.
      final last = messages.lastOrNull?.metadata;
      final requestId = last?['interaction.request_id']?.toString() ?? '';
      if (asked == null && mayWrite && chat.pendingHilGate == null && last?['interaction.awaiting_response'] == true && requestId.isNotEmpty) {
        chat.setHilGate(ChatHilGate(requestId: requestId, threadId: thread.threadId, question: messages.last.text, title: 'Your answer'));
      }
    }
    // An agent alone from before its conversation was kept: its last answer, kept on its run.
    if (threads.isEmpty && _alone) {
      final run = await client.runs.fetchRun(id);
      _write(ChatMessageRole.assistant, run.content ?? run.error ?? '');
    }
    if (asked != null && chat.pendingHilGate?.requestId != asked.requestId) {
      final thread = threads.where((t) => t.isDefault).firstOrNull ?? threads.firstOrNull;
      chat.setHilGate(ChatHilGate(requestId: asked.requestId, threadId: thread?.threadId ?? chat.ownThread(), question: asked.question ?? asked.title ?? '', title: asked.title ?? (asked.askedToYou ? 'Your approval' : 'Your answer')));
    }

    final execution = await client.runs.fetchExecution(id);
    final streamId = execution?.streamId;
    if (execution != null && streamId != null && !execution.ended) {
      _follow('/api/v1/streams/$streamId/events');
    }
  }

  /// Answers the question [gate] of the conversation.
  Future<void> answer(ChatHilGate gate, String text, String source) async {
    final id = executionId;
    if (id == null) return;
    await client.runs.submitHilResponse(executionId: id, requestId: gate.requestId, response: text, source: source);
  }

  void _follow(String streamUrl) {
    if (_followed == streamUrl) return;
    _followed = streamUrl;
    _events?.cancel();
    _stream?.dispose();
    // The platform's own stream, not a bare channel: it replays to whoever listens late, stops reconnecting once the run has
    // really ended, and knows the workspace's own frames.
    final stream = AgentivityRunStream(opener: client.runs.openEventStream, path: streamUrl);
    _stream = stream;
    _events = stream.agUiEvents.listen(_onEvent, onError: (Object _) {}, onDone: chat.streamEnded, cancelOnError: false);
    stream.start();
  }

  void _onEvent(AgUiEvent event) {
    chat.feedEvent(event);
    if (!_alone) return;
    switch (event) {
      // The agent asks something: the answer goes back to its run.
      case RunFinishedEvent(:final AgUiInterruptOutcome outcome) when outcome.interrupts.isNotEmpty:
        final asked = outcome.interrupts.first;
        if (chat.pendingHilGate?.requestId != asked.id) {
          final title = asked.metadata?['title']?.toString();
          _write(ChatMessageRole.assistant, asked.message ?? title ?? '');
          chat.setHilGate(ChatHilGate(requestId: asked.id, threadId: chat.threads.where((t) => t.isDefault).firstOrNull?.threadId ?? chat.ownThread(), question: asked.message ?? '', title: title ?? 'Your answer'));
        }
      case RunFinishedEvent(:final runId):
        _answerOf(runId);
      case RunErrorEvent():
        _answerOf(null);
      case _:
        break;
    }
  }

  Future<void> _answerOf(String? runId) async {
    final id = (runId == null || runId.isEmpty) ? executionId : runId;
    if (id == null) return;
    try {
      final run = await client.runs.fetchRun(id);
      _write(ChatMessageRole.assistant, run.content ?? run.error ?? '');
    } on Object catch (error) {
      _write(ChatMessageRole.assistant, userFacingErrorMessage(error));
    }
  }

  /// Writes a message of an agent alone in the conversation shown: the one the workspace keeps (opened again), or one of the Desk's
  /// until the workspace has it (the next opening reads it from there).
  void _write(ChatMessageRole role, String text) {
    if (text.trim().isEmpty) return;
    final thread = chat.threads.where((t) => t.isDefault).firstOrNull?.threadId ?? chat.ownThread();
    _written++;
    chat.addMessage(
      threadId: thread,
      message: ChatMessage(id: 'written-$_written', role: role, contextId: chat.contextId, threadId: thread, runId: executionId ?? '', text: text, createdAt: DateTime.now()),
    );
  }



  // ── IChatProvider: what the chat of the SDK asks ─────────────────────────────

  // The conversation comes from its stream (and from [reopen]): the chat lists nothing of its own.
  @override
  Future<List<ChatThread>> listThreads({required String contextId}) async => const [];

  @override
  Future<ChatThread> fetchThread({required String contextId, required String threadId}) async =>
      ChatThread(threadId: threadId, contextId: contextId, runId: '', title: '', isDefault: true, status: 'active', createdAt: DateTime.now());

  @override
  Future<List<ChatMessage>> listMessages({required String contextId, required String threadId}) async => const [];

  /// Starts a workflow without a message: it asks what it needs itself (its forms, in the conversation).
  Future<void> startWithoutMessage() async {
    final started = await client.runs.startExecution(entityId: entityId, input: '', enableHil: true);
    _started(started.executionId);
    if (started.streamUrl.isNotEmpty) _follow(started.streamUrl);
  }

  void _started(String id) {
    final first = executionId == null;
    executionId = id;
    if (first) onStarted?.call(id);
  }

  /// Stops what it is doing now.
  Future<void> stop() async {
    final id = executionId;
    if (id != null) await client.runs.cancelExecution(id);
  }

  /// The first message starts the execution; the next ones go on with it. The workspace writes each in the conversation of a
  /// team or a workflow and sends it back on the stream; for an agent alone, it is written here.
  @override
  Future<void> sendMessage({required String contextId, String? threadId, required String text, List<ChatAttachment>? attachments}) async {
    await send(text, files: await filesForARun(client, attachments ?? const []));
  }

  /// Sends [text], with [files] (their ids, uploaded first) or [images] (sent as they are): the first message starts the
  /// execution, the next ones go on with it. An agent, a team and a workflow are all given them.
  Future<void> send(String text, {List<Map<String, String>>? images, List<String>? files}) async {
    if (_alone) _write(ChatMessageRole.user, text);
    final started = await client.runs.startExecution(entityId: entityId, input: text, executionId: executionId, enableHil: true, images: images == null || images.isEmpty ? null : images, files: files == null || files.isEmpty ? null : files);
    _started(started.executionId);
    if (started.streamUrl.isNotEmpty) _follow(started.streamUrl);
  }



  void dispose() {
    _events?.cancel();
    _stream?.dispose();
    chat.dispose();
  }
}
