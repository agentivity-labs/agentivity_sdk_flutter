import 'dart:convert';

import 'package:flutter/foundation.dart';

// The cockpits of Agentivity Desk: the starting page of each department, made of blocks. The Desk reads them as published
// ([CockpitView]); the Studio builds them as drafts and publishes them ([ManagedCockpit]).

String? _text(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _date(dynamic raw) => raw == null ? null : DateTime.tryParse(raw.toString());

List<String> _strings(dynamic raw) => raw is List ? raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList(growable: false) : const [];

Map<String, dynamic> _map(dynamic raw) => raw is Map<String, dynamic> ? raw : raw is Map ? Map<String, dynamic>.from(raw) : const {};

List<Map<String, dynamic>> _maps(dynamic raw) => raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false) : const [];

/// The kinds of block of a cockpit, as the instance names them.
abstract final class CockpitBlockType {
  /// Its top, in its colour: its name, and a line of what it is for (`text`).
  static const hero = 'hero';

  /// The field to ask one of its Solutions (`hint`).
  static const ask = 'ask';

  /// What its Solutions suggest to ask (`title`, `count`).
  static const suggestions = 'suggestions';

  /// What waits for the person's answer in it.
  static const waiting = 'waiting';

  /// What its Solutions saved this month: the department, and the person's part.
  static const gains = 'gains';

  /// Its Solutions to start (`title`, `entityIds`: some of them; none, all).
  static const solutions = 'solutions';

  /// The person's conversations with its Solutions (`title`, `count`).
  static const conversations = 'conversations';

  /// A text (`title`, `body`): paragraphs, and lines that start with "- ".
  static const text = 'text';

  /// A news of the department (`title`, `body`, `tone`: info, success or warning, `until`: its last day, yyyy-MM-dd).
  static const announcement = 'announcement';

  /// Links (`title`, `links`: each a `label`, a `url`, a `note`).
  static const links = 'links';

  /// A button that starts a Solution with what to say already written (`entityId`, `label`, `prompt`, `note`).
  static const launch = 'launch';

  /// A figure of a Data Table (`label`, `tableId`, `kind`: count, sum, average, min or max, `column`, `filterColumn`,
  /// `filterValue`, `unit`).
  static const metric = 'metric';

  /// The rows of a Data Table (`title`, `tableId`, `columns`, `count`, `sortColumn`, `descending`).
  static const table = 'table';

  static const all = [hero, ask, suggestions, waiting, gains, solutions, conversations, text, announcement, links, launch, metric, table];
}

/// A link of a links block.
@immutable
class CockpitLink {
  const CockpitLink({required this.label, required this.url, this.note});

  final String label;
  final String url;
  final String? note;

  factory CockpitLink.fromJson(Map<String, dynamic> json) => CockpitLink(label: _text(json['label']) ?? '', url: _text(json['url']) ?? '', note: _text(json['note']));

  Map<String, dynamic> toJson() => {'label': label, 'url': url, if (note != null) 'note': note};
}

/// A block of a cockpit: its kind ([CockpitBlockType]), its width in twelfths of the page on a wide screen (4, 6, 8 or 12), and
/// what it is set to show.
@immutable
class CockpitBlock {
  const CockpitBlock({required this.id, required this.type, this.span = 12, this.settings = const {}});

  final String id;
  final String type;
  final int span;
  final Map<String, dynamic> settings;

  /// The widths a block may take: a third, a half, two thirds, all of the page.
  static const spans = [4, 6, 8, 12];

  factory CockpitBlock.fromJson(Map<String, dynamic> json) => CockpitBlock(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        span: (json['span'] as num?)?.toInt() ?? 12,
        settings: Map<String, dynamic>.from(_map(json['settings'])),
      );

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'span': span, 'settings': settings};

  String? text(String key) => _text(settings[key]);

  int? number(String key) => (settings[key] as num?)?.toInt();

  bool? flag(String key) => settings[key] is bool ? settings[key] as bool : null;

  List<String> strings(String key) => _strings(settings[key]);

  List<CockpitLink> get links => _maps(settings['links']).map(CockpitLink.fromJson).toList(growable: false);

  /// The same block, with [key] set to [value] (null or empty: taken away).
  CockpitBlock withSetting(String key, Object? value) {
    final next = Map<String, dynamic>.from(settings);
    if (value == null || value is String && value.trim().isEmpty || value is List && value.isEmpty) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return CockpitBlock(id: id, type: type, span: span, settings: next);
  }

  CockpitBlock copyWith({String? id, int? span, Map<String, dynamic>? settings}) => CockpitBlock(id: id ?? this.id, type: type, span: span ?? this.span, settings: settings ?? this.settings);

  // The same block is one that says the same: what shows it reads it again only when it changed.
  @override
  bool operator ==(Object other) => other is CockpitBlock && other.id == id && other.type == type && other.span == span && jsonEncode(other.settings) == jsonEncode(settings);

  @override
  int get hashCode => Object.hash(id, type, span, jsonEncode(settings));
}

/// What a cockpit is: its name and colour, its Solutions (what it starts, waits and counts for), and its blocks in order.
@immutable
class CockpitContent {
  const CockpitContent({required this.name, this.colour, this.entityIds = const [], this.blocks = const []});

  final String name;
  final String? colour;
  final List<String> entityIds;
  final List<CockpitBlock> blocks;

  factory CockpitContent.fromJson(Map<String, dynamic> json) => CockpitContent(
        name: json['name']?.toString() ?? '',
        colour: _text(json['colour']),
        entityIds: _strings(json['entityIds']),
        blocks: _maps(json['blocks']).map(CockpitBlock.fromJson).toList(growable: false),
      );

  Map<String, dynamic> toJson() => {'name': name, 'colour': colour, 'entityIds': entityIds, 'blocks': blocks.map((b) => b.toJson()).toList()};

  /// The line of the top of the page, when it says one.
  String? get intro => blocks.where((b) => b.type == CockpitBlockType.hero).firstOrNull?.text('text');

  CockpitContent copyWith({String? name, String? colour, bool clearColour = false, List<String>? entityIds, List<CockpitBlock>? blocks}) => CockpitContent(
        name: name ?? this.name,
        colour: clearColour ? null : colour ?? this.colour,
        entityIds: entityIds ?? this.entityIds,
        blocks: blocks ?? this.blocks,
      );
}

/// A cockpit as the Desk shows it to the caller: what was published (or its draft, for who may change it), with the Solutions of
/// it they see and the blocks that have something to show them.
@immutable
class CockpitView {
  const CockpitView({required this.id, required this.content, this.draft = false, this.mayEdit = false});

  final String id;
  final CockpitContent content;

  /// Whether this is the draft, not what is published.
  final bool draft;
  final bool mayEdit;

  factory CockpitView.fromJson(Map<String, dynamic> json) => CockpitView(
        id: json['id']?.toString() ?? '',
        content: CockpitContent.fromJson(json),
        draft: json['draft'] == true,
        mayEdit: json['mayEdit'] == true,
      );
}

/// What a block of a Data Table shows: a figure ([value]) or rows ([columns], [rows], of [total]); [problem] when it cannot.
@immutable
class CockpitBlockData {
  const CockpitBlockData({this.value, this.columns = const [], this.rows = const [], this.total = 0, this.problem});

  final double? value;
  final List<String> columns;
  final List<List<String>> rows;
  final int total;
  final String? problem;

  factory CockpitBlockData.fromJson(Map<String, dynamic> json) => CockpitBlockData(
        value: (json['value'] as num?)?.toDouble(),
        columns: _strings(json['columns']),
        rows: json['rows'] is List ? (json['rows'] as List).whereType<List>().map((r) => r.map((c) => c?.toString() ?? '').toList(growable: false)).toList(growable: false) : const [],
        total: (json['total'] as num?)?.toInt() ?? 0,
        problem: _text(json['problem']),
      );
}

/// An owner of a cockpit: their id, and their name and e-mail when the workspace knows its people.
@immutable
class CockpitOwner {
  const CockpitOwner({required this.id, this.name, this.email});

  final String id;
  final String? name;
  final String? email;

  /// What to call them: their name, else their e-mail, else their id.
  String get label => name ?? email ?? id;

  factory CockpitOwner.fromJson(dynamic raw) =>
      raw is Map ? CockpitOwner(id: raw['id']?.toString() ?? '', name: _text(raw['name']), email: _text(raw['email'])) : CockpitOwner(id: raw?.toString() ?? '');
}

/// A cockpit as the Studio builds it: its draft, what is published (null: not on the Desk), who owns it, and what the caller may
/// do with it.
@immutable
class ManagedCockpit {
  const ManagedCockpit({
    required this.id,
    required this.draft,
    this.published,
    this.order = 0,
    this.owners = const [],
    this.hasChanges = true,
    this.updatedAt,
    this.publishedAt,
    this.updatedBy,
    this.mayEdit = false,
    this.mayManage = false,
  });

  final String id;
  final CockpitContent draft;
  final CockpitContent? published;
  final int order;

  /// The people who change and publish it besides who manages the cockpits.
  final List<CockpitOwner> owners;

  /// Whether the draft says something else than what is published (or nothing is).
  final bool hasChanges;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final String? updatedBy;
  final bool mayEdit;

  /// Whether the caller manages the cockpits: makes, owns, orders and deletes them.
  final bool mayManage;

  bool get isPublished => published != null;

  factory ManagedCockpit.fromJson(Map<String, dynamic> json) => ManagedCockpit(
        id: json['id']?.toString() ?? '',
        draft: CockpitContent.fromJson(_map(json['draft'])),
        published: json['published'] is Map ? CockpitContent.fromJson(_map(json['published'])) : null,
        order: (json['order'] as num?)?.toInt() ?? 0,
        owners: json['owners'] is List ? (json['owners'] as List).map(CockpitOwner.fromJson).where((o) => o.id.isNotEmpty).toList(growable: false) : const [],
        hasChanges: json['hasChanges'] != false,
        updatedAt: _date(json['updatedAt']),
        publishedAt: _date(json['publishedAt']),
        updatedBy: _text(json['updatedBy']),
        mayEdit: json['mayEdit'] == true,
        mayManage: json['mayManage'] == true,
      );
}

/// The cockpits the caller may change, and whether they manage them all.
@immutable
class ManagedCockpits {
  const ManagedCockpits({this.cockpits = const [], this.mayManage = false});

  final List<ManagedCockpit> cockpits;
  final bool mayManage;

  factory ManagedCockpits.fromJson(Map<String, dynamic> json) => ManagedCockpits(
        cockpits: _maps(json['cockpits']).map(ManagedCockpit.fromJson).toList(growable: false),
        mayManage: json['mayManage'] == true,
      );
}
