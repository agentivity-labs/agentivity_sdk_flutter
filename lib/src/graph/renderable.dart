import 'dart:convert';

/// What a graph can be drawn from. The platform, the marketplace and the files people share all describe the same entities
/// (a team, a workflow, an agent) in slightly different envelopes; [resolveRenderable] accepts any of them and hands back the
/// one thing to draw, with the names and roles of what it points to. Mirrors the React SDK's `resolveRenderable`.
///
/// Accepted sources (a map, or the JSON text of one):
/// - a **Template file** (`schema: "agentivity.template"`): the graph of its `root`, the other entities giving names to members;
/// - the **root payload** of the marketplace (`GET /templates/{id}/root`): the catalog wrapper `{ kind, name, entryJson }` plus
///   a `members` map (id → name, role, tags) for the entities it references;
/// - the catalog **wrapper** alone (`entryJson` being a map or a JSON string);
/// - a **bare entity** as the platform stores it (a team with `members`, a workflow with `nodes`, an agent with `graph`).
///
/// Any of them may come still wrapped in the marketplace's answer envelope (`{ data: ... }`): it is taken off.
enum RenderableKind { team, workflow, agent }

/// What a drawing needs to know about an entity the root points to.
class RenderableEntity {
  const RenderableEntity({required this.kind, required this.id, required this.name, this.role, this.tags = const []});
  final String kind;
  final String id;
  final String name;
  final String? role;
  final List<String> tags;

  @override
  bool operator ==(Object other) =>
      other is RenderableEntity && kind == other.kind && id == other.id && name == other.name && role == other.role && _sameList(tags, other.tags);

  @override
  int get hashCode => Object.hash(kind, id, name, role, Object.hashAll(tags));
}

/// The Template a [Renderable] came from.
class RenderableTemplate {
  const RenderableTemplate({required this.id, required this.name, this.version});
  final String id;
  final String name;
  final String? version;
}

class Renderable {
  const Renderable({
    required this.kind,
    required this.id,
    required this.name,
    required this.entity,
    this.entitiesById = const {},
    this.template,
  });
  final RenderableKind kind;
  final String id;
  final String name;

  /// The entity to draw, as a map (the platform's own JSON).
  final Map<String, dynamic> entity;

  /// Names and roles of the entities the root points to, by id (empty for a bare entity or a bare wrapper).
  final Map<String, RenderableEntity> entitiesById;

  /// Set when the source was a Template file.
  final RenderableTemplate? template;
}

enum RenderableErrorCode { notJson, notAnObject, unreadableEntity, unsupportedKind, rootNotFound }

class RenderableError implements Exception {
  const RenderableError(this.code, this.message);
  final RenderableErrorCode code;
  final String message;

  @override
  String toString() => message;
}

const _kinds = ['team', 'workflow', 'agent'];

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Map<String, dynamic>? _rec(Object? value) => value is Map ? Map<String, dynamic>.from(value) : null;

String? _text(Object? value) {
  if (value is! String) return null;
  final t = value.trim();
  return t.isEmpty ? null : t;
}

List<String> _strings(Object? value) => value is List ? value.whereType<String>().toList(growable: false) : const [];

/// The entity inside an item: `entry` (a map), or the older `entryJson` (a map, or a JSON text).
Map<String, dynamic>? _entryOf(Map<String, dynamic> item) {
  final entry = _rec(item['entry']);
  if (entry != null) return entry;
  final wrapped = item['entryJson'];
  if (wrapped is Map) return _rec(wrapped);
  if (wrapped is String) {
    try {
      return _rec(jsonDecode(wrapped));
    } catch (_) {
      return null;
    }
  }
  return null;
}

RenderableEntity _describe(String kind, String id, String? name, Map<String, dynamic>? entry) =>
    RenderableEntity(kind: kind, id: id, name: name ?? _text(entry?['name']) ?? id, role: _text(entry?['role']), tags: _strings(entry?['tags']));

/// What kind of entity a bare map is, from its shape.
RenderableKind? _guessKind(Map<String, dynamic> entity) {
  if (entity['members'] is List && _text(entity['orchestratorId']) != null) return RenderableKind.team;
  final graph = _rec(entity['graph']);
  if (graph != null && graph['nodes'] is List) return RenderableKind.agent;
  if (entity['nodes'] is List) return RenderableKind.workflow;
  return null;
}

RenderableKind? _toKind(Object? value) {
  final kind = _text(value)?.toLowerCase();
  if (kind == null || !_kinds.contains(kind)) return null;
  return RenderableKind.values.firstWhere((k) => k.name == kind);
}

Renderable _fromTemplate(Map<String, dynamic> file) {
  final items = (file['entities'] is List ? file['entities'] as List : const []).map(_rec).whereType<Map<String, dynamic>>();
  final byId = <String, RenderableEntity>{};
  final entries = <String, Map<String, dynamic>>{};
  for (final item in items) {
    final id = _text(item['id']);
    final kind = _text(item['kind']);
    if (id == null || kind == null) continue;
    final entry = _entryOf(item);
    if (entry != null) entries[id] = entry;
    byId[id] = _describe(kind, id, _text(item['name']), entry);
  }

  final root = _rec(file['root']);
  final rootId = _text(root?['id']);
  final entity = rootId == null ? null : entries[rootId];
  if (rootId == null || entity == null) {
    throw const RenderableError(RenderableErrorCode.rootNotFound, 'The Template does not contain its root.');
  }
  final kind = _toKind(root?['kind']) ?? _toKind(byId[rootId]?.kind);
  if (kind == null) {
    throw const RenderableError(RenderableErrorCode.unsupportedKind, 'The root of a Template is a team, a workflow or an agent.');
  }
  return Renderable(
    kind: kind,
    id: rootId,
    name: byId[rootId]?.name ?? _text(entity['name']) ?? rootId,
    entity: entity,
    entitiesById: byId,
    template: RenderableTemplate(id: _text(file['id']) ?? '', name: _text(file['name']) ?? '', version: _text(file['version'])),
  );
}

Renderable _fromWrapper(Map<String, dynamic> wrapper) {
  final entity = _entryOf(wrapper);
  if (entity == null) {
    throw const RenderableError(RenderableErrorCode.unreadableEntity, 'The entity inside the wrapper cannot be read.');
  }
  final kind = _toKind(wrapper['kind']) ?? _guessKind(entity);
  if (kind == null) {
    throw RenderableError(RenderableErrorCode.unsupportedKind, 'This kind of item is not a graph (${_text(wrapper['kind']) ?? 'unknown'}).');
  }
  final byId = <String, RenderableEntity>{};
  // The marketplace gives the entities the root points to as a map: id -> { kind, name, role, tags }.
  final members = _rec(wrapper['members']);
  if (members != null) {
    for (final e in members.entries) {
      final value = _rec(e.value);
      if (value != null) {
        byId[e.key] = RenderableEntity(
          kind: _text(value['kind']) ?? 'agent',
          id: e.key,
          name: _text(value['name']) ?? e.key,
          role: _text(value['role']),
          tags: _strings(value['tags']),
        );
      }
    }
  }
  final id = _text(entity['id']) ?? '';
  return Renderable(kind: kind, id: id, name: _text(wrapper['name']) ?? _text(entity['name']) ?? id, entity: entity, entitiesById: byId);
}

Renderable _fromBare(Map<String, dynamic> entity) {
  final kind = _guessKind(entity);
  if (kind == null) {
    throw const RenderableError(RenderableErrorCode.unsupportedKind, 'This object is not a team, a workflow or an agent.');
  }
  final id = _text(entity['id']) ?? '';
  return Renderable(kind: kind, id: id, name: _text(entity['name']) ?? id, entity: entity);
}

/// The one thing to draw from any of the accepted sources. Throws a [RenderableError] saying what is wrong.
Renderable resolveRenderable(Object? source) {
  Object? value = source;
  if (value is String) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      throw const RenderableError(RenderableErrorCode.notJson, 'The text is not JSON.');
    }
  }
  final map = _rec(value);
  if (map == null) {
    throw const RenderableError(RenderableErrorCode.notAnObject, 'Nothing to draw: expected a Template, a team, a workflow or an agent.');
  }
  // The marketplace answers { data: ... } (or { data, meta }): what to draw is inside.
  if (_rec(map['data']) != null &&
      map['schema'] == null &&
      !map.containsKey('entryJson') &&
      !map.containsKey('entry') &&
      _guessKind(map) == null) {
    return resolveRenderable(map['data']);
  }
  if (map['schema'] == 'agentivity.template') return _fromTemplate(map);
  if (map.containsKey('entryJson') || map.containsKey('entry')) return _fromWrapper(map);
  return _fromBare(map);
}

/// Like [resolveRenderable], but `null` instead of an error.
Renderable? tryResolveRenderable(Object? source) {
  try {
    return resolveRenderable(source);
  } on RenderableError {
    return null;
  }
}
