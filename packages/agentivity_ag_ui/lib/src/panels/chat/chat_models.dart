import 'dart:typed_data';

import '../../shared/json_helpers.dart';

// ── Attachments ───────────────────────────────────────────────────────────────

/// An attachment that can be sent with a chat message.
///
/// The provider implementation decides how to serialize attachments for the
/// backend. Three concrete subtypes are available:
/// - [ImageUrlAttachment] — image referenced by URL or data URI
/// - [ImageBytesAttachment] — raw image bytes (e.g. from the camera)
/// - [FileAttachment] — file referenced by a backend file ID
sealed class ChatAttachment {
  const ChatAttachment({this.name, this.mimeType});
  final String? name;
  final String? mimeType;
}

/// Image referenced by a URL (`https://`) or data URI (`data:image/jpeg;base64,...`).
final class ImageUrlAttachment extends ChatAttachment {
  const ImageUrlAttachment({required this.url, super.name});
  final String url;
}

/// Raw image bytes — encode as needed in the provider (e.g. to base64 data URI).
final class ImageBytesAttachment extends ChatAttachment {
  ImageBytesAttachment({required this.bytes, super.name, super.mimeType});
  final Uint8List bytes;
}

/// File referenced by a backend-assigned file ID.
final class FileAttachment extends ChatAttachment {
  const FileAttachment({required this.fileId, super.name, super.mimeType});
  final String fileId;
}

// ── Message role ──────────────────────────────────────────────────────────────

enum ChatMessageRole {
  user,
  assistant,
  system,
  tool,
  unknown;

  factory ChatMessageRole.fromRaw(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'user':
        return ChatMessageRole.user;
      case 'assistant':
        return ChatMessageRole.assistant;
      case 'system':
        return ChatMessageRole.system;
      case 'tool':
        return ChatMessageRole.tool;
      default:
        return ChatMessageRole.unknown;
    }
  }
}

class ChatThread {
  const ChatThread({required this.threadId, required this.contextId, required this.runId, required this.title, required this.isDefault, required this.status, this.createdAt, this.updatedAt});

  final String threadId;
  final String contextId;
  final String runId;
  final String title;
  final bool isDefault;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(threadId: jsonStr(json, 'id'), contextId: jsonStr(json, 'contextId'), runId: jsonStr(json, 'runId'), title: jsonStr(json, 'title'), isDefault: jsonBool(json, 'isDefault'), status: jsonStr(json, 'status'), createdAt: jsonDateTime(json, 'createdAt'), updatedAt: jsonDateTime(json, 'updatedAt'));
  }
}

class ChatThreadDetail {
  const ChatThreadDetail({required this.thread, required this.messages});

  final ChatThread thread;
  final List<ChatMessage> messages;
}

// ── HIL gate ──────────────────────────────────────────────────────────────────

/// A pending Human-in-the-Loop gate on a chat thread.
///
/// Set on [ChatController.pendingHilGate] when a `CHAT_HIL_GATE_REACHED` CUSTOM
/// event or an AG-UI interrupt with `reason == 'chat_hil_gate'` is received.
/// Cleared when [ChatController.clearHilGate] is called or a
/// `CHAT_HIL_RESOLVED` event arrives.
class ChatHilGate {
  const ChatHilGate({required this.requestId, required this.threadId, required this.question, required this.title});

  /// Backend HIL request identifier — pass back when submitting the response.
  final String requestId;

  /// The thread this gate belongs to.
  final String threadId;

  /// The question / message shown to the user.
  final String question;

  /// Display title for the gate (e.g. "Approval required").
  final String title;
}

/// One piece of a multi-block chat message — either free text or an AG-UI interaction widget.
/// A message with several blocks renders them in order, in the same bubble (see
/// `_MessageBubble` in `ag_ui_chat_discussion.dart`).
class ChatContentBlock {
  const ChatContentBlock({required this.type, this.text, this.widgetProps});

  /// "text" for a plain-text block, or a widget type key (e.g. "ChoiceCard", "QuestionForm")
  /// resolved through the same `AgUiWidgetRegistry` used for standalone widget messages.
  final String type;
  final String? text;
  final Map<String, dynamic>? widgetProps;

  factory ChatContentBlock.fromJson(Map<String, dynamic> json) {
    final type = ((json['type'] as String?) ?? '').trim();
    if (type == 'text') {
      return ChatContentBlock(type: 'text', text: ((json['text'] as String?) ?? '').trim());
    }
    final props = json['widgetProps'];
    return ChatContentBlock(type: type, widgetProps: props is Map ? Map<String, dynamic>.from(props) : const {});
  }

  /// Parses a raw `blocks` value (from event payload or persisted metadata) into a block list,
  /// or null when absent/empty — callers fall back to the plain `text` field in that case.
  static List<ChatContentBlock>? listFromRaw(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    return raw.whereType<Map>().map((e) => ChatContentBlock.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}

class ChatMessage {
  const ChatMessage({required this.id, required this.role, required this.contextId, required this.threadId, required this.runId, required this.text, this.authorId, this.authorName, this.metadata, this.blocks, this.createdAt, this.updatedAt, this.deletedAt});

  final String id;
  final ChatMessageRole role;
  final String contextId;
  final String threadId;
  final String runId;
  final String text;
  final String? authorId;
  final String? authorName;
  final Map<String, dynamic>? metadata;
  final List<ChatContentBlock>? blocks;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final metadata = jsonMap(json, 'metadata');
    return ChatMessage(
      id: jsonStr(json, 'id'),
      role: ChatMessageRole.fromRaw(jsonStr(json, 'authorType')),
      contextId: jsonStr(json, 'contextId'),
      threadId: jsonStr(json, 'threadId'),
      runId: jsonStr(json, 'runId'),
      text: jsonStr(json, 'text'),
      authorId: jsonOpt(json, 'authorId'),
      authorName: jsonOpt(json, 'authorName'),
      metadata: metadata,
      blocks: ChatContentBlock.listFromRaw(metadata?['blocks']),
      createdAt: jsonDateTime(json, 'createdAt'),
      updatedAt: jsonDateTime(json, 'updatedAt'),
      deletedAt: jsonDateTime(json, 'deletedAt'),
    );
  }
}
