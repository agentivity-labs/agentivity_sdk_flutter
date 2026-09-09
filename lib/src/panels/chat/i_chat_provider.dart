import 'chat_models.dart';

/// Generic chat provider — implement this against any backend.
abstract interface class IChatProvider {
  Future<List<ChatThread>> listThreads({required String contextId});
  Future<ChatThread> fetchThread({required String contextId, required String threadId});
  Future<List<ChatMessage>> listMessages({required String contextId, required String threadId});

  /// Send a message, optionally with [attachments].
  ///
  /// Implementations should convert [ChatAttachment] subtypes to whatever
  /// format the backend expects (e.g. [ImageUrlAttachment] → `image_url` content
  /// part, [ImageBytesAttachment] → base64 data URI, [FileAttachment] → file ID).
  Future<void> sendMessage({required String contextId, String? threadId, required String text, List<ChatAttachment>? attachments});
}

/// No-op provider used by [ChatController.fromStream] when no REST backend is
/// needed. All read methods return empty results; [sendMessage] is a no-op.
///
/// Replace with a real implementation if you also need REST fallback or
/// message sending via [IChatProvider.sendMessage].
final class NullChatProvider implements IChatProvider {
  const NullChatProvider();

  @override
  Future<List<ChatThread>> listThreads({required String contextId}) async => const [];

  @override
  Future<ChatThread> fetchThread({required String contextId, required String threadId}) async => ChatThread(threadId: threadId, contextId: contextId, runId: '', title: '', isDefault: false, status: 'active', createdAt: DateTime.now());

  @override
  Future<List<ChatMessage>> listMessages({required String contextId, required String threadId}) async => const [];

  @override
  Future<void> sendMessage({required String contextId, String? threadId, required String text, List<ChatAttachment>? attachments}) async {}
}
