// ─────────────────────────────────────────────────────────────────────────────
// Team  (lightweight listing model)
// ─────────────────────────────────────────────────────────────────────────────

class Team {
  const Team({
    required this.teamId,
    required this.teamName,
    this.role,
    this.folderId,
    this.orchestrationType,
    this.memberCount = 0,
    this.createdAtUtc,
    this.updatedAtUtc,
  });

  final String teamId;
  final String teamName;
  final String? role;
  final String? folderId;

  /// Orchestration pattern, e.g. `"sequential"`, `"concurrent"`.
  /// Populated from `TeamSummaryDto.orchestrationType` (new agentic API).
  final String? orchestrationType;

  /// Number of member topologyPositions in the team. Populated from `TeamSummaryDto.memberCount`.
  final int memberCount;

  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      teamId: _requireString(json['id']),
      teamName: (_normalizeOptionalString(json['name'] ?? json['teamName']) ?? '').trim(),
      role: _normalizeOptionalString(json['role']),
      folderId: _normalizeOptionalString(json['folderId']),
      orchestrationType: _normalizeOptionalString(json['orchestrationType']),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      createdAtUtc: _parseDateTime(json['createdAtUtc']),
      updatedAtUtc: _parseDateTime(json['updatedAtUtc']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'teamId': teamId,
        'teamName': teamName,
        if (role != null) 'role': role,
        if (folderId != null) 'folderId': folderId,
        if (orchestrationType != null) 'orchestrationType': orchestrationType,
        'memberCount': memberCount,
        if (createdAtUtc != null) 'createdAtUtc': createdAtUtc!.toUtc().toIso8601String(),
        if (updatedAtUtc != null) 'updatedAtUtc': updatedAtUtc!.toUtc().toIso8601String(),
      };

  Team copyWith({
    String? teamId,
    String? teamName,
    Object? role = _sentinel,
    Object? folderId = _sentinel,
    Object? orchestrationType = _sentinel,
    int? memberCount,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) {
    return Team(
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      role: identical(role, _sentinel) ? this.role : _normalizeOptionalString(role),
      folderId: identical(folderId, _sentinel) ? this.folderId : _normalizeOptionalString(folderId),
      orchestrationType: identical(orchestrationType, _sentinel) ? this.orchestrationType : _normalizeOptionalString(orchestrationType),
      memberCount: memberCount ?? this.memberCount,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TeamFolder
// ─────────────────────────────────────────────────────────────────────────────

class TeamFolder {
  const TeamFolder({
    required this.objectType,
    required this.teamFolderId,
    required this.name,
    this.parentTeamFolderId,
    this.createdAtUtc,
    this.updatedAtUtc,
  });

  final String objectType;
  final String teamFolderId;
  final String name;
  final String? parentTeamFolderId;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;

  factory TeamFolder.fromJson(Map<String, dynamic> json) {
    return TeamFolder(
      objectType: (json['type'] as String? ?? 'folder').trim(),
      teamFolderId: _requireString(json['id']),
      name: (json['name'] as String? ?? '').trim(),
      parentTeamFolderId: _normalizeOptionalString(json['parentFolderId']),
      createdAtUtc: _parseDateTime(json['createdAtUtc']),
      updatedAtUtc: _parseDateTime(json['updatedAtUtc']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'objectType': objectType,
        'teamFolderId': teamFolderId,
        'name': name,
        if (parentTeamFolderId != null) 'parentTeamFolderId': parentTeamFolderId,
        if (createdAtUtc != null) 'createdAtUtc': createdAtUtc!.toUtc().toIso8601String(),
        if (updatedAtUtc != null) 'updatedAtUtc': updatedAtUtc!.toUtc().toIso8601String(),
      };

  TeamFolder copyWith({
    String? objectType,
    String? teamFolderId,
    String? name,
    Object? parentTeamFolderId = _sentinel,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) {
    return TeamFolder(
      objectType: objectType ?? this.objectType,
      teamFolderId: teamFolderId ?? this.teamFolderId,
      name: name ?? this.name,
      parentTeamFolderId: identical(parentTeamFolderId, _sentinel) ? this.parentTeamFolderId : _normalizeOptionalString(parentTeamFolderId),
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Browse level
// ─────────────────────────────────────────────────────────────────────────────

class TeamBrowseCurrent {
  const TeamBrowseCurrent({
    required this.folderId,
    required this.name,
    required this.isRoot,
  });

  final String? folderId;
  final String? name;
  final bool isRoot;

  factory TeamBrowseCurrent.fromJson(Map<String, dynamic> json) {
    return TeamBrowseCurrent(
      folderId: _normalizeOptionalString(json['folderId']),
      name: _normalizeOptionalString(json['name']),
      isRoot: json['isRoot'] == true,
    );
  }
}

class TeamBrowseLevel {
  const TeamBrowseLevel({
    required this.current,
    required this.folders,
    required this.items,
  });

  final TeamBrowseCurrent current;
  final List<TeamFolder> folders;
  final List<Team> items;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const Object _sentinel = Object();

String _requireString(dynamic value) {
  final normalized = _normalizeOptionalString(value);
  if (normalized == null) {
    throw StateError('Required string field is null or empty: $value');
  }
  return normalized;
}

String? _normalizeOptionalString(dynamic value) {
  if (value == null) return null;
  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _parseDateTime(dynamic value) {
  final normalized = _normalizeOptionalString(value);
  if (normalized == null) return null;
  return DateTime.tryParse(normalized)?.toUtc();
}
