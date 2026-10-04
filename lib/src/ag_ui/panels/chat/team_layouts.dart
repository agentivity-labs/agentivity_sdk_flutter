import 'dart:math' as math;
import 'dart:ui';

import 'team_topology.dart';

/// Where each topology puts the members of a team in the graph — pure geometry, no drawing. A manager-led team keeps its
/// hub-and-groups constellation (see `AgUiTeamGraph`); the other four kinds are laid out here (mirrors the React SDK):
///
/// - sequential: a chain that snakes row by row, each member linked to the next, numbered in order;
/// - concurrent: a start, parallel lanes (a band when there are many), a join;
/// - handoff: peers on a ring, linked by the directed links of the team definition, the first member being the entry;
/// - group chat: peers on a ring around the shared conversation they all take part in.

/// The drawing space in design units: its size and the center and radii of the ring members sit on.
class SceneFrame {
  const SceneFrame({
    required this.width,
    required this.height,
    required this.center,
    required this.ringX,
    required this.ringY,
  });
  final double width;
  final double height;
  final Offset center;
  final double ringX;
  final double ringY;
}

/// A member's place in the scene. [order] is its 1-based position in a chain; [labelAbove] puts its name above it.
class ScenePlacement {
  const ScenePlacement(this.id, this.at, {this.order, this.labelAbove = false});
  final String id;
  final Offset at;
  final int? order;
  final bool labelAbove;
}

/// Which member's status lights a link: [any] / [all] stand for the whole team (lit once any member is in the run / once
/// every member is done).
const sceneLitAny = '*any';
const sceneLitAll = '*all';

/// A link of the scene; [arrow] puts a head at its end, [fromInset] / [toInset] stop it short of each end.
class SceneEdge {
  const SceneEdge(
    this.key,
    this.from,
    this.to,
    this.bend,
    this.lit,
    this.arrow,
    this.fromInset,
    this.toInset,
  );
  final String key;
  final Offset from;
  final Offset to;
  final double bend;
  final String lit;
  final bool arrow;
  final double fromInset;
  final double toInset;
}

enum SceneDotKind { start, join, center }

/// A point of the scene that is not a member: where a run starts, where parallel work joins, the shared conversation.
class SceneDot {
  const SceneDot(this.kind, this.at);
  final SceneDotKind kind;
  final Offset at;
}

class TeamScene {
  const TeamScene({
    required this.members,
    required this.edges,
    required this.dots,
    this.band,
  });
  final List<ScenePlacement> members;
  final List<SceneEdge> edges;
  final List<SceneDot> dots;

  /// The rounded band that holds many parallel members.
  final Rect? band;
}

const double memberInset = 20;
const double _dotInset = 6;
const double _minCellWidth = 78;
const int _maxLanes = 6;

/// The most a row of a chain may be tall: rows farther apart than this read as unrelated.
const double _maxRowHeight = 118;

/// A frame narrower than this (in design units) is a side panel.
const double _narrowFrame = 360;

/// Captions are at most 16 characters (about 70 units): in a narrow frame a cell may be just wide enough for one.
const double _narrowMinCellWidth = 72;

Offset _onEllipse(SceneFrame frame, double angle, [double scale = 1]) =>
    frame.center +
    Offset(
      frame.ringX * scale * math.cos(angle),
      frame.ringY * scale * math.sin(angle),
    );

({int cols, int rows, double cellW, double cellH}) _gridFor(
  int n,
  double width,
  double height, [
  double minCell = _minCellWidth,
  bool fillWidth = false,
]) {
  final maxCols = math.max(1, (width / minCell).floor());
  // [fillWidth]: as many columns as the width holds, rather than the number that best matches the box's shape.
  var cols =
      n <= math.min(4, maxCols)
          ? n
          : fillWidth
          ? math.min(n, maxCols)
          : math.max(
            1,
            math.min(
              math.min(n, maxCols),
              math.sqrt(n * (width / math.max(height, 1))).round(),
            ),
          );
  final rows = math.max(1, (n / cols).ceil());
  cols = math.max(1, (n / rows).ceil());
  return (cols: cols, rows: rows, cellW: width / cols, cellH: height / rows);
}

SceneEdge _edge(
  String key,
  Offset from,
  Offset to,
  double bend,
  String lit,
  bool arrow,
  double fromInset,
  double toInset,
) => SceneEdge(key, from, to, bend, lit, arrow, fromInset, toInset);

/// Chain: members on a serpentine grid in the order given, each linked to the next (or by the links given).
TeamScene sequentialScene(
  List<String> ids,
  List<AgUiTeamLink> links,
  SceneFrame frame,
) {
  final n = ids.length;
  // A narrow frame (a side panel) gives up its margins and its caption room so the chain can use the whole width.
  final narrow = frame.width < _narrowFrame;
  final padX = narrow ? 22.0 : 46.0;
  const padY = 50.0;
  final usableW = math.max(frame.width - 2 * padX, 1.0);
  final usableH = math.max(frame.height - 2 * padY, 1.0);
  final grid = _gridFor(n, usableW, usableH, narrow ? _narrowMinCellWidth : _minCellWidth, narrow);
  // A tall frame would spread the rows far apart: they keep a steady spacing and the chain is centered vertically.
  final cellH = math.min(grid.cellH, _maxRowHeight);
  final top = (frame.height - grid.rows * cellH) / 2;

  final members = <ScenePlacement>[];
  for (var i = 0; i < n; i++) {
    final row = i ~/ grid.cols;
    final slot = i % grid.cols;
    // Every other row runs the other way, so the end of one row sits right above the start of the next.
    final col = row.isEven ? slot : grid.cols - 1 - slot;
    members.add(
      ScenePlacement(
        ids[i],
        Offset(
          padX + (col + 0.5) * grid.cellW,
          top + (row + 0.5) * cellH,
        ),
        order: i + 1,
      ),
    );
  }
  final at = {for (final m in members) m.id: m.at};

  final pairs =
      links.isNotEmpty
          ? links
              .where((l) => at.containsKey(l.from) && at.containsKey(l.to))
              .toList()
          : [for (var i = 1; i < n; i++) AgUiTeamLink(ids[i - 1], ids[i])];
  final edges = <SceneEdge>[];
  for (var i = 0; i < pairs.length; i++) {
    final from = at[pairs[i].from]!;
    final to = at[pairs[i].to]!;
    edges.add(
      _edge(
        'chain-$i',
        from,
        to,
        (from.dy - to.dy).abs() < 1 ? 0.1 : 0,
        pairs[i].to,
        true,
        memberInset,
        memberInset,
      ),
    );
  }
  return TeamScene(members: members, edges: edges, dots: const []);
}

/// Parallel work: a start on the left, a lane per member (or one band holding them all when there are many), a join on the right.
TeamScene concurrentScene(
  List<String> ids,
  SceneFrame frame, [
  String? Function(String id)? groupOf,
]) {
  final n = ids.length;
  final start = Offset(14, frame.center.dy);
  final join = Offset(frame.width - 14, frame.center.dy);
  final dots = [
    SceneDot(SceneDotKind.start, start),
    SceneDot(SceneDotKind.join, join),
  ];

  if (n <= _maxLanes) {
    final step = math.min((frame.height - 100) / math.max(n, 1), 64.0);
    final members = [
      for (var i = 0; i < n; i++)
        ScenePlacement(
          ids[i],
          Offset(frame.center.dx, frame.center.dy + (i - (n - 1) / 2) * step),
        ),
    ];
    final edges = <SceneEdge>[];
    for (var i = 0; i < members.length; i++) {
      final m = members[i];
      final side = (m.at.dy - frame.center.dy).sign;
      edges.add(
        _edge(
          'out-$i',
          start,
          m.at,
          side * -0.16,
          m.id,
          true,
          _dotInset,
          memberInset,
        ),
      );
      edges.add(
        _edge(
          'in-$i',
          m.at,
          join,
          side * -0.16,
          m.id,
          true,
          memberInset,
          _dotInset,
        ),
      );
    }
    return TeamScene(members: members, edges: edges, dots: dots);
  }

  // Many members: they sit in a grid inside one band — "all at once" — entered from the start and left towards the join.
  final bandLeft = 42.0;
  final bandRight = frame.width - 42;
  const padX = 16.0;
  const padY = 30.0;
  final boxW = bandRight - bandLeft - 2 * padX;
  final boxH = math.max(frame.height - 2 * padY - 20, 1.0);
  final grouped = ids.any((id) => groupOf?.call(id) != null);
  final cols =
      grouped
          ? math.max(1, math.min(n, (boxW / 66).floor()))
          : _gridFor(n, boxW, boxH, 66).cols;
  final cellW = boxW / cols;
  // Each group fills its own rows (a group is one block, not a run that wraps into the next group's row).
  final rowsOf = <List<String>>[];
  var current = <String>[];
  String? currentGroup;
  for (final id in ids) {
    final group = groupOf?.call(id);
    if (current.isNotEmpty &&
        (current.length == cols || group != currentGroup)) {
      rowsOf.add(current);
      current = [];
    }
    current.add(id);
    currentGroup = group;
  }
  if (current.isNotEmpty) rowsOf.add(current);
  final cellH = math.min(boxH / rowsOf.length, 96.0);
  final gridH = rowsOf.length * cellH;
  final top = frame.center.dy - gridH / 2;
  final members = <ScenePlacement>[];
  for (var row = 0; row < rowsOf.length; row++) {
    final rowIds = rowsOf[row];
    for (var col = 0; col < rowIds.length; col++) {
      // A short row is centered, not pushed to the left.
      members.add(
        ScenePlacement(
          rowIds[col],
          Offset(
            bandLeft +
                padX +
                ((cols - rowIds.length) * cellW) / 2 +
                (col + 0.5) * cellW,
            top + (row + 0.5) * cellH,
          ),
        ),
      );
    }
  }
  final band = Rect.fromLTWH(
    bandLeft,
    top - 22,
    bandRight - bandLeft,
    gridH + 44,
  );
  final edges = [
    _edge(
      'in',
      start,
      Offset(band.left, frame.center.dy),
      0,
      sceneLitAny,
      true,
      _dotInset,
      1,
    ),
    _edge(
      'out',
      Offset(band.right, frame.center.dy),
      join,
      0,
      sceneLitAll,
      true,
      1,
      _dotInset,
    ),
  ];
  return TeamScene(members: members, edges: edges, dots: dots, band: band);
}

/// Peers on a ring linked by the team's directed links; the first member is the entry, reached from outside the ring.
TeamScene handoffScene(
  List<String> ids,
  List<AgUiTeamLink> links,
  SceneFrame frame,
) {
  final members = _ring(ids, frame, keepFirstBelow: true);
  final at = {for (final m in members) m.id: m.at};
  final edges = <SceneEdge>[];
  var i = 0;
  for (final l in links) {
    if (!at.containsKey(l.from) || !at.containsKey(l.to)) continue;
    edges.add(
      _edge(
        'link-${i++}',
        at[l.from]!,
        at[l.to]!,
        0.22,
        l.to,
        true,
        memberInset,
        memberInset + 3,
      ),
    );
  }
  final dots = <SceneDot>[];
  if (ids.isNotEmpty) {
    final entry = _onEllipse(frame, -math.pi / 2, 1.34);
    dots.add(SceneDot(SceneDotKind.start, entry));
    edges.add(
      _edge(
        'entry',
        entry,
        members.first.at,
        0,
        members.first.id,
        true,
        _dotInset,
        memberInset + 3,
      ),
    );
  }
  return TeamScene(members: members, edges: edges, dots: dots);
}

/// Peers on a ring, each linked to the conversation they all take part in at the center.
TeamScene groupChatScene(List<String> ids, SceneFrame frame) {
  final members = _ring(ids, frame);
  final edges = [
    for (var i = 0; i < members.length; i++)
      _edge(
        'spoke-$i',
        frame.center,
        members[i].at,
        0,
        members[i].id,
        false,
        12,
        memberInset,
      ),
  ];
  return TeamScene(
    members: members,
    edges: edges,
    dots: [SceneDot(SceneDotKind.center, frame.center)],
  );
}

/// Lays out [ids] for a topology kind other than manager-led; null for the kind the graph draws as a constellation.
TeamScene? sceneFor(
  AgUiTeamTopologyKind kind,
  List<String> ids,
  List<AgUiTeamLink> links,
  SceneFrame frame, [
  String? Function(String id)? groupOf,
]) => switch (kind) {
  AgUiTeamTopologyKind.sequential => sequentialScene(ids, links, frame),
  AgUiTeamTopologyKind.concurrent => concurrentScene(ids, frame, groupOf),
  AgUiTeamTopologyKind.handoff => handoffScene(ids, links, frame),
  AgUiTeamTopologyKind.groupChat => groupChatScene(ids, frame),
  AgUiTeamTopologyKind.managerLed => null,
};

/// Members evenly spaced on the ring, the first at the top. Those in the upper part carry their name above.
List<ScenePlacement> _ring(
  List<String> ids,
  SceneFrame frame, {
  bool keepFirstBelow = false,
}) {
  final n = math.max(ids.length, 1);
  return [
    for (var i = 0; i < ids.length; i++)
      () {
        final angle = -math.pi / 2 + (2 * math.pi * i) / n;
        return ScenePlacement(
          ids[i],
          _onEllipse(frame, angle),
          // The entry of a handoff is reached from above, so its name stays below it.
          labelAbove: math.sin(angle) < -0.3 && !(keepFirstBelow && i == 0),
        );
      }(),
  ];
}

/// The point [inset] away from [a] on the way to [b].
Offset shortenLink(Offset a, Offset b, double inset) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final length = math.sqrt(dx * dx + dy * dy);
  final t = math.min(inset / (length == 0 ? 1 : length), 0.45);
  return Offset(a.dx + dx * t, a.dy + dy * t);
}

// ── Groups ─────────────────────────────────────────────────────────────────────────────────────────────────────────────

/// A group of the team as drawn: the members' positions (for the soft zone behind them) and where its name badge sits.
class SceneGroup {
  const SceneGroup({
    required this.key,
    required this.name,
    required this.ids,
    required this.points,
    required this.label,
  });
  final String key;
  final String name;
  final List<String> ids;
  final List<Offset> points;

  /// Center of the badge.
  final Offset label;
}

const double _pillHeight = 16;

/// Width of a group's badge: its name in capitals, a dot and the member count.
double scenePillWidth(String name) => name.length * 6.9 + 38;

bool _overlaps(Rect a, Rect b, [double margin = 2]) =>
    a.left < b.right + margin &&
    a.right > b.left - margin &&
    a.top < b.bottom + margin &&
    a.bottom > b.top - margin;

Rect _memberBox(ScenePlacement m) => Rect.fromLTRB(
  m.at.dx - 34,
  m.at.dy - (m.labelAbove ? 34 : 18),
  m.at.dx + 34,
  m.at.dy + (m.labelAbove ? 18 : 28),
);

/// The groups of a scene, each with the badge carrying its name. A badge goes to the free place nearest its group: the frame
/// is scanned for positions clear of every member (name included), of the start / join / center dots and of the badges
/// already placed, and the one closest to the group's members — a little above them rather than below — wins.
List<SceneGroup> groupsFor(
  TeamScene scene,
  ({String key, String name})? Function(String id) groupOf,
  SceneFrame frame,
) {
  final byKey = <String, ({String name, List<ScenePlacement> placed})>{};
  for (final placed in scene.members) {
    final group = groupOf(placed.id);
    if (group == null) continue;
    final entry = byKey.putIfAbsent(
      group.key,
      () => (name: group.name, placed: <ScenePlacement>[]),
    );
    entry.placed.add(placed);
  }

  final obstacles = <Rect>[
    for (final m in scene.members) _memberBox(m),
    for (final d in scene.dots)
      Rect.fromLTRB(d.at.dx - 10, d.at.dy - 10, d.at.dx + 10, d.at.dy + 10),
  ];
  final taken = <Rect>[];
  final result = <SceneGroup>[];

  for (final entry in byKey.entries) {
    final name = entry.value.name;
    final placed = entry.value.placed;
    final points = [for (final m in placed) m.at];
    final w = scenePillWidth(name);
    final centroidY =
        points.fold<double>(0, (sum, q) => sum + q.dy) / points.length;
    Rect boxAt(Offset c) => Rect.fromLTRB(
      c.dx - w / 2,
      c.dy - _pillHeight / 2,
      c.dx + w / 2,
      c.dy + _pillHeight / 2,
    );
    bool free(Rect box) =>
        box.left >= 2 &&
        box.right <= frame.width - 2 &&
        box.top >= 2 &&
        box.bottom <= frame.height - 2 &&
        !obstacles.any((o) => _overlaps(box, o)) &&
        !taken.any((t) => _overlaps(box, t));

    Offset? best;
    var bestScore = double.infinity;
    for (
      var y = _pillHeight / 2 + 2;
      y <= frame.height - _pillHeight / 2 - 2;
      y += 4
    ) {
      for (var x = w / 2 + 2; x <= frame.width - w / 2 - 2; x += 4) {
        final c = Offset(x, y);
        if (!free(boxAt(c))) continue;
        var nearest = double.infinity;
        for (final q in points) {
          nearest = math.min(nearest, (q - c).distance);
        }
        final score = nearest + (y > centroidY ? 6 : 0);
        if (score < bestScore) {
          bestScore = score;
          best = c;
        }
      }
    }

    // Nothing free (a crowded frame): over the group's first member, kept in the frame.
    final label =
        best ??
        _clampToFrame(
          Offset(points.first.dx - 16 + w / 2, points.first.dy - 33),
          w,
          frame,
        );
    taken.add(boxAt(label));
    result.add(
      SceneGroup(
        key: entry.key,
        name: name,
        ids: [for (final m in placed) m.id],
        points: points,
        label: label,
      ),
    );
  }
  return result;
}

Offset _clampToFrame(Offset c, double width, SceneFrame frame) => Offset(
  c.dx.clamp(
    width / 2 + 2,
    math.max(frame.width - width / 2 - 2, width / 2 + 2),
  ),
  c.dy.clamp(
    _pillHeight / 2 + 2,
    math.max(frame.height - _pillHeight / 2 - 2, _pillHeight / 2 + 2),
  ),
);
