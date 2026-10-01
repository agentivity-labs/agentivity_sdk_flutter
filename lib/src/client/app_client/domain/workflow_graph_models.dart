/// A minimal, display-only shape of a Workflow's node graph — enough to draw a flow diagram
/// (`AgUiWorkflowGraph`), never enough to edit one. Deliberately NOT the full node-editor model
/// ([WorkflowEntity]'s own doc comment calls that "Studio-editor territory", out of this SDK's
/// scope) — this reads the same raw `GET /workflows/{id}` response [WorkflowEntity] already
/// discards `nodes`/`connections` from, but keeps only what a flow diagram needs: a node's
/// identity/kind and the *execution-flow* edges between them. Mirrors the React SDK's
/// `workflow-graph-models.ts` exactly, field for field.

/// A node's broad visual role — which icon/shape [AgUiWorkflowGraph] draws for it, not a platform concept.
enum WorkflowNodeKind { start, decision, human, ai, end, action }

class WorkflowGraphNode {
  const WorkflowGraphNode({
    required this.id,
    required this.displayName,
    required this.nodeType,
    required this.kind,
  });
  final String id;
  final String displayName;

  /// The node's actual catalog type (e.g. `ai.llm.prompt`, `core.if`) — [kind] is derived from this.
  final String nodeType;
  final WorkflowNodeKind kind;
}

class WorkflowGraphEdge {
  const WorkflowGraphEdge({required this.from, required this.to, this.label});
  final String from;
  final String to;

  /// A branch condition's label (e.g. a `core.if` node's "Yes"/"No"), when the source port carries one.
  final String? label;
}

class WorkflowGraphStructure {
  const WorkflowGraphStructure({
    required this.nodes,
    required this.edges,
    this.entryNodeId,
  });
  final List<WorkflowGraphNode> nodes;
  final List<WorkflowGraphEdge> edges;
  final String? entryNodeId;

  static WorkflowNodeKind _kindFor(String nodeType) {
    if (nodeType == 'core.if' || nodeType.startsWith('core.switch'))
      return WorkflowNodeKind.decision;
    if (nodeType.startsWith('interaction.')) return WorkflowNodeKind.human;
    if (nodeType.startsWith('ai.')) return WorkflowNodeKind.ai;
    return WorkflowNodeKind.action;
  }

  static String? _branchLabel(Map<String, dynamic>? source, String port) {
    final inputs = source?['inputs'];
    final Map<String, dynamic>? inputsMap = inputs is Map
        ? Map<String, dynamic>.from(inputs)
        : null;
    String? key;
    if (port == 'true') {
      key = 'true_branch_label';
    } else if (port == 'false') {
      key = 'false_branch_label';
    }
    final explicit = key == null ? null : inputsMap?[key];
    if (explicit is String && explicit.trim().isNotEmpty) return explicit.trim();
    return port != 'out' && port != 'in' ? port : null;
  }

  /// Parses the flow-diagram-relevant subset of a Workflow's raw definition — the same
  /// `Map<String, dynamic>` `EntitiesApi.fetchWorkflow` receives from `GET /workflows/{id}`
  /// before narrowing it down to [WorkflowEntity]. Only nodes reachable through an
  /// execution-flow edge (or the entry node) are kept — a resource/credential binding (an LLM
  /// model, a chat channel, ...) always sources from a port literally named `resource`, so
  /// filtering those out drops the wiring nodes along with them, leaving just the path a run
  /// actually walks.
  factory WorkflowGraphStructure.fromJson(Map<String, dynamic> json) {
    final rawNodes = (json['nodes'] is List ? json['nodes'] as List : const [])
        .whereType<Object>()
        .map((n) => n is Map<String, dynamic> ? n : Map<String, dynamic>.from(n as Map))
        .toList();
    final rawConnections = (json['connections'] is List ? json['connections'] as List : const [])
        .whereType<Object>()
        .map((c) => c is Map<String, dynamic> ? c : Map<String, dynamic>.from(c as Map))
        .toList();
    final entryNodeId = (json['entryNode'] as String?)?.trim();
    final entryNode = entryNodeId != null && entryNodeId.isNotEmpty ? entryNodeId : null;

    final nodeById = <String, Map<String, dynamic>>{
      for (final n in rawNodes)
        if ((n['id'] as String?)?.trim().isNotEmpty ?? false) (n['id'] as String).trim(): n,
    };

    final edges = <WorkflowGraphEdge>[];
    final referenced = <String>{};
    for (final c in rawConnections) {
      final from = (c['from'] as String?)?.trim();
      final to = (c['to'] as String?)?.trim();
      final fromPort = (c['fromPort'] as String?)?.trim();
      if (from == null || from.isEmpty || to == null || to.isEmpty || fromPort == 'resource')
        continue;
      edges.add(
        WorkflowGraphEdge(
          from: from,
          to: to,
          label: fromPort != null ? _branchLabel(nodeById[from], fromPort) : null,
        ),
      );
      referenced..add(from)..add(to);
    }
    if (entryNode != null) referenced.add(entryNode);

    final hasOutgoing = {for (final e in edges) e.from};
    final nodes = referenced.map((id) {
      final raw = nodeById[id];
      final nodeType = (raw?['nodeType'] as String?) ?? '';
      final metadata = raw?['metadata'];
      final metadataMap = metadata is Map ? Map<String, dynamic>.from(metadata) : null;
      final displayName = (metadataMap?['displayName'] as String?) ?? id;
      // The entry node always reads as "start"; a node nothing flows out of reads as "end" —
      // both override the type-derived kind, which only matters for everything in between.
      final kind = id == entryNode
          ? WorkflowNodeKind.start
          : !hasOutgoing.contains(id)
          ? WorkflowNodeKind.end
          : _kindFor(nodeType);
      return WorkflowGraphNode(id: id, displayName: displayName, nodeType: nodeType, kind: kind);
    }).toList(growable: false);

    return WorkflowGraphStructure(nodes: nodes, edges: edges, entryNodeId: entryNode);
  }
}
