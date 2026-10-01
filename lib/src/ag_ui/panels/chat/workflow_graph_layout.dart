import 'dart:ui';

import '../../../client/app_client/domain/workflow_graph_models.dart';

/// Lays a Workflow's graph out left-to-right and finds the loop-back edges — pure logic, no
/// Flutter widget dependency, so it's trivially unit-testable. Mirrors the React SDK's
/// `workflow-graph-layout.ts` exactly (same column/row gaps, same cycle-breaking DFS).

const colGap = 132.0;
const rowGap = 92.0;
const margin = 56.0;

String edgeKey(String from, String to) => '$from->$to';

class WorkflowLayout {
  const WorkflowLayout({
    required this.positions,
    required this.width,
    required this.height,
    required this.backEdges,
  });
  final Map<String, Offset> positions;
  final double width;
  final double height;

  /// `"from->to"` keys of edges that loop back to an earlier layer (a retry loop) — drawn as a
  /// dashed arc instead of the usual left-to-right curve.
  final Set<String> backEdges;
}

/// Lays a Workflow's graph out left-to-right, one column per "distance from the start" (a node's
/// layer = the longest path to it from the entry node, over the graph with cycles broken), rows
/// within a column ordered by a breadth-first walk so a chain of nodes reads top to bottom in the
/// order it actually runs.
///
/// Cycles (a retry loop back to an earlier node) are real in a workflow graph and must not hang
/// the layering pass: a DFS classifies each edge as a tree/forward/cross edge (kept) or a back
/// edge (a target already on the current DFS path) — back edges are excluded from layering and
/// reported separately in [WorkflowLayout.backEdges] for the caller to draw differently.
WorkflowLayout layoutWorkflowGraph(WorkflowGraphStructure structure) {
  final ids = [for (final n in structure.nodes) n.id];
  final idSet = ids.toSet();
  if (ids.isEmpty) {
    return const WorkflowLayout(positions: {}, width: 0, height: 0, backEdges: {});
  }

  final adjacency = {for (final id in ids) id: <String>[]};
  for (final e in structure.edges) {
    if (idSet.contains(e.from) && idSet.contains(e.to)) adjacency[e.from]!.add(e.to);
  }

  // DFS cycle breaking: 0 = unvisited, 1 = on the current path, 2 = done. An edge to a node on
  // the current path is a back edge — excluded from the DAG the rest of this function lays out.
  final color = {for (final id in ids) id: 0};
  final backEdges = <String>{};
  final dag = {for (final id in ids) id: <String>[]};
  void dfs(String u) {
    color[u] = 1;
    for (final v in adjacency[u] ?? const []) {
      final c = color[v];
      if (c == 1) {
        backEdges.add(edgeKey(u, v));
      } else {
        dag[u]!.add(v);
        if (c == 0) dfs(v);
      }
    }
    color[u] = 2;
  }

  final incoming = {for (final e in structure.edges) if (idSet.contains(e.to)) e.to};
  final roots = structure.entryNodeId != null && idSet.contains(structure.entryNodeId)
      ? [structure.entryNodeId!]
      : ids.where((id) => !incoming.contains(id)).toList();
  for (final r in roots.isNotEmpty ? roots : ids) {
    if (color[r] == 0) dfs(r);
  }
  for (final id in ids) {
    if (color[id] == 0) dfs(id); // any node unreached from a root (disconnected)
  }

  // Layer = longest path from a root, via a topological pass over the (now acyclic) dag.
  final indegree = {for (final id in ids) id: 0};
  for (final tos in dag.values) {
    for (final t in tos) indegree[t] = (indegree[t] ?? 0) + 1;
  }
  final layer = {for (final id in ids) id: 0};
  final topoQueue = ids.where((id) => (indegree[id] ?? 0) == 0).toList();
  while (topoQueue.isNotEmpty) {
    final u = topoQueue.removeAt(0);
    for (final v in dag[u] ?? const []) {
      layer[v] = [layer[v] ?? 0, (layer[u] ?? 0) + 1].reduce((a, b) => a > b ? a : b);
      final left = (indegree[v] ?? 0) - 1;
      indegree[v] = left;
      if (left == 0) topoQueue.add(v);
    }
  }

  // Row order within each layer: a breadth-first walk from the roots, so a straight chain of
  // nodes keeps reading top-to-bottom instead of an arbitrary order.
  final layers = <int, List<String>>{};
  final placed = <String>{};
  void place(String id) {
    if (placed.contains(id)) return;
    placed.add(id);
    final l = layer[id] ?? 0;
    layers.putIfAbsent(l, () => []).add(id);
  }

  final bfsQueue = [...(roots.isNotEmpty ? roots : ids)];
  final bfsSeen = bfsQueue.toSet();
  while (bfsQueue.isNotEmpty) {
    final u = bfsQueue.removeAt(0);
    place(u);
    for (final v in dag[u] ?? const []) {
      if (bfsSeen.add(v)) bfsQueue.add(v);
    }
  }
  for (final id in ids) place(id); // anything still unplaced (disconnected from every root)

  final maxRows = layers.values.map((l) => l.length).fold(1, (a, b) => a > b ? a : b);
  final positions = <String, Offset>{};
  for (final entry in layers.entries) {
    final l = entry.key;
    final idsInLayer = entry.value;
    final total = idsInLayer.length;
    for (var i = 0; i < total; i++) {
      positions[idsInLayer[i]] = Offset(
        margin + l * colGap,
        margin + ((maxRows - total) / 2 + i) * rowGap,
      );
    }
  }

  final maxLayer = layers.keys.fold(0, (a, b) => a > b ? a : b);
  return WorkflowLayout(
    positions: positions,
    width: margin * 2 + maxLayer * colGap,
    height: margin * 2 + (maxRows - 1) * rowGap,
    backEdges: backEdges,
  );
}

/// A left-to-right S-curve between two node centers — the standard flowchart connector shape.
Path flowCurve(Offset a, Offset b) {
  final dx = ((b.dx - a.dx) / 2).abs().clamp(36.0, double.infinity) * (b.dx >= a.dx ? 1 : -1);
  return Path()
    ..moveTo(a.dx, a.dy)
    ..cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy);
}

/// A loop-back connector (a retry edge to an earlier column) — arcs below both nodes rather than
/// crossing straight through the diagram.
Path loopCurve(Offset a, Offset b) {
  final dip = (a.dy > b.dy ? a.dy : b.dy) + 54;
  return Path()
    ..moveTo(a.dx, a.dy)
    ..cubicTo(a.dx, dip, b.dx, dip, b.dx, b.dy);
}
