import 'dart:convert';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

final _team = {
  'id': 'team-1',
  'name': 'SEO team',
  'role': 'Turns a keyword into a reviewed article.',
  'orchestratorId': 'manager-led',
  'managerAgentId': 'p1',
  'members': [
    {'topologyPositionId': 'p1', 'memberEntityId': 'a-writer', 'memberType': 'agent'},
    {'topologyPositionId': 'p2', 'memberEntityId': 'a-reviewer', 'memberType': 'agent'},
  ],
  'connections': [],
};
final _writer = {
  'id': 'a-writer',
  'name': 'Writer',
  'role': 'Writes the draft',
  'tags': ['seo'],
  'graph': {
    'id': 'g1',
    'entryNode': 'agent',
    'nodes': [
      {'id': 'agent', 'nodeType': 'ai.node', 'inputs': {}},
    ],
    'connections': [],
  },
};
final _reviewer = {
  'id': 'a-reviewer',
  'name': 'Reviewer',
  'graph': {
    'id': 'g2',
    'entryNode': 'agent',
    'nodes': [
      {'id': 'agent', 'nodeType': 'ai.node', 'inputs': {}},
    ],
    'connections': [],
  },
};
final _workflow = {
  'id': 'wf-1',
  'name': 'Publish',
  'entryNode': 'start',
  'nodes': [
    {'id': 'start', 'nodeType': 'core.start', 'inputs': {}},
    {'id': 'send', 'nodeType': 'core.http', 'inputs': {}},
  ],
  'connections': [
    {'from': 'start', 'to': 'send', 'fromPort': 'out', 'toPort': 'in'},
  ],
};

Map<String, dynamic> _templateFile({Map<String, dynamic> extra = const {}}) => {
  'schema': 'agentivity.template',
  'schemaVersion': 1,
  'id': 'seo-factory',
  'version': '1.0.0',
  'name': 'SEO factory',
  'root': {'kind': 'team', 'id': 'team-1'},
  'entities': [
    {'kind': 'team', 'id': 'team-1', 'name': 'SEO team', 'entry': _team},
    {'kind': 'agent', 'id': 'a-writer', 'name': 'Writer', 'entry': _writer},
    {'kind': 'agent', 'id': 'a-reviewer', 'name': 'Reviewer', 'entry': _reviewer},
    {'kind': 'workflow', 'id': 'wf-1', 'name': 'Publish', 'entry': _workflow},
  ],
  ...extra,
};

Matcher _throwsCode(RenderableErrorCode code) => throwsA(isA<RenderableError>().having((e) => e.code, 'code', code));

void main() {
  group('resolveRenderable — a Template file', () {
    test('is the graph of its root, with the other entities giving names', () {
      final r = resolveRenderable(_templateFile());
      expect(r.kind, RenderableKind.team);
      expect(r.id, 'team-1');
      expect(r.name, 'SEO team');
      expect(r.entity['orchestratorId'], 'manager-led');
      expect(
        r.entitiesById['a-writer'],
        const RenderableEntity(kind: 'agent', id: 'a-writer', name: 'Writer', role: 'Writes the draft', tags: ['seo']),
      );
      expect(r.entitiesById['a-reviewer']?.name, 'Reviewer');
      expect(r.template?.id, 'seo-factory');
      expect(r.template?.name, 'SEO factory');
      expect(r.template?.version, '1.0.0');
    });

    test('can have a workflow or an agent as its root', () {
      expect(resolveRenderable(_templateFile(extra: {'root': {'kind': 'workflow', 'id': 'wf-1'}})).kind, RenderableKind.workflow);
      expect(resolveRenderable(_templateFile(extra: {'root': {'kind': 'agent', 'id': 'a-writer'}})).kind, RenderableKind.agent);
    });

    test('still reads the older catalog wrapper for an entity', () {
      final file = _templateFile();
      (file['entities'] as List)[0] = {'kind': 'team', 'id': 'team-1', 'name': 'SEO team', 'entryJson': jsonEncode(_team)};
      expect(resolveRenderable(file).entity['name'], 'SEO team');
    });

    test('says when the root is missing or not something to draw', () {
      expect(() => resolveRenderable(_templateFile(extra: {'root': {'kind': 'team', 'id': 'nope'}})), _throwsCode(RenderableErrorCode.rootNotFound));
      final table = _templateFile(
        extra: {
          'root': {'kind': 'datatable', 'id': 'tbl'},
          'entities': [
            {
              'kind': 'datatable',
              'id': 'tbl',
              'name': 'T',
              'entry': {'id': 'tbl', 'columns': []},
            },
          ],
        },
      );
      expect(() => resolveRenderable(table), _throwsCode(RenderableErrorCode.unsupportedKind));
    });
  });

  group('resolveRenderable — what the marketplace serves', () {
    test('reads the root payload: the wrapper and the members map', () {
      final r = resolveRenderable({
        'kind': 'team',
        'name': 'SEO team',
        'entryJson': jsonEncode(_team),
        'members': {
          'a-writer': {'kind': 'agent', 'name': 'Writer', 'role': 'Writes the draft', 'tags': []},
          'a-reviewer': {'kind': 'agent', 'name': 'Reviewer'},
        },
      });
      expect(r.kind, RenderableKind.team);
      expect(r.entitiesById['a-writer']?.role, 'Writes the draft');
      expect(r.entitiesById['a-reviewer']?.name, 'Reviewer');
      expect(r.template, isNull);
    });

    test('reads the wrapper alone, with the entity as a map or as a JSON text', () {
      expect(resolveRenderable({'kind': 'workflow', 'name': 'Publish', 'entryJson': _workflow}).kind, RenderableKind.workflow);
      final r = resolveRenderable({'kind': 'agent', 'name': 'Writer', 'entryJson': jsonEncode(_writer)});
      expect(r.kind, RenderableKind.agent);
      expect(r.entitiesById, isEmpty);
    });
  });

  group('resolveRenderable — bare entities and text', () {
    test('tells a team, a workflow and an agent apart by their shape', () {
      expect(resolveRenderable(_team).kind, RenderableKind.team);
      expect(resolveRenderable(_workflow).kind, RenderableKind.workflow);
      expect(resolveRenderable(_writer).kind, RenderableKind.agent);
    });

    test('accepts the JSON text of any of them', () {
      expect(resolveRenderable(jsonEncode(_templateFile())).kind, RenderableKind.team);
      expect(resolveRenderable(jsonEncode(_workflow)).kind, RenderableKind.workflow);
    });
  });

  group('resolveRenderable — what it refuses', () {
    test('names the problem', () {
      expect(() => resolveRenderable('not json'), _throwsCode(RenderableErrorCode.notJson));
      expect(() => resolveRenderable(42), _throwsCode(RenderableErrorCode.notAnObject));
      expect(() => resolveRenderable(<Object?>[]), _throwsCode(RenderableErrorCode.notAnObject));
      expect(() => resolveRenderable({'hello': 'world'}), _throwsCode(RenderableErrorCode.unsupportedKind));
      expect(
        () => resolveRenderable({
          'kind': 'datatable',
          'name': 'T',
          'entryJson': {'columns': []},
        }),
        _throwsCode(RenderableErrorCode.unsupportedKind),
      );
      expect(() => resolveRenderable({'kind': 'team', 'entryJson': '{broken'}), _throwsCode(RenderableErrorCode.unreadableEntity));
    });

    test('has a quiet version', () {
      expect(tryResolveRenderable('not json'), isNull);
      expect(tryResolveRenderable(_team)?.kind, RenderableKind.team);
    });
  });

  group('resolveRenderable — the marketplace envelope', () {
    test('takes off { data } and reads what is inside', () {
      final payload = {
        'kind': 'team',
        'name': 'SEO team',
        'entryJson': jsonEncode(_team),
        'members': {
          'a-writer': {'kind': 'agent', 'name': 'Writer'},
        },
      };
      final r = resolveRenderable({'data': payload});
      expect(r.kind, RenderableKind.team);
      expect(r.entitiesById['a-writer']?.name, 'Writer');
      expect(
        resolveRenderable({
          'data': _templateFile(),
          'meta': {'total': 1},
        }).template?.id,
        'seo-factory',
      );
      expect(resolveRenderable(jsonEncode({'data': _workflow})).kind, RenderableKind.workflow);
    });

    test('does not mistake an entity that has a `data` field for an envelope', () {
      expect(
        resolveRenderable({
          ..._workflow,
          'data': {'whatever': 1},
        }).kind,
        RenderableKind.workflow,
      );
    });
  });
}
