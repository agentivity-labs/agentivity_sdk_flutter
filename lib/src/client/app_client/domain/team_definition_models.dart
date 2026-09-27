import '../../../icons/icon_ref.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Team definition (members, connections) — read-only.
// ─────────────────────────────────────────────────────────────────────────────

/// One member of a team, as saved in the team editor.
class TeamMemberPosition {
  const TeamMemberPosition({
    required this.topologyPositionId,
    required this.memberEntityId,
    this.memberType = 'agent',
    this.displayName,
    this.role,
    this.icon,
    this.group,
  });

  /// This member's slot in the team (what connections and `managerAgentId` refer to).
  final String topologyPositionId;

  /// The agent, team or workflow behind the slot — the id a run reports on each of its steps.
  final String memberEntityId;

  /// `agent`, `team` or `workflow`.
  final String memberType;
  final String? displayName;
  final String? role;

  /// The icon the member wears — an [IconRef] into the platform's icon catalog (`GET /api/v1/icons`), chosen in the team
  /// editor or suggested when it was saved.
  final IconRef? icon;

  /// The group the team editor put this member in, if any.
  final String? group;

  factory TeamMemberPosition.fromJson(Map<String, dynamic> json) {
    return TeamMemberPosition(
      topologyPositionId: _text(json['topologyPositionId']) ?? '',
      memberEntityId: _text(json['memberEntityId']) ?? '',
      memberType: (_text(json['memberType']) ?? 'agent').toLowerCase(),
      displayName: _text(json['displayName']),
      role: _text(json['role']),
      icon: IconRef.tryParse(json['icon']),
      group: _text(json['group']),
    );
  }
}

/// A directed link between two members of a team.
class TeamConnectionDefinition {
  const TeamConnectionDefinition({
    required this.fromTopologyPositionId,
    required this.toTopologyPositionId,
    this.types = const [],
  });

  final String fromTopologyPositionId;
  final String toTopologyPositionId;

  /// `sequential`, `parallel`, `delegate`, `loop`… as the backend names them.
  final List<String> types;

  factory TeamConnectionDefinition.fromJson(Map<String, dynamic> json) {
    final rawTypes = json['types'];
    return TeamConnectionDefinition(
      fromTopologyPositionId: _text(json['fromTopologyPositionId']) ?? '',
      toTopologyPositionId: _text(json['toTopologyPositionId']) ?? '',
      types:
          rawTypes is List
              ? rawTypes
                  .map((t) => t.toString().toLowerCase())
                  .toList(growable: false)
              : const [],
    );
  }
}

/// A team's saved definition: who its members are, how they are connected and which one manages.
class TeamStructure {
  const TeamStructure({
    required this.id,
    required this.name,
    required this.orchestratorId,
    this.managerTopologyPositionId,
    this.goal,
    this.members = const [],
    this.connections = const [],
    this.groupColors = const {},
  });

  final String id;
  final String name;

  /// `sequential`, `concurrent`, `handoff`, `group-chat`, `manager-led`…
  final String orchestratorId;

  /// The [TeamMemberPosition.topologyPositionId] of the manager (manager-led teams).
  final String? managerTopologyPositionId;
  final String? goal;
  final List<TeamMemberPosition> members;
  final List<TeamConnectionDefinition> connections;

  /// Colors the team editor chose for groups (`#RRGGBB`), by group key (trimmed, lower-case). A group without one gets the
  /// default color.
  final Map<String, String> groupColors;

  /// The manager's member, when the team has one.
  TeamMemberPosition? get manager =>
      managerTopologyPositionId == null
          ? null
          : members
              .where((m) => m.topologyPositionId == managerTopologyPositionId)
              .firstOrNull;

  factory TeamStructure.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
      if (raw is! List) return const [];
      return raw
          .whereType<Object>()
          .map(
            (e) => parse(
              e is Map<String, dynamic>
                  ? e
                  : Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(growable: false);
    }

    return TeamStructure(
      id: _text(json['id']) ?? '',
      name: _text(json['name']) ?? '',
      orchestratorId: _text(json['orchestratorId']) ?? '',
      managerTopologyPositionId: _text(json['managerAgentId']),
      goal: _text(json['goal']),
      members: list(json['members'], TeamMemberPosition.fromJson),
      connections: list(json['connections'], TeamConnectionDefinition.fromJson),
      groupColors: _groupColors(json['groupColors']),
    );
  }
}

Map<String, String> _groupColors(Object? raw) {
  if (raw is! Map) return const {};
  final hex = RegExp(r'^#[0-9a-fA-F]{6}$');
  return {
    for (final e in raw.entries)
      if (e.value is String && hex.hasMatch((e.value as String).trim())) e.key.toString().trim().toLowerCase(): (e.value as String).trim().toUpperCase(),
  };
}

String? _text(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
