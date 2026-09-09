import 'package:meta/meta.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CatalogBrowseItem
// ─────────────────────────────────────────────────────────────────────────────

/// A single item in the unified `CatalogBrowseResult` returned by the
/// `/agentic/browse`, `/workflows/browse`, and `/prompts/browse` endpoints.
/// The `type` field discriminates between entity kinds.
@immutable
class CatalogBrowseItem {
  const CatalogBrowseItem({
    required this.id,
    required this.name,
    required this.type,
    this.updatedAt,
    this.role,
    this.folderId,
  });

  final String id;
  final String name;

  /// `"agent"` | `"team"` | `"WorkflowEntity"` | `"prompt"` | `"folder"`
  final String type;
  final DateTime? updatedAt;
  final String? role;
  final String? folderId;

  bool get isAgent => type == 'agent';
  bool get isTeam => type == 'team';
  bool get isWorkflow => type == 'WorkflowEntity';
  bool get isPrompt => type == 'prompt';

  factory CatalogBrowseItem.fromJson(Map<String, dynamic> json) {
    return CatalogBrowseItem(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      type: (json['type'] as String? ?? '').trim().toLowerCase(),
      updatedAt: _parseDateTime(json['updatedAt']),
      role: _nullableTrimmedString(json['role']),
      folderId: _nullableTrimmedString(json['folderId']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AgentSummary
// ─────────────────────────────────────────────────────────────────────────────

/// Summary returned by `GET BASE/agentic/agents?folderId={id}`.
@immutable
class AgentSummary {
  const AgentSummary({
    required this.id,
    required this.name,
    required this.tags,
    this.folderId,
    this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> tags;
  final String? folderId;
  final DateTime? updatedAt;

  factory AgentSummary.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tags = (rawTags is List) ? rawTags.map((t) => t.toString().trim()).where((t) => t.isNotEmpty).toList() : const <String>[];
    return AgentSummary(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      tags: List<String>.unmodifiable(tags),
      folderId: _nullableTrimmedString(json['folderId']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AgenticFolder  (returned by CRUD endpoints — not browse)
// ─────────────────────────────────────────────────────────────────────────────

/// Folder returned by the `/agentic/folders` CRUD endpoints.
/// The browse endpoint returns a different (leaner) shape handled by
/// `CatalogBrowseItem` with `type == "folder"`.
@immutable
class AgenticFolder {
  const AgenticFolder({
    required this.folderId,
    required this.name,
    this.parentFolderId,
    this.createdAtUtc,
    this.updatedAtUtc,
  });

  final String folderId;
  final String name;
  final String? parentFolderId;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;

  factory AgenticFolder.fromJson(Map<String, dynamic> json) {
    // CRUD endpoint returns WorkspaceFolder shape with 'folderId'.
    // Browse endpoint (CatalogBrowseFolder) uses 'id' — handled separately.
    final folderId = _nullableTrimmedString(json['folderId']) ?? _nullableTrimmedString(json['id']) ?? '';
    return AgenticFolder(
      folderId: folderId,
      name: (json['name'] as String? ?? '').trim(),
      parentFolderId: _nullableTrimmedString(json['parentFolderId']),
      createdAtUtc: _parseDateTime(json['createdAtUtc']),
      updatedAtUtc: _parseDateTime(json['updatedAtUtc']),
    );
  }

  AgenticFolder copyWith({
    String? folderId,
    String? name,
    Object? parentFolderId = _sentinel,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) {
    return AgenticFolder(
      folderId: folderId ?? this.folderId,
      name: name ?? this.name,
      parentFolderId: identical(parentFolderId, _sentinel) ? this.parentFolderId : _nullableTrimmedString(parentFolderId),
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AgenticBrowseCurrent / AgenticBrowseLevel
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class AgenticBrowseCurrent {
  const AgenticBrowseCurrent({
    required this.folderId,
    required this.name,
    required this.isRoot,
  });

  final String? folderId;
  final String? name;
  final bool isRoot;

  factory AgenticBrowseCurrent.fromJson(Map<String, dynamic> json) {
    return AgenticBrowseCurrent(
      folderId: _nullableTrimmedString(json['folderId']),
      name: _nullableTrimmedString(json['name']),
      isRoot: json['isRoot'] == true,
    );
  }
}

@immutable
class AgenticBrowseLevel {
  const AgenticBrowseLevel({
    required this.current,
    required this.folders,
    required this.items,
  });

  final AgenticBrowseCurrent current;

  /// Folders at this level — sourced from `CatalogBrowseResult.folders`.
  /// Each folder entry has been deserialized into an [AgenticFolder] using
  /// the `id` field from the browse shape mapped to `folderId`.
  final List<AgenticFolder> folders;

  /// Items at this level — agents and teams mixed, discriminated by [CatalogBrowseItem.type].
  final List<CatalogBrowseItem> items;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const Object _sentinel = Object();

String? _nullableTrimmedString(dynamic value) {
  if (value == null) return null;
  final trimmed = value.toString().trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
