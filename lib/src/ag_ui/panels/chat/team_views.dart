import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../client/app_client/domain/team_definition_models.dart';
import '../../../icons/icon_ref.dart';
import 'chat_controller.dart';
import 'member_avatar.dart';
import 'team_appearance.dart';

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
  List<AgUiTeamMember> toTeamMembers() => [
    for (final m in members)
      AgUiTeamMember(
        memberEntityId: m.memberEntityId,
        displayName: m.displayName ?? m.memberEntityId,
        icon: m.icon,
        group: m.group,
        groupColor: agUiParseHexColor(groupColors[agUiTeamGroupKey(m.group)]),
      ),
  ];

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
    this.idle = const Color(0xFFCBD5E1),
  });
  final Color working;
  final Color waiting;
  final Color done;
  final Color idle;

  Color of(TeamMemberStatus? status) => switch (status) {
    TeamMemberStatus.working => working,
    TeamMemberStatus.waiting => waiting,
    TeamMemberStatus.done => done,
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
  });

  final ChatController controller;

  /// Every member of the Team, in the order to show them.
  final List<AgUiTeamMember> members;
  final AgUiMemberAvatar? Function(AgUiChatMember member)? resolveMemberAvatar;
  final AgUiTeamPalette palette;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final statuses = controller.memberStatuses;
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
    required this.controller,
    required this.members,
    this.hubMemberId,
    this.resolveMemberAvatar,
    this.palette = const AgUiTeamPalette(),
    this.restingColors = false,
  });

  final ChatController controller;
  final List<AgUiTeamMember> members;

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
    widget.controller.addListener(_syncAnimation);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(AgUiTeamGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncAnimation);
      widget.controller.addListener(_syncAnimation);
    }
    _syncAnimation();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncAnimation);
    _view.dispose();
    _blink.dispose();
    _flow.dispose();
    super.dispose();
  }

  // The link animation only runs while someone is actually working.
  void _syncAnimation() {
    final working = widget.controller.memberStatuses.containsValue(
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
    final scale = math.min(width / _width, height / _height);
    final w = math.min(width / scale, 1200.0);
    final h = math.min(height / scale, 1200.0);
    final ringX = math.max(w / 2 - 48, 100.0);
    final ringY = math.min(math.max(h / 2 - 58, 85.0), ringX * 1.4);
    return _Frame(
      scale: scale,
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
        Widget node(
          AgUiTeamMember member,
          Offset at,
          double radius,
          TeamMemberStatus? status,
          bool resting,
        ) {
          final hexSize = radius * 2 * scale * 1.18;
          final boxSize = hexSize + 10;
          final label = _truncate(
            member.label ?? agUiTeamMemberShortName(member.displayName),
          );
          return Positioned(
            left: at.dx * scale - 40,
            top: at.dy * scale - boxSize / 2,
            width: 80,
            child: Semantics(
              label: '${member.displayName}, ${teamMemberStatusText(status)}',
              excludeSemantics: true,
              child: Tooltip(
                message:
                    '${member.displayName} — ${teamMemberStatusText(status)}',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TeamHexNode(
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
                      pulse:
                          status == TeamMemberStatus.working ? _blink.value : 0,
                      ringColor:
                          status == null ? null : widget.palette.of(status),
                    ),
                    const SizedBox(height: 1),
                    Opacity(
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
                    ),
                  ],
                ),
              ),
            ),
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
                  minScale: 0.5,
                  maxScale: 6,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        widget.controller,
                        _flow,
                        _blink,
                      ]),
                      builder: (context, _) {
                        final statuses = widget.controller.memberStatuses;
                        final running = statuses.isNotEmpty;
                        // Nothing runs and the graph was asked for a still, colored picture of the team.
                        final resting = widget.restingColors && !running;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _BranchPainter(
                                  branches: branches,
                                  hasHub: hub != null,
                                  statuses: statuses,
                                  colors: groupColors,
                                  running: !resting,
                                  flow: _flow.value,
                                  scale: scale,
                                  center: frame.center,
                                  labelColor:
                                      Theme.of(context).colorScheme.onSurface,
                                  haloColor:
                                      Theme.of(context).colorScheme.surface,
                                ),
                              ),
                            ),
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
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              // The way back to the fitted view.
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
    required this.center,
    required this.ringX,
    required this.ringY,
  });

  final double scale;
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

  static Path _curve(Offset a, Offset b, double bend) {
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final control = Offset(
      mid.dx - (b.dy - a.dy) * bend,
      mid.dy + (b.dx - a.dx) * bend,
    );
    return Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy);
  }

  TeamMemberStatus? _litStatus(_Branch branch) {
    final all = [
      for (final p in branch.members) statuses[p.member.memberEntityId],
    ];
    if (all.contains(TeamMemberStatus.working)) return TeamMemberStatus.working;
    if (all.contains(TeamMemberStatus.waiting)) return TeamMemberStatus.waiting;
    if (all.contains(TeamMemberStatus.done)) return TeamMemberStatus.done;
    return null;
  }

  void _link(
    Canvas canvas,
    Path path,
    Color color,
    TeamMemberStatus? status, {
    required bool trunk,
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
        _dashed(canvas, path, paint, 6 * scale, 4 * scale, flow);
      case TeamMemberStatus.done:
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
        _dashed(canvas, path, paint, 1.5 * scale, 4 * scale, 0);
    }
  }

  // Dashes march along the curve toward the working member.
  static void _dashed(
    Canvas canvas,
    Path path,
    Paint paint,
    double dash,
    double gap,
    double flow,
  ) {
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

  // The soft zone behind a group: its members' positions thickened into one rounded shape in the group's color.
  void _zone(Canvas canvas, _Branch branch, Color color) {
    final points = [for (final p in branch.members) p.at * scale];
    final paint = Paint()..color = color.withValues(alpha: 0.11);
    const width = 46.0;
    if (points.length == 1) {
      canvas.drawCircle(points.first, width / 2 * scale, paint);
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    if (points.length > 2) {
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

  @override
  void paint(Canvas canvas, Size size) {
    for (final branch in branches) {
      final color = colors[branch.key];
      if (color != null) _zone(canvas, branch, color);
    }
    for (final branch in branches) {
      final color = colors[branch.key] ?? labelColor.withValues(alpha: 0.5);
      final lit = _litStatus(branch);
      final junction = branch.junction;
      if (hasHub && junction != null) {
        _link(
          canvas,
          _curve(center * scale, junction * scale, 0.14),
          color,
          lit,
          trunk: true,
        );
      }
      if (hasHub || junction != null) {
        for (final p in branch.members) {
          _link(
            canvas,
            _curve(p.from * scale, p.at * scale, p.bend),
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

  // The group's badge — a pill with its color, its name in capitals and its size — set beside its junction, clear of the links.
  void _label(Canvas canvas, _Branch branch, Color color) {
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

    final name = text(branch.name!.toUpperCase(), color, FontWeight.w700);
    final count = text(
      '${branch.members.length}',
      labelColor.withValues(alpha: 0.5),
      FontWeight.w500,
    );
    final height = 15.0 * scale;
    final width =
        9 * scale +
        7 * scale +
        name.width +
        8 * scale +
        count.width +
        8 * scale;
    final px = -math.sin(branch.angle);
    final py = math.cos(branch.angle);
    final j = branch.junction! * scale;
    final centerPoint = Offset(
      j.dx + px * (width / 2 + 6 * scale),
      j.dy + py * 13 * scale,
    );
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: centerPoint, width: width, height: height),
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
    canvas.drawCircle(
      Offset(left + 9 * scale, centerPoint.dy),
      2.4 * scale,
      Paint()..color = color,
    );
    name.paint(
      canvas,
      Offset(left + 16 * scale, centerPoint.dy - name.height / 2),
    );
    count.paint(
      canvas,
      Offset(
        rect.right - 8 * scale - count.width,
        centerPoint.dy - count.height / 2,
      ),
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

/// One member of [AgUiTeamGraph]: a hexagon (the shape Team Studio draws) whose border and icon wear the member's color —
/// its group's, or the app's own — on a neutral fill. A status ring surrounds it while the member is in the run.
class _TeamHexNode extends StatelessWidget {
  const _TeamHexNode({
    required this.avatar,
    required this.size,
    this.ringColor,
    this.off = false,
    this.pulse = 0,
  });

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

    return SizedBox(
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
