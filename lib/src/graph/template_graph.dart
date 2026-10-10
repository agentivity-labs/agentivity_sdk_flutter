import 'dart:async';

import 'package:flutter/material.dart';

import '../ag_ui/panels/chat/chat_controller.dart';
import '../ag_ui/panels/chat/member_avatar.dart';
import '../ag_ui/panels/chat/team_views.dart';
import '../ag_ui/panels/chat/workflow_views.dart';
import '../client/app_client/domain/team_definition_models.dart';
import '../client/app_client/domain/workflow_graph_models.dart';
import 'renderable.dart';

/// The graph of anything the platform can describe: a team as its constellation of members, a workflow (or the graph inside an
/// agent) as its flow. It needs no run and no chat — it is the picture for a catalog, a preview, an import dialog or a
/// documentation page. [source] is a Template file, the marketplace's root payload, a catalog wrapper or a bare team /
/// workflow / agent — a map or its JSON text (see [resolveRenderable]); a Template is drawn from its root. An unreadable
/// source draws a short message instead of throwing. Mirrors the React SDK's `TemplateGraph`.
class AgUiTemplateGraph extends StatefulWidget {
  const AgUiTemplateGraph({
    super.key,
    required this.source,
    this.resolveMemberAvatar,
    this.autoplay = false,
    this.stepDuration,
    this.interactive = false,
    this.camera = AgUiWorkflowCamera.fit,
  });

  final Object? source;

  /// Maps a member to an image or emoji of the app's own; by default the icon and group color the team editor chose.
  final AgUiMemberAvatar? Function(AgUiChatMember member)? resolveMemberAvatar;

  /// Light the members (or the steps) up one after the other, as a run would: a living picture for a catalog. Off by default,
  /// and never done when the platform asks for reduced motion.
  final bool autoplay;

  /// How long each step stays lit. Defaults to 1.4 s for a team and 1.1 s for a workflow.
  final Duration? stepDuration;

  /// Whether the visitor can drag and zoom. Default false: a Template graph is a picture on a page that scrolls.
  final bool interactive;

  /// Where the camera looks on a workflow (and on the graph inside an agent); a team is not affected. [AgUiWorkflowCamera.fit]
  /// (the default) keeps the whole diagram in view. [AgUiWorkflowCamera.follow] opens on the start node at a readable scale and,
  /// with [autoplay], glides from one active node to the next, back to the start when the loop begins again. The widget then fills the
  /// size its parent gives it (16:9 when the height is unbounded). Without [autoplay], or when the platform asks for reduced
  /// motion, it is a still picture centred on the start.
  final AgUiWorkflowCamera camera;

  @override
  State<AgUiTemplateGraph> createState() => _AgUiTemplateGraphState();
}

/// The order in which a run walks a workflow: from its start, following the edges; whatever is left comes last.
List<String> agUiWorkflowWalk(WorkflowGraphStructure structure) {
  final order = <String>[];
  final seen = <String>{};
  final first = structure.entryNodeId ?? (structure.nodes.isNotEmpty ? structure.nodes.first.id : null);
  final queue = [if (first != null) first];
  while (queue.isNotEmpty) {
    final id = queue.removeAt(0);
    if (!seen.add(id)) continue;
    order.add(id);
    for (final edge in structure.edges) {
      if (edge.from == id && !seen.contains(edge.to)) queue.add(edge.to);
    }
  }
  for (final node in structure.nodes) {
    if (!seen.contains(node.id)) order.add(node.id);
  }
  return order;
}

/// The statuses at [step] of a walk over [ids]: the steps passed read as done, the current one as working; the last two rounds
/// leave everything done, then everything at rest again. Pure, so it can be tested without a clock.
Map<String, S> agUiPlaybackStatuses<S>(List<String> ids, int step, {required S working, required S done}) {
  final statuses = <String, S>{};
  if (step >= ids.length + 1) return statuses;
  for (var i = 0; i < ids.length; i++) {
    if (i < step) {
      statuses[ids[i]] = done;
    } else if (i == step) {
      statuses[ids[i]] = working;
    }
  }
  if (step == ids.length) {
    for (final id in ids) {
      statuses[id] = done;
    }
  }
  return statuses;
}

class _Resolved {
  _Resolved({this.renderable, this.error, this.team, this.workflow, this.walk = const []});
  final Renderable? renderable;
  final String? error;
  final TeamStructure? team;
  final WorkflowGraphStructure? workflow;
  final List<String> walk;

  List<String> get ids => team != null ? [for (final m in team!.members) m.memberEntityId] : walk;
}

class _AgUiTemplateGraphState extends State<AgUiTemplateGraph> {
  late _Resolved _resolved;
  Timer? _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _resolved = _resolve(widget.source);
  }

  @override
  void didUpdateWidget(AgUiTemplateGraph old) {
    super.didUpdateWidget(old);
    final sourceChanged = !identical(old.source, widget.source);
    if (sourceChanged) {
      _resolved = _resolve(widget.source);
      _step = 0;
    }
    if (sourceChanged || old.autoplay != widget.autoplay || old.stepDuration != widget.stepDuration) _restartTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _playing => widget.autoplay && _resolved.ids.isNotEmpty && !MediaQuery.disableAnimationsOf(context);

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_playing) return;
    final every = widget.stepDuration ?? Duration(milliseconds: _resolved.team != null ? 1400 : 1100);
    _timer = Timer.periodic(every, (_) {
      if (mounted) setState(() => _step = (_step + 1) % (_resolved.ids.length + 2));
    });
  }

  static _Resolved _resolve(Object? source) {
    final Renderable renderable;
    try {
      renderable = resolveRenderable(source);
    } on RenderableError catch (e) {
      return _Resolved(error: e.message);
    }
    if (renderable.kind == RenderableKind.team) {
      return _Resolved(renderable: renderable, team: _namedTeam(renderable));
    }
    final graph = renderable.kind == RenderableKind.agent ? renderable.entity['graph'] : renderable.entity;
    final structure = graph is Map ? WorkflowGraphStructure.fromJson(Map<String, dynamic>.from(graph)) : null;
    return _Resolved(renderable: renderable, workflow: structure, walk: structure == null ? const [] : agUiWorkflowWalk(structure));
  }

  /// A team whose members are named from what the Template (or the marketplace) says about them.
  static TeamStructure _namedTeam(Renderable renderable) {
    final structure = TeamStructure.fromJson(renderable.entity);
    return TeamStructure(
      id: structure.id,
      name: structure.name,
      orchestratorId: structure.orchestratorId,
      managerTopologyPositionId: structure.managerTopologyPositionId,
      goal: structure.goal,
      connections: structure.connections,
      groupColors: structure.groupColors,
      members: [
        for (final m in structure.members)
          TeamMemberPosition(
            topologyPositionId: m.topologyPositionId,
            memberEntityId: m.memberEntityId,
            memberType: m.memberType,
            displayName: m.displayName ?? renderable.entitiesById[m.memberEntityId]?.name,
            role: m.role ?? renderable.entitiesById[m.memberEntityId]?.role,
            icon: m.icon,
            group: m.group,
          ),
      ],
    );
  }

  Widget _message(String text) => Semantics(
    label: 'Nothing to draw',
    child: Padding(padding: const EdgeInsets.all(16), child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
  );

  @override
  Widget build(BuildContext context) {
    final r = _resolved;
    if (r.renderable == null) return _message(r.error ?? 'Nothing to draw.');
    final playing = _playing;

    final team = r.team;
    if (team != null) {
      final statuses = playing
          ? agUiPlaybackStatuses<TeamMemberStatus>(r.ids, _step, working: TeamMemberStatus.working, done: TeamMemberStatus.done)
          : null;
      return AgUiTeamGraph(
        members: team.toTeamMembers(),
        hubMemberId: team.hubMemberEntityId,
        resolveMemberAvatar: widget.resolveMemberAvatar,
        restingColors: !playing,
        statuses: statuses,
        interactive: widget.interactive,
      );
    }

    final workflow = r.workflow;
    if (workflow == null || workflow.nodes.isEmpty) return _message('This ${r.renderable!.kind.name} has no steps to draw.');
    final statuses = playing
        ? agUiPlaybackStatuses<WorkflowStepStatus>(r.ids, _step, working: WorkflowStepStatus.working, done: WorkflowStepStatus.done)
        : null;
    return AgUiWorkflowGraph(structure: workflow, statuses: statuses, camera: widget.camera, interactive: widget.interactive);
  }
}
