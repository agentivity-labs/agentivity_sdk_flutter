import '../../../client/app_client/domain/team_definition_models.dart';

/// How a team's members work together — what the team graph draws. Mirrors the backend's orchestrators.
enum AgUiTeamTopologyKind {
  managerLed,
  sequential,
  concurrent,
  handoff,
  groupChat,
}

/// A directed link between two members, by `memberEntityId`.
class AgUiTeamLink {
  const AgUiTeamLink(this.from, this.to);
  final String from;
  final String to;
}

/// The shape of a team: how its members are organized ([kind]) and the directed links the team editor drew between them.
/// `AgUiTeamGraph` draws each kind differently — a hub for a manager-led team, a chain for a sequential one, parallel lanes
/// for a concurrent one, a ring of peers for a handoff, a shared table for a group chat.
class AgUiTeamTopology {
  const AgUiTeamTopology(this.kind, [this.links = const []]);
  final AgUiTeamTopologyKind kind;

  /// The links saved in the team (sequential: who hands over to whom; handoff: who may delegate to whom). Empty when none.
  final List<AgUiTeamLink> links;
}

const _kinds = {
  'manager-led': AgUiTeamTopologyKind.managerLed,
  'managerled': AgUiTeamTopologyKind.managerLed,
  'manager_led': AgUiTeamTopologyKind.managerLed,
  'sequential': AgUiTeamTopologyKind.sequential,
  'concurrent': AgUiTeamTopologyKind.concurrent,
  'parallel': AgUiTeamTopologyKind.concurrent,
  'handoff': AgUiTeamTopologyKind.handoff,
  'group-chat': AgUiTeamTopologyKind.groupChat,
  'groupchat': AgUiTeamTopologyKind.groupChat,
  'group_chat': AgUiTeamTopologyKind.groupChat,
};

/// The shape of a team as saved, or null for an orchestrator this SDK does not know (the graph then falls back to its
/// default drawing).
AgUiTeamTopology? agUiTeamTopology(TeamStructure team) {
  final kind = _kinds[team.orchestratorId.trim().toLowerCase()];
  if (kind == null) return null;
  final memberOf = {
    for (final m in team.members) m.topologyPositionId: m.memberEntityId,
  };
  final links = <AgUiTeamLink>[];
  for (final c in team.connections) {
    final from = memberOf[c.fromTopologyPositionId];
    final to = memberOf[c.toTopologyPositionId];
    if (from != null &&
        to != null &&
        from != to &&
        !links.any((l) => l.from == from && l.to == to)) {
      links.add(AgUiTeamLink(from, to));
    }
  }
  return AgUiTeamTopology(kind, links);
}
