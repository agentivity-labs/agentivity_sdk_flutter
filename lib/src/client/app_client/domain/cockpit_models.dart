import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../icons/icon_ref.dart';

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

  /// A chart of a Data Table (`tableId`, `kind`: bars, lines or parts; `labelKind`: a column, a stretch of time (`period`,
  /// with `by`: day, week, month, quarter or year, cut where the platform is) or an expression; `labelColumn`, `labelExpression`, `valueKind`, `valueColumn`,
  /// `valueExpression`, `count`, `filters`, `where`, `periodColumn`, `period`). A chart over time is drawn oldest group first.
  /// An expression is read and turned into SQL by the service; nothing of it is read here.
  static const chart = 'chart';

  /// A text (`title`, `body`): paragraphs, and lines that start with "- ".
  static const text = 'text';

  /// A news of the department (`title`, `body`, `tone`: info, success or warning, `until`: its last day, yyyy-MM-dd).
  static const announcement = 'announcement';

  /// Links (`title`, `links`: each a `label`, a `url`, a `note`).
  static const links = 'links';

  /// A button that starts a Solution with what to say already written (`entityId`, `label`, `prompt`, `note`).
  static const launch = 'launch';

  /// What a department does every day, as several buttons in one block (`title`, `actions`: each an `entityId`, a `label`, a
  /// `prompt` and a `note`).
  static const actions = 'actions';

  /// Who to ask when no Solution can help (`title`, `people`: each an `id` of a person and a `note`). The service gives back
  /// their names and e-mails; the page keeps only who it names.
  static const people = 'people';

  /// A figure of a Data Table (`label`, `tableId`, `kind`: count, sum, average, min, max, a percentile (p50…p99) or
  /// expression, `column`, `expression`, `filterColumn`, `filterValue`, `filters`, `where`, `unit`). It may read one stretch
  /// of time (`periodColumn`, `period`: today, 7d, 30d, 90d, 12m, ytd) and say how it moved against the stretch before it
  /// (`compare`, `rise`: which way is the good way).
  static const metric = 'metric';

  /// The rows of a Data Table (`title`, `tableId`, `columns`, `count`, `sortColumn`, `descending`, `filters`, `where`,
  /// `search`, `periodColumn`, `period`, `tabs`: each a `label` and the `where` it keeps on top of the block's own).
  static const table = 'table';

  /// An image, a title, a text and a link out of Agentivity (`image`: kept as a data URL or an https address, `imageAt`: top or
  /// left, `ratio`: wide, classic or square, `title`, `body`, `linkLabel`, `url`).
  static const card = 'card';

  /// Opens a part of the page: a title, a line under it, a rule (`title`, `subtitle`, `line`). Always the whole width.
  static const section = 'section';

  static const all = [
    hero, ask, suggestions, waiting, gains, solutions, conversations, text, announcement, links, launch, actions, people,
    metric, table, chart, card, section,
  ];
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

/// A block of a cockpit: its kind ([CockpitBlockType]), its width in twelfths of the page on a wide screen (3, 4, 6, 8 or 12), what it
/// is set to show, and how it looks besides the page ([style]: `fill` white, tinted, colour or clear, `colour`, `border` none, thin
/// or accent, `corners` square, soft or round; what is not said is as the page says).
@immutable
class CockpitBlock {
  const CockpitBlock({required this.id, required this.type, this.span = units, this.settings = const {}, this.style = const {}});

  final String id;
  final String type;
  final int span;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> style;

  /// The widths a block may take: a quarter, a third, a half, two thirds, all of the page.
  /// How many parts the width of a page is cut into: forty-eight, which is both sixteen and twelve, so a block may be a
  /// sixteenth of the page or a third of it. A page written when it was cut into twelfths keeps its widths exactly — the
  /// service turns each of its twelfths into four, once.
  static const units = 48;

  /// The widths the designer offers: a sixteenth, an eighth, a sixth, a quarter, a third, three eighths, a half, two thirds,
  /// three quarters, all of it. Any width between them is kept as it is dragged.
  static const spans = [3, 6, 8, 9, 12, 16, 18, 24, 32, 36, 48];

  /// What a width is called, for a person choosing one.
  static String spanName(int span) => switch (span) {
        3 => '1/16',
        6 => '1/8',
        8 => '1/6',
        9 => '3/16',
        12 => '1/4',
        16 => '1/3',
        18 => '3/8',
        24 => '1/2',
        32 => '2/3',
        36 => '3/4',
        48 => 'Full',
        _ => '$span/48',
      };

  factory CockpitBlock.fromJson(Map<String, dynamic> json) => CockpitBlock(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        span: (json['span'] as num?)?.toInt() ?? units,
        settings: Map<String, dynamic>.from(_map(json['settings'])),
        style: Map<String, dynamic>.from(_map(json['style'])),
      );

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'span': span, 'settings': settings, if (style.isNotEmpty) 'style': style};

  String? text(String key) => _text(settings[key]);

  int? number(String key) => (settings[key] as num?)?.toInt();

  bool? flag(String key) => settings[key] is bool ? settings[key] as bool : null;

  List<String> strings(String key) => _strings(settings[key]);

  List<CockpitLink> get links => _maps(settings['links']).map(CockpitLink.fromJson).toList(growable: false);

  /// The buttons of a block of quick actions.
  List<CockpitAction> get actions => _maps(settings['actions']).map(CockpitAction.fromJson).toList(growable: false);

  /// The tabs of a block of rows: the same rows read several ways.
  List<CockpitTab> get tabs => _maps(settings['tabs']).map(CockpitTab.fromJson).toList(growable: false);

  /// The same block, with [key] set to [value] (null or empty: taken away).
  CockpitBlock withSetting(String key, Object? value) {
    final next = Map<String, dynamic>.from(settings);
    if (value == null || value is String && value.trim().isEmpty || value is List && value.isEmpty) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return CockpitBlock(id: id, type: type, span: span, settings: next, style: style);
  }

  /// The same block, with [key] of its look set to [value] (null: as the page says).
  CockpitBlock withStyle(String key, Object? value) {
    final next = Map<String, dynamic>.from(style);
    value == null ? next.remove(key) : next[key] = value;
    return CockpitBlock(id: id, type: type, span: span, settings: settings, style: next);
  }

  CockpitBlock copyWith({String? id, int? span, Map<String, dynamic>? settings}) =>
      CockpitBlock(id: id ?? this.id, type: type, span: span ?? this.span, settings: settings ?? this.settings, style: style);

  // The same block is one that says the same: what shows it reads it again only when it changed.
  @override
  bool operator ==(Object other) =>
      other is CockpitBlock && other.id == id && other.type == type && other.span == span && jsonEncode(other.settings) == jsonEncode(settings) && jsonEncode(other.style) == jsonEncode(style);

  @override
  int get hashCode => Object.hash(id, type, span, jsonEncode(settings), jsonEncode(style));
}

/// What a cockpit is: its name and colour, its Solutions (what it starts, waits and counts for), its blocks in order, and how the
/// page looks ([style]: `background` none, colour, gradient or image, `colour`, `colour2`, `direction` down, diagonal or across,
/// `image`, `veil` 0 to 90; its cards: `corners` square, soft or round, `border` none, thin or accent, `shadow` none or soft, `fill`
/// white, tinted or clear; empty: as the Desk has it).
@immutable
class CockpitContent {
  const CockpitContent({required this.name, this.colour, this.entityIds = const [], this.blocks = const [], this.style = const {}});

  final String name;
  final String? colour;
  final List<String> entityIds;
  final List<CockpitBlock> blocks;
  final Map<String, dynamic> style;

  /// How many parts the width of the page is cut into. Always said when a page is kept, so that the service reads its widths
  /// as they are: a page that says nothing is read as one written when the page was cut into twelfths, and converted once.
  int get grid => CockpitBlock.units;

  factory CockpitContent.fromJson(Map<String, dynamic> json) => CockpitContent(
        name: json['name']?.toString() ?? '',
        colour: _text(json['colour']),
        entityIds: _strings(json['entityIds']),
        blocks: _maps(json['blocks']).map(CockpitBlock.fromJson).toList(growable: false),
        style: Map<String, dynamic>.from(_map(json['style'])),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'colour': colour,
        'entityIds': entityIds,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        if (style.isNotEmpty) 'style': style,
        'grid': grid,
      };

  /// The line of the top of the page, when it says one.
  String? get intro => blocks.where((b) => b.type == CockpitBlockType.hero).firstOrNull?.text('text');

  CockpitContent copyWith({String? name, String? colour, bool clearColour = false, List<String>? entityIds, List<CockpitBlock>? blocks, Map<String, dynamic>? style}) =>
      CockpitContent(
        name: name ?? this.name,
        colour: clearColour ? null : colour ?? this.colour,
        entityIds: entityIds ?? this.entityIds,
        blocks: blocks ?? this.blocks,
        style: style ?? this.style,
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

/// What a block of a Data Table shows: a figure ([value], and [before] over the stretch of time before it) or rows ([columns],
/// [rows], of [total]); [problem] when it cannot.
@immutable
class CockpitBlockData {
  const CockpitBlockData({
    this.value,
    this.before,
    this.columns = const [],
    this.kinds = const [],
    this.rows = const [],
    this.points = const [],
    this.series = const [],
    this.trend = const [],
    this.people = const [],
    this.total = 0,
    this.sortedBy,
    this.sortedDown = false,
    this.problem,
  });

  final double? value;

  /// The same figure over the stretch of time just before the one shown, when it says which way it is going; null otherwise.
  final double? before;
  final List<String> columns;
  final List<List<String>> rows;

  /// What a chart draws: one point per group, already counted, added up or averaged by the database.
  final List<CockpitPoint> points;

  /// The same groups cut by a second column, when the chart is: each series has one value per point, in their order, the
  /// largest series first. Empty for a chart of one series.
  final List<CockpitSeries> series;

  /// Which way a figure went: its measure over the last stretches of time, the oldest first; null where a stretch held nothing.
  final List<double?> trend;

  /// What each column of [rows] holds: moment, date, number, yesno or text. A moment arrives in UTC, to be shown where the
  /// person reading is.
  final List<String> kinds;

  /// Who a block of people puts forward, by the names the workspace knows them under.
  final List<CockpitPerson> people;
  final int total;

  /// Which column the rows came back sorted by, and whether from the largest: what the page draws the arrow on.
  final String? sortedBy;
  final bool sortedDown;
  final String? problem;

  factory CockpitBlockData.fromJson(Map<String, dynamic> json) => CockpitBlockData(
        value: (json['value'] as num?)?.toDouble(),
        before: (json['before'] as num?)?.toDouble(),
        columns: _strings(json['columns']),
        kinds: _strings(json['kinds']),
        rows: json['rows'] is List ? (json['rows'] as List).whereType<List>().map((r) => r.map((c) => c?.toString() ?? '').toList(growable: false)).toList(growable: false) : const [],
        points: json['points'] is List
            ? (json['points'] as List).whereType<Map>().map((p) => CockpitPoint.fromJson(Map<String, dynamic>.from(p))).toList(growable: false)
            : const [],
        series: json['series'] is List
            ? (json['series'] as List).whereType<Map>().map((p) => CockpitSeries.fromJson(Map<String, dynamic>.from(p))).toList(growable: false)
            : const [],
        trend: json['trend'] is List ? (json['trend'] as List).map((v) => (v as num?)?.toDouble()).toList(growable: false) : const [],
        people: json['people'] is List
            ? (json['people'] as List).whereType<Map>().map((p) => CockpitPerson.fromJson(Map<String, dynamic>.from(p))).toList(growable: false)
            : const [],
        total: (json['total'] as num?)?.toInt() ?? 0,
        sortedBy: _text(json['sortedBy']),
        sortedDown: json['sortedDown'] == true,
        problem: _text(json['problem']),
      );
}

/// One series of a chart cut by a second column: what it is called, and its value at each point of the chart.
@immutable
class CockpitSeries {
  const CockpitSeries({required this.name, required this.values});

  final String name;
  final List<double> values;

  factory CockpitSeries.fromJson(Map<String, dynamic> json) => CockpitSeries(
        name: json['name']?.toString() ?? '',
        values: json['values'] is List ? (json['values'] as List).map((v) => (v as num?)?.toDouble() ?? 0).toList(growable: false) : const [],
      );
}

/// One button of a block of quick actions: the Solution it starts, and what it says to it.
@immutable
class CockpitAction {
  const CockpitAction({required this.entityId, required this.label, this.prompt, this.note, this.icon});

  final String entityId;
  final String label;
  final String? prompt;
  final String? note;

  /// The icon it wears, from the icon catalog; null: the mark of what its Solution is.
  final IconRef? icon;

  factory CockpitAction.fromJson(Map<String, dynamic> json) => CockpitAction(
        entityId: json['entityId']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        prompt: _text(json['prompt']),
        note: _text(json['note']),
        icon: IconRef.tryParse(json['icon']),
      );

  Map<String, dynamic> toJson() => {
        'entityId': entityId,
        'label': label,
        if (prompt != null) 'prompt': prompt,
        if (note != null) 'note': note,
        if (icon != null) 'icon': icon!.toJson(),
      };
}

/// One tab of a block of rows: its name, and what it keeps on top of what the block keeps.
@immutable
class CockpitTab {
  const CockpitTab({required this.label, this.where});

  final String label;
  final String? where;

  factory CockpitTab.fromJson(Map<String, dynamic> json) => CockpitTab(label: json['label']?.toString() ?? '', where: _text(json['where']));
}

/// One person a cockpit puts forward: who they are here, and what they are the one to ask about.
@immutable
class CockpitPerson {
  const CockpitPerson({required this.id, this.name, this.email, this.note});

  final String id;
  final String? name;
  final String? email;
  final String? note;

  /// What to call them: their name, else their e-mail, else their id.
  String get label => name ?? email ?? id;

  factory CockpitPerson.fromJson(Map<String, dynamic> json) => CockpitPerson(
        id: json['id']?.toString() ?? '',
        name: _text(json['name']),
        email: _text(json['email']),
        note: _text(json['note']),
      );
}

/// One point of a chart: what it is about, and how much of it there is.
///
/// A chart over time says [day] instead — the day its stretch of time starts on, as a day and not as words, because what is read
/// under the bar is written where it is read. See `timeLabel` in the Desk kit.
@immutable
class CockpitPoint {
  const CockpitPoint({this.label = '', this.day, required this.value});

  final String label;

  /// The first day of the stretch of time this point stands for (2026-11-18), on a chart drawn over time.
  final DateTime? day;
  final double value;

  factory CockpitPoint.fromJson(Map<String, dynamic> json) => CockpitPoint(
        label: _text(json['label']) ?? '',
        day: _text(json['day']) is String ? DateTime.tryParse(_text(json['day'])!) : null,
        value: (json['value'] as num?)?.toDouble() ?? 0,
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
    this.spaceId = 'default',
  });

  final String id;

  /// The space it is in: its members see it in the Desk, who manages the cockpits there changes it.
  final String spaceId;
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
        spaceId: _text(json['spaceId']) ?? 'default',
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
