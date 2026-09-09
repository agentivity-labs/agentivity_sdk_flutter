class ChatThreadSummary {
  const ChatThreadSummary({
    required this.threadId,
    required this.contextId,
    required this.runId,
    required this.title,
    required this.isDefault,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String threadId;
  final String contextId;
  final String runId;
  final String title;
  final bool isDefault;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ChatThreadSummary.fromJson(Map<String, dynamic> json) {
    return ChatThreadSummary(
      threadId: _readString(json, 'id'),
      contextId: _readString(json, 'contextId'),
      runId: _readString(json, 'runId'),
      title: _readString(json, 'title'),
      isDefault: _readBool(json, 'isDefault'),
      status: _readString(json, 'status'),
      createdAt: _readOptionalDateTime(json, 'createdAt'),
      updatedAt: _readOptionalDateTime(json, 'updatedAt'),
    );
  }
}

/// A thread with its full message history — pairs [InteractionThread] with its
/// [ThreadMessage] list.
class InteractionThreadDetail {
  const InteractionThreadDetail({
    required this.thread,
    required this.messages,
  });

  final InteractionThread thread;
  final List<ThreadMessage> messages;
}

String _readString(Map<String, dynamic> json, String key) {
  final raw = _get(json, key);
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  if (raw != null) {
    final coerced = raw.toString().trim();
    if (coerced.isNotEmpty) {
      return coerced;
    }
  }
  return '';
}

String? _readOptional(Map<String, dynamic> json, String key) {
  final raw = _get(json, key);
  if (raw == null) {
    return null;
  }
  final value = raw.toString().trim();
  return value.isEmpty ? null : value;
}

bool _readBool(Map<String, dynamic> json, String key) {
  final raw = _get(json, key);
  if (raw is bool) {
    return raw;
  }
  if (raw is num) {
    return raw != 0;
  }
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  return false;
}

DateTime? _readOptionalDateTime(Map<String, dynamic> json, String key) {
  final raw = _get(json, key);
  if (raw == null) {
    return null;
  }
  if (raw is DateTime) {
    return raw.toUtc();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw.trim())?.toUtc();
  }
  return null;
}

Map<String, dynamic>? _readOptionalMap(Map<String, dynamic> json, String key) {
  final raw = _get(json, key);
  if (raw is Map<String, dynamic>) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return null;
}

dynamic _get(Map<String, dynamic> json, String key) {
  if (json.containsKey(key)) {
    return json[key];
  }
  final lower = key.toLowerCase();
  for (final entry in json.entries) {
    if (entry.key.toLowerCase() == lower) {
      return entry.value;
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Interaction thread models — new interaction contract
// Source: GET /api/v1/executions/{executionId}/threads
//         GET /api/v1/executions/{executionId}/threads/{threadId}/messages
// ─────────────────────────────────────────────────────────────────────────────

/// Author type enum for messages in interaction threads.
enum ThreadAuthorType {
  user,
  agent,
  WorkflowEntity,
  system,
  unknown;

  factory ThreadAuthorType.fromRaw(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'user':
        return ThreadAuthorType.user;
      case 'agent':
        return ThreadAuthorType.agent;
      case 'workflow':
        return ThreadAuthorType.WorkflowEntity;
      case 'system':
        return ThreadAuthorType.system;
      default:
        return ThreadAuthorType.unknown;
    }
  }

  String get label {
    switch (this) {
      case ThreadAuthorType.user:
        return 'User';
      case ThreadAuthorType.agent:
        return 'Agent';
      case ThreadAuthorType.WorkflowEntity:
        return 'WorkflowEntity';
      case ThreadAuthorType.system:
        return 'System';
      case ThreadAuthorType.unknown:
        return 'Unknown';
    }
  }
}

/// A thread scoped to an execution (replaces the old context-scoped ChatThreadSummary).
class InteractionThread {
  const InteractionThread({
    required this.threadId,
    required this.executionId,
    this.runId,
    required this.title,
    required this.isDefault,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String threadId;
  final String executionId;
  final String? runId;
  final String title;
  final bool isDefault;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory InteractionThread.fromJson(Map<String, dynamic> json) {
    return InteractionThread(
      threadId: _readString(json, 'threadId'),
      executionId: _readString(json, 'executionId'),
      runId: _readOptional(json, 'runId'),
      title: _readString(json, 'title'),
      isDefault: _readBool(json, 'isDefault'),
      status: _readString(json, 'status'),
      createdAt: _readOptionalDateTime(json, 'createdAt'),
      updatedAt: _readOptionalDateTime(json, 'updatedAt'),
    );
  }
}

/// A message within an interaction thread.
class ThreadMessage {
  const ThreadMessage({
    required this.messageId,
    required this.threadId,
    this.runId,
    required this.authorType,
    this.authorId,
    this.authorName,
    required this.text,
    this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  final String messageId;
  final String threadId;
  final String? runId;
  final ThreadAuthorType authorType;
  final String? authorId;
  final String? authorName;
  final String text;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  factory ThreadMessage.fromJson(Map<String, dynamic> json) {
    return ThreadMessage(
      messageId: _readString(json, 'messageId'),
      threadId: _readString(json, 'threadId'),
      runId: _readOptional(json, 'runId'),
      authorType: ThreadAuthorType.fromRaw(_readString(json, 'authorType')),
      authorId: _readOptional(json, 'authorId'),
      authorName: _readOptional(json, 'authorName'),
      text: _readString(json, 'text'),
      createdAt: _readOptionalDateTime(json, 'createdAt'),
      updatedAt: _readOptionalDateTime(json, 'updatedAt'),
      metadata: _readOptionalMap(json, 'metadata'),
    );
  }
}
