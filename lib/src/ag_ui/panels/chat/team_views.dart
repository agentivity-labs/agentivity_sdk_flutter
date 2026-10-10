import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../client/app_client/domain/team_definition_models.dart';
import '../../../icons/icon_ref.dart';
import 'chat_controller.dart';
import 'execution_statuses_controller.dart';
import 'member_avatar.dart';
import 'team_appearance.dart';
import 'team_layouts.dart';
import 'team_topology.dart';

/// A member of the Team being shown by [AgUiTeamRoster] / [AgUiTeamGraph]. [memberEntityId] must match
/// the id the backend reports on `STEP_STARTED`/`STEP_FINISHED`.
class AgUiTeamMember {
  const AgUiTeamMember({
    required this.memberEntityId,
    required this.displayName,
    this.label,
    this.icon,
    this.group,
    this.groupColor,
    this.topology,
  });
  final String memberEntityId;
  final String displayName;

  /// The icon the team editor gave this member (an [IconRef] into the platform's icon catalog). Drawn when the app's own avatar resolver
  /// has nothing for this member.
  final IconRef? icon;

  /// The group the team editor put this member in; members of a group are drawn together and share a color.
  final String? group;

  /// The color the team editor chose for this member's group; null = the default color.
  final Color? groupColor;

  /// The shape of the whole team, set by [AgUiTeamStructureMembers.toTeamMembers] on every member so [AgUiTeamGraph] can draw the
  /// right layout from the members alone. An app that builds its members by hand can pass `topology` to [AgUiTeamGraph] instead.
  final AgUiTeamTopology? topology;

  /// Short caption under the member in [AgUiTeamGraph]; defaults to [displayName] without its trailing role word
  /// ("Flight Specialist" → "Flight"), truncated to fit.
  final String? label;

  AgUiChatMember get asChatMember =>
      AgUiChatMember(memberEntityId: memberEntityId, displayName: displayName);
}

Map<String, Color> _colorOverrides(List<AgUiTeamMember> members) =>
    agUiGroupColorOverrides(
      members.map((m) => (group: m.group, groupColor: m.groupColor)),
    );

/// A team's saved definition, ready for [AgUiTeamRoster] / [AgUiTeamGraph]: one [AgUiTeamMember] per member, with the
/// icon and group the team editor set.
extension AgUiTeamStructureMembers on TeamStructure {
  List<AgUiTeamMember> toTeamMembers() {
    final topology = agUiTeamTopology(this);
    return [
      for (final m in members)
        AgUiTeamMember(
          memberEntityId: m.memberEntityId,
          displayName: m.displayName ?? m.memberEntityId,
          icon: m.icon,
          group: m.group,
          groupColor: agUiParseHexColor(groupColors[agUiTeamGroupKey(m.group)]),
          topology: topology,
        ),
    ];
  }

  /// The id to pass as `hubMemberId` — the manager of a manager-led team, otherwise null.
  String? get hubMemberEntityId => manager?.memberEntityId;
}

/// An avatar resolver for chat speaker labels and the active-member indicator, drawing each member with the icon and
/// group color the team editor gave it — so a chat, a roster and a graph show the same member the same way. Pass it
/// as `resolveMemberAvatar`; [fallback] answers first for a member the app wants to draw differently (an image).
AgUiMemberAvatar? Function(AgUiChatMember) agUiTeamAvatarResolver(
  List<AgUiTeamMember> members, {
  AgUiMemberAvatar? Function(AgUiChatMember member)? fallback,
}) {
  final groupColors = agUiTeamGroupColors(
    members.map((m) => m.group),
    custom: _colorOverrides(members),
  );
  final byId = {for (final m in members) m.memberEntityId: m};
  return (chatMember) {
    final resolved = fallback?.call(chatMember);
    final member = byId[chatMember.memberEntityId];
    if (member == null) return resolved;
    return AgUiMemberAvatar(
      imageUrl: resolved?.imageUrl,
      emoji: resolved?.emoji,
      icon: resolved?.icon ?? member.icon,
      color: resolved?.color ?? groupColors[agUiTeamGroupKey(member.group)],
      initials: resolved?.initials,
    );
  };
}

/// The avatar resolver for one team member: the app's own answer first (an image or emoji it chose), then the icon and
/// group color the team editor gave the member, so a team drawn from its saved definition needs no app-side mapping.
AgUiMemberAvatar? Function(AgUiChatMember) _memberAvatar(
  AgUiTeamMember member,
  Color? groupColor,
  AgUiMemberAvatar? Function(AgUiChatMember member)? resolver,
) {
  return (chatMember) {
    final resolved = resolver?.call(chatMember);
    return AgUiMemberAvatar(
      imageUrl: resolved?.imageUrl,
      emoji: resolved?.emoji,
      icon: resolved?.icon ?? member.icon,
      color: resolved?.color ?? groupColor,
      initials: resolved?.initials,
    );
  };
}

/// Colors for each [TeamMemberStatus] (and for a member that has not been needed yet).
class AgUiTeamPalette {
  const AgUiTeamPalette({
    this.working = const Color(0xFFF1633B),
    this.waiting = const Color(0xFFE3A94F),
    this.done = const Color(0xFF10B981),
    this.failed = const Color(0xFFDC2626),
    this.idle = const Color(0xFFCBD5E1),
  });
  final Color working;
  final Color waiting;
  final Color done;
  final Color failed;
  final Color idle;

  Color of(TeamMemberStatus? status) => switch (status) {
    TeamMemberStatus.working => working,
    TeamMemberStatus.waiting => waiting,
    TeamMemberStatus.done => done,
    TeamMemberStatus.failed => failed,
    null => idle,
  };
}

const _roleWords = {'specialist', 'agent', 'advisor', 'assistant'};

/// A member's name without the generic role word it usually ends with — "Flight Specialist" → "Flight",
/// "On-Trip Assistant" → "On-Trip".
String agUiTeamMemberShortName(String displayName) {
  final words = displayName.trim().split(RegExp(r'\s+'));
  return words.length > 1 && _roleWords.contains(words.last.toLowerCase())
      ? words.sublist(0, words.length - 1).join(' ')
      : displayName.trim();
}

/// Text for a member's status, shared by both widgets' tooltips and screen-reader labels.
String teamMemberStatusText(TeamMemberStatus? status) => switch (status) {
  TeamMemberStatus.working => 'working now',
  TeamMemberStatus.waiting => 'waiting for your answer',
  TeamMemberStatus.done => 'done',
  TeamMemberStatus.failed => 'failed',
  null => 'not needed yet',
};

/// A compact strip of the whole Team — one avatar per member, showing who is working now, who is waiting
/// on the user, who is done and who has not been needed yet. Driven by [ChatController.memberStatuses];
/// optional and independent of [AgUiChatDiscussion], so it can sit anywhere. Small enough for a phone width.
class AgUiTeamRoster extends StatelessWidget {
  const AgUiTeamRoster({
    super.key,
    required this.controller,
    required this.members,
    this.resolveMemberAvatar,
    this.palette = const AgUiTeamPalette(),
    this.avatarSize = 28,
    this.statusSource,
  });

  final ChatController controller;
  /// Where member statuses come from — an [ExecutionStatusesController] reading the execution's own inspector (right on a
  /// fresh run, after a reconnect and when reopening an old execution). When omitted it falls back to what [controller]
  /// has seen on the stream ([ChatController.memberStatuses]), which is empty for anything that happened before this
  /// screen was open.
  final ExecutionStatusesController? statusSource;


  /// Every member of the Team, in the order to show them.
  final List<AgUiTeamMember> members;
  final AgUiMemberAvatar? Function(AgUiChatMember member)? resolveMemberAvatar;
  final AgUiTeamPalette palette;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, if (statusSource != null) statusSource!]),
      builder: (context, _) {
        final statuses = statusSource?.memberStatuses ?? controller.memberStatuses;
        final groupColors = agUiTeamGroupColors(
          members.map((m) => m.group),
          custom: _colorOverrides(members),
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              for (final member in members)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _RosterMember(
                    member: member,
                    status: statuses[member.memberEntityId],
                    resolver: _memberAvatar(
                      member,
                      groupColors[agUiTeamGroupKey(member.group)],
                      resolveMemberAvatar,
                    ),
                    palette: palette,
                    size: avatarSize,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RosterMember extends StatelessWidget {
  const _RosterMember({
    required this.member,
    required this.status,
    required this.resolver,
    required this.palette,
    required this.size,
  });

  final AgUiTeamMember member;
  final TeamMemberStatus? status;
  final AgUiMemberAvatar? Function(AgUiChatMember member)? resolver;
  final AgUiTeamPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = teamMemberStatusText(status);
    final ring =
        status == TeamMemberStatus.working
            ? palette.working
            : Colors.transparent;
    return Semantics(
      label: '${member.displayName}, $text',
      excludeSemantics: true,
      child: Tooltip(
        message: '${member.displayName} — $text',
        child: Opacity(
          opacity: status == null ? 0.4 : 1.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 2),
                ),
                child: MemberAvatarWidget(
                  member: member.asChatMember,
                  resolver: resolver,
                  size: size - 4,
                ),
              ),
              if (status != null)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: palette.of(status),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The whole Team as a constellation: an optional hub in the middle, one branch per group (named, in its color) and every
/// member a small hexagon with its icon and its name underneath. Each member is lit by its live status — working now
/// (animated link), waiting on the user, done (the path already taken is drawn in full), or not needed yet (a faint dotted link).
/// Driven by [ChatController.memberStatuses]; optional and independent of [AgUiChatDiscussion].
class AgUiTeamGraph extends StatefulWidget {
  const AgUiTeamGraph({
    super.key,
    this.controller,
    required this.members,
    this.hubMemberId,
    this.resolveMemberAvatar,
    this.palette = const AgUiTeamPalette(),
    this.restingColors = false,
    this.statusSource,
    this.topology,
    this.statuses,
    this.interactive = true,
  });

  /// The chat the graph follows. Optional: without it (and without a [statusSource]) the graph shows [statuses], or a still picture.
  final ChatController? controller;

  /// Member statuses to show, by `memberEntityId` — for a picture driven by the app (a catalog's autoplay) rather than by a run.
  /// Wins over [statusSource] and [controller].
  final Map<String, TeamMemberStatus>? statuses;

  /// Whether the visitor can drag and zoom. Turn it off for a picture on a page that scrolls.
  final bool interactive;

  /// Where member statuses come from — an [ExecutionStatusesController] reading the execution's own inspector (right on a
  /// fresh run, after a reconnect and when reopening an old execution). When omitted it falls back to what [controller]
  /// has seen on the stream ([ChatController.memberStatuses]), which is empty for anything that happened before this
  /// screen was open.
  final ExecutionStatusesController? statusSource;

  final List<AgUiTeamMember> members;

  /// The shape of the team. Defaults to the one carried by [members] ([AgUiTeamStructureMembers.toTeamMembers]); a manager-led
  /// team, or one of unknown shape, is drawn as a constellation around its hub.
  final AgUiTeamTopology? topology;

  /// Show the members in their group colors while nothing is running (a still picture of the team). By default they are
  /// switched off and light up as the run needs them.
  final bool restingColors;

  /// The coordinating member (a manager), drawn in the middle and linked to every group. Omit to draw the groups around a neutral center.
  final String? hubMemberId;
  final AgUiMemberAvatar? Function(AgUiChatMember member)? resolveMemberAvatar;
  final AgUiTeamPalette palette;

  @override
  State<AgUiTeamGraph> createState() => _AgUiTeamGraphState();
}

class _AgUiTeamGraphState extends State<AgUiTeamGraph>
    with TickerProviderStateMixin {
  // Same design space as the React graph, so both SDKs lay a Team out identically.
  static const _width = 400.0;
  static const _height = 380.0;
  static const _junction = 0.6;
  static const _nodeRadius = 13.0;
  static const _hubRadius = 21.0;
  static const _labelMax = 16;

  /// A box taller than this many times its width is a side panel.
  static const _tallBox = 1.4;

  /// The width, in design units, a tall narrow box is laid out in — three captions side by side, one design unit per pixel.
  static const _narrowWidth = 280.0;

  final TransformationController _view = TransformationController();

  // The member at work blinks slowly.
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_syncAnimation);
    widget.statusSource?.addListener(_syncAnimation);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(AgUiTeamGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_syncAnimation);
      widget.controller?.addListener(_syncAnimation);
    }
    if (oldWidget.statusSource != widget.statusSource) {
      oldWidget.statusSource?.removeListener(_syncAnimation);
      widget.statusSource?.addListener(_syncAnimation);
    }
    if (oldWidget.statuses != widget.statuses) _syncAnimation();
    _syncAnimation();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_syncAnimation);
    widget.statusSource?.removeListener(_syncAnimation);
    _view.dispose();
    _blink.dispose();
    _flow.dispose();
    super.dispose();
  }

  Map<String, TeamMemberStatus> get _memberStatuses => widget.statuses ?? widget.statusSource?.memberStatuses ?? widget.controller?.memberStatuses ?? const {};

  // The link animation only runs while someone is actually working.
  void _syncAnimation() {
    final working = _memberStatuses.containsValue(
      TeamMemberStatus.working,
    );
    if (working && !_flow.isAnimating) {
      _flow.repeat();
      _blink.repeat(reverse: true);
    } else if (!working && _flow.isAnimating) {
      _flow.stop();
      _blink
        ..stop()
        ..value = 0;
    }
  }

  String _truncate(String text) =>
      text.length > _labelMax ? '${text.substring(0, _labelMax - 1)}…' : text;

  /// The drawing space for a box of [width] × [height] pixels: elements keep the size they have at the design size, scaled by
  /// the tighter of the two dimensions, and the ring stretches to the rest of the space (never past 1.4 : 1, so a tall
  /// narrow box gets a centered constellation, not a thread). Mirrors the React graph.
  static _Frame _frameFor(double width, double height) {
    final fitted = math.min(width / _width, height / _height);
    // A tall, narrow box (a side panel) would make everything tiny that way, so there the scale follows the width — down to
    // [_narrowWidth] units across — and the extra height is left to the layout.
    final scale = height > width * _tallBox ? math.max(fitted, math.min(1.0, width / _narrowWidth)) : fitted;
    final w = math.min(width / scale, 1200.0);
    final h = math.min(height / scale, 1200.0);
    final ringX = math.max(w / 2 - 48, 100.0);
    final ringY = math.min(math.max(h / 2 - 58, 85.0), ringX * 1.4);
    return _Frame(
      scale: scale,
      width: w,
      height: h,
      center: Offset(w / 2, h / 2),
      ringX: ringX,
      ringY: ringY,
    );
  }

  static Offset _onRing(_Frame frame, double angle, [double scale = 1]) =>
      frame.center +
      Offset(
        frame.ringX * scale * math.cos(angle),
        frame.ringY * scale * math.sin(angle),
      );

  /// Lays the members out as a constellation: each group gets an angular sector of the ring in proportion to its size, a
  /// junction dot on the way to it, and its members spread across the sector. A member without a group is its own sector,
  /// linked straight to the hub. Mirrors the React graph.
  static List<_Branch> _layout(List<AgUiTeamMember> others, _Frame frame) {
    final units = <List<AgUiTeamMember>>[];
    for (final member in others) {
      final key = agUiTeamGroupKey(member.group);
      if (key != null &&
          units.isNotEmpty &&
          agUiTeamGroupKey(units.last.first.group) == key) {
        units.last.add(member);
      } else {
        units.add([member]);
      }
    }
    final total = math.max(others.length, 1);
    var cursor = -math.pi / 2;
    final branches = <_Branch>[];
    for (final unit in units) {
      final key = agUiTeamGroupKey(unit.first.group);
      final sector = 2 * math.pi * unit.length / total;
      final middle = cursor + sector / 2;
      final junction = key == null ? null : _onRing(frame, middle, _junction);
      final placed = <_Placed>[];
      for (var i = 0; i < unit.length; i++) {
        final angle = cursor + sector * (i + 0.5) / unit.length;
        final flare = unit.length > 1 ? (angle - middle) / sector : 0.0;
        // A crowded group staggers its members on two rings, so their names never touch.
        final scale = unit.length > 3 && i.isOdd ? 0.82 : 1.0;
        placed.add(
          _Placed(
            unit[i],
            _onRing(frame, angle, scale),
            junction ?? frame.center,
            junction == null ? 0.12 : -flare * 0.9,
          ),
        );
      }
      branches.add(
        _Branch(
          key: key,
          name: key == null ? null : unit.first.group!.trim(),
          junction: junction,
          angle: middle,
          members: placed,
        ),
      );
      cursor += sector;
    }
    return branches;
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.members;
    final groupColors = agUiTeamGroupColors(
      members.map((m) => m.group),
      custom: _colorOverrides(members),
    );
    final hub =
        widget.hubMemberId == null
            ? null
            : members
                .where((m) => m.memberEntityId == widget.hubMemberId)
                .firstOrNull;
    final others = agUiOrderByGroup(
      members.where((m) => m != hub),
      (m) => m.group,
    );

    return LayoutBuilder(
      builder: (context, outer) {
        // The graph fills a box whose height is fixed (a SizedBox, an Expanded); otherwise the width decides, at the design
        // aspect ratio.
        final fills = outer.hasTightHeight && outer.maxHeight > 40;
        final width = outer.maxWidth;
        final height = fills ? outer.maxHeight : width * _height / _width;
        final frame = _frameFor(width, height);
        final scale = frame.scale;
        final branches = _layout(others, frame);

        // Every topology but the manager-led one has its own layout; the manager-led one (and a team of unknown shape) keeps
        // the constellation.
        final topology =
            widget.topology ??
            members.map((m) => m.topology).whereType<AgUiTeamTopology>().firstOrNull;
        final byId = {for (final m in members) m.memberEntityId: m};
        TeamScene? scene;
        var sceneGroups = const <SceneGroup>[];
        if (topology != null && topology.kind != AgUiTeamTopologyKind.managerLed) {
          final sceneFrame = SceneFrame(
            width: frame.width,
            height: frame.height,
            center: frame.center,
            ringX: frame.ringX,
            ringY: frame.ringY,
          );
          // A chain keeps the order of the team; every other layout draws a group as one arc / one block.
          final ordered =
              topology.kind == AgUiTeamTopologyKind.sequential
                  ? members
                  : agUiOrderByGroup(members, (m) => m.group);
          scene = sceneFor(
            topology.kind,
            [for (final m in ordered) m.memberEntityId],
            topology.links,
            sceneFrame,
            (id) => agUiTeamGroupKey(byId[id]?.group),
          );
          // In a chain the order is the team's, so a group split by another is drawn once per run of consecutive members.
          final runs = <String, String>{};
          if (topology.kind == AgUiTeamTopologyKind.sequential) {
            String? previous;
            var run = 0;
            for (final m in members) {
              final key = agUiTeamGroupKey(m.group);
              if (key != previous) run++;
              previous = key;
              if (key != null) runs[m.memberEntityId] = '$key#$run';
            }
          }
          sceneGroups = groupsFor(scene!, (id) {
            final member = byId[id];
            final key = agUiTeamGroupKey(member?.group);
            return key == null ? null : (key: runs[id] ?? key, name: member!.group!.trim());
          }, sceneFrame);
        }

        Widget node(
          AgUiTeamMember member,
          Offset at,
          double radius,
          TeamMemberStatus? status,
          bool resting, {
          int? order,
          bool labelAbove = false,
        }) {
          final hexSize = radius * 2 * scale * 1.18;
          final boxSize = hexSize + 10;
          final label = _truncate(
            member.label ?? agUiTeamMemberShortName(member.displayName),
          );
          final hex = _TeamHexNode(
            avatar: resolveMemberAvatar(
              member.asChatMember,
              _memberAvatar(
                member,
                groupColors[agUiTeamGroupKey(member.group)],
                widget.resolveMemberAvatar,
              ),
            ),
            size: hexSize,
            off: status == null && !resting,
            pulse: status == TeamMemberStatus.working ? _blink.value : 0,
            ringColor: status == null ? null : widget.palette.of(status),
            order: order,
            scale: scale,
          );
          final caption = Opacity(
            opacity:
                status == null && !resting
                    ? 0.5
                    : (status == TeamMemberStatus.working
                        ? 1 - 0.45 * _blink.value
                        : 1.0),
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontSize: 8.5 * scale),
            ),
          );
          final body = Semantics(
            label: '${member.displayName}, ${teamMemberStatusText(status)}',
            excludeSemantics: true,
            child: Tooltip(
              message:
                  '${member.displayName} — ${teamMemberStatusText(status)}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    labelAbove
                        ? [caption, const SizedBox(height: 1), hex]
                        : [hex, const SizedBox(height: 1), caption],
              ),
            ),
          );
          // A name above the member is anchored by its bottom edge, so the hexagon stays centered on `at` whatever the name's height.
          return labelAbove
              ? Positioned(
                left: at.dx * scale - 40,
                bottom: height - (at.dy * scale + boxSize / 2),
                width: 80,
                child: body,
              )
              : Positioned(
                left: at.dx * scale - 40,
                top: at.dy * scale - boxSize / 2,
                width: 80,
                child: body,
              );
        }

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              // Drag (mouse or one finger) to move, wheel or pinch to zoom.
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _view,
                  panEnabled: widget.interactive,
                  scaleEnabled: widget.interactive,
                  minScale: 0.5,
                  maxScale: 6,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        if (widget.controller != null) widget.controller!,
                        if (widget.statusSource != null) widget.statusSource!,
                        _flow,
                        _blink,
                      ]),
                      builder: (context, _) {
                        final statuses = _memberStatuses;
                        final running = statuses.isNotEmpty;
                        // Nothing runs and the graph was asked for a still, colored picture of the team.
                        final resting = widget.restingColors && !running;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter:
                                    scene != null
                                        ? _ScenePainter(
                                          scene: scene,
                                          groups: sceneGroups,
                                          members: byId,
                                          statuses: statuses,
                                          colors: groupColors,
                                          palette: widget.palette,
                                          running: !resting,
                                          flow: _flow.value,
                                          scale: scale,
                                          labelColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                          haloColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.surface,
                                        )
                                        : _BranchPainter(
                                          branches: branches,
                                          hasHub: hub != null,
                                          statuses: statuses,
                                          colors: groupColors,
                                          running: !resting,
                                          flow: _flow.value,
                                          scale: scale,
                                          center: frame.center,
                                          labelColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                          haloColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.surface,
                                        ),
                              ),
                            ),
                            ...(scene != null
                                ? [
                                  for (final placed in scene.members)
                                    if (byId[placed.id] case final member?)
                                      node(
                                        member,
                                        placed.at,
                                        _nodeRadius,
                                        statuses[placed.id],
                                        resting,
                                        order: placed.order,
                                        labelAbove: placed.labelAbove,
                                      ),
                                ]
                                : [
                                  for (final branch in branches)
                                    for (final placed in branch.members)
                                      node(
                                        placed.member,
                                        placed.at,
                                        _nodeRadius,
                                        statuses[placed.member.memberEntityId],
                                        resting,
                                      ),
                                  if (hub != null)
                                    node(
                                      hub,
                                      frame.center,
                                      _hubRadius,
                                      statuses[hub.memberEntityId],
                                      resting,
                                    ),
                                ]),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              // The way back to the fitted view.
              if (widget.interactive)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _FitButton(
                    onPressed: () => _view.value = Matrix4.identity(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A small button that puts the graph back to the fitted view.
class _FitButton extends StatelessWidget {
  const _FitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Fit to view',
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              Icons.fit_screen,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The drawing space of an [AgUiTeamGraph]: the scale from design units to pixels, the center, and the ring's radii.
class _Frame {
  const _Frame({
    required this.scale,
    required this.width,
    required this.height,
    required this.center,
    required this.ringX,
    required this.ringY,
  });

  final double scale;

  /// The drawing space in design units.
  final double width;
  final double height;
  final Offset center;
  final double ringX;
  final double ringY;
}

class _Placed {
  const _Placed(this.member, this.at, this.from, this.bend);

  final AgUiTeamMember member;
  final Offset at;

  /// Where the member's link starts: its group's junction, or the hub for a member without a group.
  final Offset from;
  final double bend;
}

class _Branch {
  const _Branch({
    required this.key,
    required this.name,
    required this.junction,
    required this.angle,
    required this.members,
  });

  final String? key;

  /// The group's name as written by the team editor.
  final String? name;
  final Offset? junction;

  /// Direction of the junction from the center, in radians.
  final double angle;
  final List<_Placed> members;
}

// ── Drawing helpers shared by the constellation and the other topologies ─────────────────────────────────────────────────

/// A curve from [a] to [b], bent sideways by [bend] × its length — every link of the graph is one.
Path _curvePath(Offset a, Offset b, double bend) {
  final control = _controlPoint(a, b, bend);
  return Path()
    ..moveTo(a.dx, a.dy)
    ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy);
}

Offset _controlPoint(Offset a, Offset b, double bend) {
  final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  return Offset(mid.dx - (b.dy - a.dy) * bend, mid.dy + (b.dx - a.dx) * bend);
}

/// A small triangle at [tip], pointing the way the curve arrives there (from its control point).
Path _arrowHead(Offset tip, Offset control, double size) {
  final d = tip - control;
  final length = d.distance == 0 ? 1.0 : d.distance;
  final ux = d.dx / length;
  final uy = d.dy / length;
  final base = Offset(tip.dx - ux * size, tip.dy - uy * size);
  final wing = Offset(-uy * size * 0.55, ux * size * 0.55);
  return Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo(base.dx + wing.dx, base.dy + wing.dy)
    ..lineTo(base.dx - wing.dx, base.dy - wing.dy)
    ..close();
}

// Dashes march along the curve toward the working member.
void _dashedPath(Canvas canvas, Path path, Paint paint, double dash, double gap, double flow) {
  for (final metric in path.computeMetrics()) {
    var travelled = -flow * (dash + gap) * 2;
    while (travelled < metric.length) {
      final start = math.max(travelled, 0.0);
      final end = math.min(travelled + dash, metric.length);
      if (end > start) canvas.drawPath(metric.extractPath(start, end), paint);
      travelled += dash + gap;
    }
  }
}

/// A link in its branch's color: faint and dotted once a run has started and its member is not in it, solid when done,
/// animated while working; before any run ([running] false) every link is solid, as a plain picture of the team.
void _drawLink(
  Canvas canvas,
  Path path,
  Color color,
  TeamMemberStatus? status, {
  required bool trunk,
  required bool running,
  required double scale,
  required double flow,
}) {
  final paint =
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
  if (!running) {
    paint
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = (trunk ? 2.4 : 1.5) * scale;
    canvas.drawPath(path, paint);
    return;
  }
  switch (status) {
    case TeamMemberStatus.working:
      paint
        ..color = color
        ..strokeWidth = 2.4 * scale;
      _dashedPath(canvas, path, paint, 6 * scale, 4 * scale, flow);
    case TeamMemberStatus.done:
    case TeamMemberStatus.failed:
      paint
        ..color = color
        ..strokeWidth = 1.8 * scale;
      canvas.drawPath(path, paint);
    case TeamMemberStatus.waiting:
      paint
        ..color = color.withValues(alpha: 0.75)
        ..strokeWidth = 1.8 * scale;
      canvas.drawPath(path, paint);
    case null:
      paint
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 1.0 * scale;
      _dashedPath(canvas, path, paint, 1.5 * scale, 4 * scale, 0);
  }
}

/// The soft zone behind a group: its members' [points] (in design units) thickened into one rounded shape in the group's color.
void _drawZone(Canvas canvas, List<Offset> points, Color color, double scale) {
  final px = [for (final p in points) p * scale];
  final paint = Paint()..color = color.withValues(alpha: 0.11);
  const width = 46.0;
  if (px.length == 1) {
    canvas.drawCircle(px.first, width / 2 * scale, paint);
    return;
  }
  final path = Path()..moveTo(px.first.dx, px.first.dy);
  for (final point in px.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  if (px.length > 2) {
    path.close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }
  canvas.drawPath(
    path,
    Paint()
      ..color = color.withValues(alpha: 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

/// A group's badge — a pill with its color, its name in capitals and its size. [centerFor] gives the pill's center (in pixels)
/// from its width; [width] forces that width (in pixels) instead of measuring the text.
void _drawPill(
  Canvas canvas, {
  required String name,
  required int count,
  required Color color,
  required double scale,
  required Color labelColor,
  required Color haloColor,
  required Offset Function(double width) centerFor,
  double? width,
}) {
  TextPainter text(String value, Color textColor, FontWeight weight) =>
      TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontSize: 8.5 * scale,
            fontWeight: weight,
            letterSpacing: 8.5 * scale * 0.14,
            color: textColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  final label = text(name.toUpperCase(), color, FontWeight.w700);
  final countText = text('$count', labelColor.withValues(alpha: 0.5), FontWeight.w500);
  final height = 15.0 * scale;
  final pillWidth =
      width ??
      9 * scale + 7 * scale + label.width + 8 * scale + countText.width + 8 * scale;
  final centerPoint = centerFor(pillWidth);
  final rect = RRect.fromRectAndRadius(
    Rect.fromCenter(center: centerPoint, width: pillWidth, height: height),
    Radius.circular(height / 2),
  );
  canvas.drawRRect(rect, Paint()..color = haloColor);
  canvas.drawRRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale
      ..color = color.withValues(alpha: 0.55),
  );
  final left = rect.left;
  canvas.drawCircle(Offset(left + 9 * scale, centerPoint.dy), 2.4 * scale, Paint()..color = color);
  label.paint(canvas, Offset(left + 16 * scale, centerPoint.dy - label.height / 2));
  countText.paint(canvas, Offset(rect.right - 8 * scale - countText.width, centerPoint.dy - countText.height / 2));
}

/// Draws the constellation's links, junction dots and group names. A link is drawn in its branch's color: faint and dotted
/// once a run has started and its member is not in it, solid when done, animated while working; before any run every link is
/// solid, as a plain picture of the team.
class _BranchPainter extends CustomPainter {
  _BranchPainter({
    required this.branches,
    required this.hasHub,
    required this.statuses,
    required this.colors,
    required this.running,
    required this.flow,
    required this.scale,
    required this.center,
    required this.labelColor,
    required this.haloColor,
  });

  final List<_Branch> branches;
  final bool hasHub;
  final Map<String, TeamMemberStatus> statuses;
  final Map<String, Color> colors;
  final bool running;
  final double flow;
  final double scale;
  final Offset center;
  final Color labelColor;
  final Color haloColor;

  TeamMemberStatus? _litStatus(_Branch branch) {
    final all = [
      for (final p in branch.members) statuses[p.member.memberEntityId],
    ];
    if (all.contains(TeamMemberStatus.working)) return TeamMemberStatus.working;
    if (all.contains(TeamMemberStatus.waiting)) return TeamMemberStatus.waiting;
    if (all.contains(TeamMemberStatus.done)) return TeamMemberStatus.done;
    return null;
  }

  void _link(Canvas canvas, Path path, Color color, TeamMemberStatus? status, {required bool trunk}) =>
      _drawLink(canvas, path, color, status, trunk: trunk, running: running, scale: scale, flow: flow);

  @override
  void paint(Canvas canvas, Size size) {
    for (final branch in branches) {
      final color = colors[branch.key];
      if (color != null) {
        _drawZone(canvas, [for (final p in branch.members) p.at], color, scale);
      }
    }
    for (final branch in branches) {
      final color = colors[branch.key] ?? labelColor.withValues(alpha: 0.5);
      final lit = _litStatus(branch);
      final junction = branch.junction;
      if (hasHub && junction != null) {
        _link(
          canvas,
          _curvePath(center * scale, junction * scale, 0.14),
          color,
          lit,
          trunk: true,
        );
      }
      if (hasHub || junction != null) {
        for (final p in branch.members) {
          _link(
            canvas,
            _curvePath(p.from * scale, p.at * scale, p.bend),
            color,
            statuses[p.member.memberEntityId],
            trunk: false,
          );
        }
      }
      if (junction != null) {
        final active = !running || lit != null;
        canvas.drawCircle(
          junction * scale,
          2.6 * scale,
          Paint()..color = color.withValues(alpha: active ? 1.0 : 0.4),
        );
        if (branch.name != null) _label(canvas, branch, color);
      }
    }
  }

  // The group's badge, set beside its junction, clear of the links.
  void _label(Canvas canvas, _Branch branch, Color color) {
    final px = -math.sin(branch.angle);
    final py = math.cos(branch.angle);
    final j = branch.junction! * scale;
    _drawPill(
      canvas,
      name: branch.name!,
      count: branch.members.length,
      color: color,
      scale: scale,
      labelColor: labelColor,
      haloColor: haloColor,
      centerFor: (width) => Offset(j.dx + px * (width / 2 + 6 * scale), j.dy + py * 13 * scale),
    );
  }

  @override
  bool shouldRepaint(_BranchPainter old) =>
      old.flow != flow ||
      old.running != running ||
      old.statuses != statuses ||
      old.branches != branches ||
      old.scale != scale ||
      old.colors != colors;
}

/// Draws every topology but the manager-led one: the soft zone and the name badge of each group, the band that holds many
/// parallel members, the links between members (directed ones end in a head) and the start / join / shared-conversation dots.
/// Links are lit by the status of the member they lead to, in that member's group color.
class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.scene,
    required this.groups,
    required this.members,
    required this.statuses,
    required this.colors,
    required this.palette,
    required this.running,
    required this.flow,
    required this.scale,
    required this.labelColor,
    required this.haloColor,
  });

  final TeamScene scene;
  final List<SceneGroup> groups;
  final Map<String, AgUiTeamMember> members;
  final Map<String, TeamMemberStatus> statuses;
  final Map<String, Color> colors;
  final AgUiTeamPalette palette;
  final bool running;
  final double flow;
  final double scale;
  final Color labelColor;
  final Color haloColor;

  static const _muted = Color(0xFF94A3B8);

  // A group split by another in a chain is drawn once per run (key `group#run`); the color is the group's.
  Color? _groupColor(String key) => colors[key.replaceAll(RegExp(r'#\d+$'), '')];

  TeamMemberStatus? _anyStatus() {
    final all = [for (final id in members.keys) statuses[id]];
    if (all.contains(TeamMemberStatus.working)) return TeamMemberStatus.working;
    if (all.contains(TeamMemberStatus.waiting)) return TeamMemberStatus.waiting;
    if (all.contains(TeamMemberStatus.done)) return TeamMemberStatus.done;
    return null;
  }

  bool get _everyoneDone => members.isNotEmpty && members.keys.every((id) => statuses[id] == TeamMemberStatus.done);

  @override
  void paint(Canvas canvas, Size size) {
    for (final group in groups) {
      final color = _groupColor(group.key);
      if (color != null) _drawZone(canvas, group.points, color, scale);
    }

    final band = scene.band;
    if (band != null) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(band.left * scale, band.top * scale, band.width * scale, band.height * scale),
        Radius.circular(18 * scale),
      );
      canvas.drawRRect(rect, Paint()..color = _muted.withValues(alpha: 0.08));
      _dashedPath(
        canvas,
        Path()..addRRect(rect),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale
          ..color = _muted.withValues(alpha: 0.45),
        3 * scale,
        4 * scale,
        0,
      );
    }

    for (final edge in scene.edges) {
      _paintEdge(canvas, edge);
    }

    for (final group in groups) {
      _drawPill(
        canvas,
        name: group.name,
        count: group.ids.length,
        color: _groupColor(group.key) ?? labelColor.withValues(alpha: 0.5),
        scale: scale,
        labelColor: labelColor,
        haloColor: haloColor,
        width: scenePillWidth(group.name) * scale,
        centerFor: (_) => group.label * scale,
      );
    }

    for (final dot in scene.dots) {
      _paintDot(canvas, dot);
    }
  }

  void _paintEdge(Canvas canvas, SceneEdge edge) {
    final a = shortenLink(edge.from, edge.to, edge.fromInset) * scale;
    final b = shortenLink(edge.to, edge.from, edge.toInset) * scale;
    final status = switch (edge.lit) {
      sceneLitAny => statuses.isEmpty ? null : (_anyStatus() == null ? null : TeamMemberStatus.done),
      sceneLitAll => _everyoneDone ? TeamMemberStatus.done : null,
      final id => statuses[id],
    };
    final color =
        members.containsKey(edge.lit)
            ? (_groupColor(agUiTeamGroupKey(members[edge.lit]!.group) ?? '') ?? labelColor.withValues(alpha: 0.5))
            : (edge.lit == sceneLitAny || edge.lit == sceneLitAll ? palette.done : labelColor.withValues(alpha: 0.5));
    _drawLink(canvas, _curvePath(a, b, edge.bend), color, status, trunk: false, running: running, scale: scale, flow: flow);
    if (edge.arrow) {
      final alpha = !running
          ? 0.6
          : switch (status) {
            TeamMemberStatus.done || TeamMemberStatus.working || TeamMemberStatus.failed => 1.0,
            TeamMemberStatus.waiting => 0.75,
            null => 0.4,
          };
      canvas.drawPath(
        _arrowHead(b, _controlPoint(a, b, edge.bend), 6.5 * scale),
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }

  void _paintDot(Canvas canvas, SceneDot dot) {
    final at = dot.at * scale;
    switch (dot.kind) {
      case SceneDotKind.center:
        final status = _anyStatus();
        final stroke = switch (status) {
          TeamMemberStatus.working => palette.working,
          TeamMemberStatus.waiting => palette.waiting,
          TeamMemberStatus.done => palette.done,
          _ => const Color(0xFFC8CCD4),
        };
        canvas.drawCircle(at, 11 * scale, Paint()..color = haloColor);
        canvas.drawCircle(
          at,
          11 * scale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * scale
            ..color = stroke,
        );
        for (final dx in const [-4.5, 0.0, 4.5]) {
          canvas.drawCircle(at + Offset(dx * scale, 0), 1.5 * scale, Paint()..color = _muted);
        }
      case SceneDotKind.start:
      case SceneDotKind.join:
        final done = dot.kind == SceneDotKind.start ? statuses.isNotEmpty : _everyoneDone;
        canvas.drawCircle(
          at,
          (dot.kind == SceneDotKind.start ? 4.5 : 5.5) * scale,
          Paint()..color = done ? palette.done : _muted.withValues(alpha: 0.55),
        );
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.flow != flow ||
      old.running != running ||
      old.statuses != statuses ||
      old.scene != scene ||
      old.groups != groups ||
      old.scale != scale ||
      old.colors != colors;
}

/// One member of [AgUiTeamGraph]: a hexagon (the shape Team Studio draws) whose border and icon wear the member's color —
/// its group's, or the app's own — on a neutral fill. A status ring surrounds it while the member is in the run.
class _TeamHexNode extends StatelessWidget {
  const _TeamHexNode({
    required this.avatar,
    required this.size,
    this.ringColor,
    this.off = false,
    this.pulse = 0,
    this.order,
    this.scale = 1,
  });

  /// The member's step number in a chain, drawn as a small badge on its hexagon.
  final int? order;

  /// Pixels per design unit, for the badge.
  final double scale;

  final AgUiMemberAvatar avatar;
  final double size;
  final Color? ringColor;

  /// A run has started and has not needed this member yet: the hexagon is switched off — grey and dim. Its fill stays solid,
  /// so the links running under it never show through.
  final bool off;

  /// 0 to 1: how far the member at work is into its slow blink — its border and icon fade by up to 45 %.
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base =
        off
            ? scheme.outline.withValues(alpha: 0.6)
            : (avatar.color ?? scheme.outline);
    final accent = base.withValues(alpha: base.a * (1 - 0.45 * pulse));
    final glyph = avatar.emoji == null ? agUiIcon(avatar.icon) : null;
    final content =
        avatar.imageUrl != null
            ? ClipPath(
              clipper: const _HexClipper(),
              child: Image.network(
                avatar.imageUrl!,
                width: size * 0.9,
                height: size * 0.9,
                fit: BoxFit.cover,
              ),
            )
            : glyph != null
            ? Icon(glyph, size: size * 0.5, color: accent)
            : Text(
              avatar.emoji ?? avatar.initials ?? '?',
              style: TextStyle(
                fontSize: size * 0.34,
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            );

    final hex = SizedBox(
      width: size + 10,
      height: size + 10,
      child: CustomPaint(
        painter: _HexPainter(
          fill: scheme.surface,
          border: accent,
          ring: ringColor,
        ),
        child: Center(child: content),
      ),
    );
    if (order == null) return hex;
    final r = 6.2 * scale;
    final middle = (size + 10) / 2;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        hex,
        Positioned(
          left: middle - size / 2 * 0.9 - r,
          top: middle - size / 2 * 0.95 - r,
          width: r * 2,
          height: r * 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surface,
              border: Border.all(color: accent, width: 1.4 * scale),
            ),
            child: Center(
              child: Text(
                '$order',
                style: TextStyle(
                  fontSize: 7.5 * scale,
                  height: 1,
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Path _hexPath(Offset center, double radius) {
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final angle = math.pi / 180 * (60 * i - 90);
    final point =
        center + Offset(radius * math.cos(angle), radius * math.sin(angle));
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size size) =>
      _hexPath(size.center(Offset.zero), size.shortestSide / 2);

  @override
  bool shouldReclip(_HexClipper old) => false;
}

class _HexPainter extends CustomPainter {
  const _HexPainter({required this.fill, required this.border, this.ring});

  final Color fill;
  final Color border;
  final Color? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 5;
    final hex = _hexPath(center, radius);
    canvas.drawPath(hex, Paint()..color = fill);
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = border,
    );
    if (ring != null) {
      canvas.drawPath(
        _hexPath(center, radius + 4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..color = ring!,
      );
    }
  }

  @override
  bool shouldRepaint(_HexPainter old) =>
      old.fill != fill || old.border != border || old.ring != ring;
}
