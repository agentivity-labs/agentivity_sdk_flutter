/// Domain models for the Human-in-the-Loop interaction system.
///
/// When a WorkflowEntity node requires human input (approval, form input, choice, or
/// notification), the backend suspends the run and creates an [InteractionRequest].
/// The editor polls for pending requests and displays a dialog so the user can
/// respond. Submitting an [InteractionResponse] via the API automatically
/// resumes the WorkflowEntity.
library;

import 'dart:convert';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// The kind of human interaction expected by the suspended node.
enum InteractionKind {
  /// A form with one or more fields the user must fill in.
  input,

  /// The user must approve, reject, or request changes on reviewed content.
  approval,

  /// The user must pick one option from a list.
  choice,

  /// Informational — no response is expected.
  notification;

  factory InteractionKind.fromApi(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'input':
        return InteractionKind.input;
      case 'approval':
        return InteractionKind.approval;
      case 'choice':
        return InteractionKind.choice;
      case 'notification':
        return InteractionKind.notification;
    }
    return InteractionKind.input;
  }
}

/// The data-type of a single field inside an [InteractionRequest].
enum InteractionFieldType {
  text,
  multilineText,
  number,
  boolean,
  choice,
  date,
  file;

  factory InteractionFieldType.fromApi(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'text':
        return InteractionFieldType.text;
      case 'multilinetext':
        return InteractionFieldType.multilineText;
      case 'number':
        return InteractionFieldType.number;
      case 'boolean':
      case 'bool':
        return InteractionFieldType.boolean;
      case 'choice':
        return InteractionFieldType.choice;
      case 'date':
        return InteractionFieldType.date;
      case 'file':
        return InteractionFieldType.file;
    }
    return InteractionFieldType.text;
  }
}

/// The outcome chosen by the human operator when responding to an interaction.
enum InteractionOutcome {
  /// User submitted a filled form (for [InteractionKind.input]).
  submitted,

  /// Approved (for [InteractionKind.approval]).
  approved,

  /// Rejected (for [InteractionKind.approval]).
  rejected,

  /// Requested revisions (for [InteractionKind.approval]).
  revised,

  /// The interaction timed out before a response was given.
  timedOut,

  /// The user explicitly cancelled the interaction.
  cancelled;

  String toApi() {
    switch (this) {
      case InteractionOutcome.submitted:
        return 'Submitted';
      case InteractionOutcome.approved:
        return 'Approved';
      case InteractionOutcome.rejected:
        return 'Rejected';
      case InteractionOutcome.revised:
        return 'Revised';
      case InteractionOutcome.timedOut:
        return 'TimedOut';
      case InteractionOutcome.cancelled:
        return 'Cancelled';
    }
  }
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// A single field inside an [InteractionRequest] that the user must fill.
class InteractionField {
  InteractionField({
    required this.name,
    required this.label,
    required this.type,
    required this.isRequired,
    this.defaultValue,
    this.hint,
    this.options,
  });

  /// Technical key — used as the key in the response `data` map.
  final String name;

  /// Human-readable label displayed in the UI.
  final String label;

  /// The data type of this field.
  final InteractionFieldType type;

  /// Whether the field must be filled before the form can be submitted.
  final bool isRequired;

  /// Pre-filled value (if any).
  final dynamic defaultValue;

  /// Placeholder / help text.
  final String? hint;

  /// For [InteractionFieldType.choice] — the list of selectable options.
  final List<String>? options;

  factory InteractionField.fromJson(Map<String, dynamic> json) {
    final rawOptions = _get(json, 'options');
    List<String>? options;
    if (rawOptions is List) {
      options = rawOptions.map((entry) => '$entry').toList();
    }

    return InteractionField(
      name: _readString(json, 'name'),
      label: _readString(json, 'label'),
      type: InteractionFieldType.fromApi(_readString(json, 'type')),
      isRequired: _get(json, 'required') == true,
      defaultValue: _get(json, 'defaultValue'),
      hint: _readOptional(json, 'hint'),
      options: options,
    );
  }

  /// Serialises this field back to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'label': label,
      'type': type.name,
      'required': isRequired,
    };
    if (hint != null && hint!.isNotEmpty) {
      map['hint'] = hint;
    }
    if (options != null && options!.isNotEmpty) {
      map['options'] = options;
    }
    if (defaultValue != null) {
      map['defaultValue'] = defaultValue;
    }
    return map;
  }
}

/// A pending interaction request created by the backend when a WorkflowEntity node
/// suspends waiting for human input.
class InteractionRequest {
  InteractionRequest({
    required this.id,
    required this.contextId,
    required this.runId,
    this.workflowId,
    required this.nodeId,
    required this.kind,
    this.operation,
    required this.channelType,
    required this.title,
    this.description,
    this.message,
    this.messageId,
    this.threadId,
    this.conversationId,
    this.query,
    this.metadata,
    required this.fields,
    this.timeout,
    required this.createdAt,
    this.respondent,
  });

  /// Unique identifier of this interaction request.
  final String id;

  /// Explicit execution context identifier. In the current contract, this is
  /// aligned with [runId].
  final String contextId;

  /// The WorkflowEntity run that is suspended.
  final String runId;

  /// The WorkflowEntity that owns this run (if provided by the backend).
  final String? workflowId;

  /// The node that triggered the interaction.
  final String nodeId;

  /// What kind of interaction is expected.
  final InteractionKind kind;

  /// Optional backend operation identifier.
  final String? operation;

  /// The channel type (forms, slack, email). Only `forms` interactions are
  /// rendered inside the editor UI.
  final String channelType;

  /// Short title displayed as the dialog header.
  final String title;

  /// Longer description — content to review, instructions, etc.
  final String? description;

  /// Channel/provider message text when it is separate from [description].
  final String? message;

  /// Channel-specific message identifier.
  final String? messageId;

  /// Channel-specific thread identifier.
  final String? threadId;

  /// Channel-specific conversation identifier.
  final String? conversationId;

  /// Optional query or prompt attached to the interaction.
  final String? query;

  /// Opaque provider metadata.
  final Map<String, dynamic>? metadata;

  /// The fields the user must fill in (empty for notifications).
  final List<InteractionField> fields;

  /// Timeout in minutes. `null` means no timeout.
  final int? timeout;

  /// When the interaction was created (UTC).
  final DateTime createdAt;

  /// Pre-configured respondent from the channel (optional).
  final String? respondent;

  /// Whether this interaction should be rendered in the editor UI.
  bool get isFormsChannel => channelType.trim().toLowerCase() == 'forms';

  bool get isChatChannel => channelType.trim().toLowerCase() == 'chat';

  String get effectiveContextId => contextId.trim().isNotEmpty ? contextId : runId;

  /// Computes how many seconds remain before this interaction times out.
  /// Returns `null` when there is no timeout or it has already expired.
  int? get remainingSeconds {
    if (timeout == null) {
      return null;
    }
    final deadline = createdAt.add(Duration(minutes: timeout!));
    final remaining = deadline.difference(DateTime.now().toUtc()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  factory InteractionRequest.fromJson(Map<String, dynamic> json) {
    final rawFields = _get(json, 'fields');
    List<dynamic>? fieldsList;
    if (rawFields is List) {
      fieldsList = rawFields;
    } else if (rawFields is String && rawFields.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawFields);
        if (decoded is List) {
          fieldsList = decoded;
        }
      } catch (_) {
        // Malformed JSON string — treat as no fields.
      }
    }
    final fields = <InteractionField>[];
    if (fieldsList != null) {
      for (final entry in fieldsList) {
        if (entry is Map<String, dynamic>) {
          fields.add(InteractionField.fromJson(entry));
        } else if (entry is Map) {
          fields.add(InteractionField.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }

    return InteractionRequest(
      id: _readString(json, 'id'),
      contextId: _readString(json, 'contextId'),
      runId: _readString(json, 'runId'),
      workflowId: _readOptional(json, 'workflowId'),
      nodeId: _readString(json, 'nodeId'),
      kind: InteractionKind.fromApi(_readString(json, 'kind')),
      operation: _readOptional(json, 'operation'),
      channelType: _readString(json, 'channelType'),
      title: _readString(json, 'title'),
      description: _readOptional(json, 'description'),
      message: _readOptional(json, 'message'),
      messageId: _readOptional(json, 'messageId'),
      threadId: _readOptional(json, 'threadId'),
      conversationId: _readOptional(json, 'conversationId'),
      query: _readOptional(json, 'query'),
      metadata: _readOptionalMap(json, 'metadata'),
      fields: fields,
      timeout: _readOptionalInt(json, 'timeout'),
      createdAt: _parseDateTime(_get(json, 'createdAt')),
      respondent: _readOptional(json, 'respondent'),
    );
  }
}

/// The response the editor sends back to the backend to resume the WorkflowEntity.
class InteractionResponse {
  InteractionResponse({
    required this.outcome,
    this.data,
    this.metadata,
    this.channelType,
    this.channel,
    this.respondedBy,
    this.responseText,
    this.messageId,
    this.threadId,
    this.conversationId,
    this.messages,
  });

  final InteractionOutcome outcome;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? metadata;
  final String? channelType;
  final String? channel;
  final String? respondedBy;
  final String? responseText;
  final String? messageId;
  final String? threadId;
  final String? conversationId;
  final List<Map<String, dynamic>>? messages;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'outcome': outcome.toApi(),
      'data': data,
      'metadata': metadata,
      'channelType': channelType,
      'channel': channel,
      'respondedBy': respondedBy,
      'responseText': responseText,
      'messageId': messageId,
      'threadId': threadId,
      'conversationId': conversationId,
      'messages': messages,
    };
    payload.removeWhere((_, value) => value == null);
    return payload;
  }
}

/// The result returned by the backend after successfully submitting a response.
class InteractionSubmitResult {
  InteractionSubmitResult({
    required this.status,
    required this.contextId,
    required this.runId,
    required this.requestId,
  });

  final String status;
  final String contextId;
  final String runId;
  final String requestId;

  factory InteractionSubmitResult.fromJson(Map<String, dynamic> json) {
    return InteractionSubmitResult(
      status: _readString(json, 'status'),
      contextId: _readString(json, 'contextId'),
      runId: _readString(json, 'runId'),
      requestId: _readString(json, 'requestId'),
    );
  }
}

// ---------------------------------------------------------------------------
// JSON helpers (private, follow the pattern in workflow_run_models.dart)
// ---------------------------------------------------------------------------

/// Case-insensitive key lookup – handles both camelCase and PascalCase keys
/// from different backend serialisation conventions.
dynamic _get(Map<String, dynamic> json, String key) {
  // Fast path: exact match.
  if (json.containsKey(key)) return json[key];
  // Slow path: case-insensitive scan.
  final lower = key.toLowerCase();
  for (final entry in json.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return null;
}

String _readString(Map<String, dynamic> json, String key) {
  final raw = _get(json, key);
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  // Fallback: coerce non-null to string (e.g. int ids).
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
  if (raw is String) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return raw.toString();
}

int? _readOptionalInt(Map<String, dynamic> json, String key) {
  final raw = _get(json, key);
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  if (raw is String) {
    return int.tryParse(raw.trim());
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

DateTime _parseDateTime(Object? raw) {
  if (raw is DateTime) {
    return raw.toUtc();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return parsed.toUtc();
    }
  }
  return DateTime.now().toUtc();
}
