import 'package:flutter/foundation.dart';

// The models of a person's own work on an instance (Agentivity Desk): who is signed in, their conversations as they keep them,
// their groups, what waits for their answer, the people a conversation is shared with, the time saved, and how the Desk looks.

String? _text(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _date(dynamic raw) => raw == null ? null : DateTime.tryParse(raw.toString());

double? _number(dynamic raw) => raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');

List<String> _strings(dynamic raw) => raw is List ? raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList(growable: false) : const [];

Map<String, dynamic> _map(dynamic raw) => raw is Map<String, dynamic> ? raw : raw is Map ? Map<String, dynamic>.from(raw) : const {};

List<Map<String, dynamic>> _maps(dynamic raw) => raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false) : const [];

// ── Signing in ────────────────────────────────────────────────────────────

/// A person of the instance, as it says who is signed in.
@immutable
class AccountPerson {
  const AccountPerson({required this.id, required this.name, required this.email, required this.atDesk, this.isOwner = false});

  final String id;
  final String name;
  final String email;

  /// On a seat of Agentivity Desk (rather than of the Studio): the Desk is all they use.
  final bool atDesk;
  final bool isOwner;

  /// Their initials, for an avatar.
  String get initials {
    final words = name.split(RegExp(r'[\s@._-]+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return (words.length == 1 ? words.first.substring(0, words.first.length.clamp(1, 2)) : '${words.first[0]}${words[1][0]}').toUpperCase();
  }

  factory AccountPerson.fromJson(Map<String, dynamic> json) => AccountPerson(
        id: json['id']?.toString() ?? '',
        name: (json['name'] ?? json['displayName'] ?? json['email'] ?? '').toString(),
        email: json['email']?.toString() ?? '',
        atDesk: json['seat'] == 'desk',
        isOwner: json['isOwner'] == true,
      );
}

/// What an instance answers before anything else: whether one signs in, and who is.
@immutable
class AccountStatus {
  const AccountStatus({required this.signInRequired, required this.person, this.ownerMissingReason, this.ownerInvited = false, this.passwordResetByEmail = false});

  final bool signInRequired;
  final AccountPerson? person;

  /// Why no one can sign in yet (the instance has no owner).
  final String? ownerMissingReason;
  final bool ownerInvited;

  /// Whether a forgotten password can be asked by e-mail.
  final bool passwordResetByEmail;

  bool get signedIn => person != null || !signInRequired;

  factory AccountStatus.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return AccountStatus(
      signInRequired: json['signInRequired'] == true,
      person: user is Map ? AccountPerson.fromJson(Map<String, dynamic>.from(user)) : null,
      ownerMissingReason: json['ownerMissing'] == true ? _text(json['ownerMissingReason']) : null,
      ownerInvited: json['ownerInvited'] == true,
      passwordResetByEmail: json['passwordResetByEmail'] == true,
    );
  }
}

// ── How the Desk looks ────────────────────────────────────────────────────

/// The brand of the Desk: its name, its colour (#RRGGBB) and its logo (a data URL). Null: the style of Agentivity.
@immutable
class DeskBrand {
  const DeskBrand({this.name, this.colour, this.logo});

  final String? name;
  final String? colour;
  final String? logo;

  static const none = DeskBrand();

  factory DeskBrand.fromJson(Map<String, dynamic> json) => DeskBrand(name: _text(json['name']), colour: _text(json['colour']), logo: _text(json['logo']));

  Map<String, dynamic> toJson() => {'name': name, 'colour': colour, 'logo': logo};

  DeskBrand copyWith({String? name, String? colour, String? logo, bool clearLogo = false, bool clearColour = false}) =>
      DeskBrand(name: name ?? this.name, colour: clearColour ? null : colour ?? this.colour, logo: clearLogo ? null : logo ?? this.logo);
}

/// A cockpit: a page of the Desk for a department (Finance, HR…), with the elements it starts.
@immutable
class DeskCockpit {
  const DeskCockpit({required this.id, required this.name, this.intro, this.colour, this.entityIds = const [], this.waiting = 0});

  final String id;
  final String name;
  final String? intro;
  final String? colour;
  final List<String> entityIds;

  /// How many of the caller's conversations in it wait for their answer.
  final int waiting;

  factory DeskCockpit.fromJson(Map<String, dynamic> json) => DeskCockpit(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        intro: _text(json['intro']),
        colour: _text(json['colour']),
        entityIds: _strings(json['entityIds']),
        waiting: (json['waiting'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'intro': intro, 'colour': colour, 'entityIds': entityIds};

  DeskCockpit copyWith({String? name, String? intro, String? colour, List<String>? entityIds}) =>
      DeskCockpit(id: id, name: name ?? this.name, intro: intro ?? this.intro, colour: colour ?? this.colour, entityIds: entityIds ?? this.entityIds, waiting: waiting);
}

/// What the Desk says of an element: its suggestions, and the time it saves each time (set by hand, or measured).
@immutable
class DeskEntityInfo {
  const DeskEntityInfo({this.starters = const [], this.minutesSaved});

  final List<String> starters;
  final double? minutesSaved;

  factory DeskEntityInfo.fromJson(Map<String, dynamic> json) => DeskEntityInfo(starters: _strings(json['starters']), minutesSaved: _number(json['minutesSaved']));

  Map<String, dynamic> toJson() => {'starters': starters, 'minutesSaved': minutesSaved};
}

/// What fills a group by itself: what a conversation talks to, and words of its title or first message.
@immutable
class DeskGroupRule {
  const DeskGroupRule({this.entityId, this.contains});

  final String? entityId;
  final String? contains;

  bool get isEmpty => entityId == null && (contains ?? '').trim().isEmpty;

  factory DeskGroupRule.fromJson(Map<String, dynamic> json) => DeskGroupRule(entityId: _text(json['entityId']), contains: _text(json['contains']));

  Map<String, dynamic> toJson() => {'entityId': entityId, 'contains': contains};
}

/// A group of the caller's conversations: a name, a colour, and the rule that fills it, if any.
@immutable
class DeskGroup {
  const DeskGroup({required this.id, required this.name, required this.colour, this.rule, this.count = 0});

  final String id;
  final String name;
  final String colour;
  final DeskGroupRule? rule;
  final int count;

  factory DeskGroup.fromJson(Map<String, dynamic> json) {
    final rule = json['rule'];
    return DeskGroup(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      colour: json['colour']?.toString() ?? '#5B3BD6',
      rule: rule is Map ? DeskGroupRule.fromJson(Map<String, dynamic>.from(rule)) : null,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// What the Desk shows to the caller when it opens: its look, the cockpits and elements published to them, their groups and counts.
@immutable
class DeskOverview {
  const DeskOverview({
    this.brand = DeskBrand.none,
    this.welcome,
    this.cockpits = const [],
    this.shown,
    this.entities = const {},
    this.groups = const [],
    this.waiting = 0,
    this.conversations = 0,
    this.archived = 0,
    this.emailQuestions = true,
  });

  final DeskBrand brand;
  final String? welcome;
  final List<DeskCockpit> cockpits;

  /// The elements published to the Desk; null, all those the caller may start.
  final List<String>? shown;

  /// What the Desk says of each element published, by id.
  final Map<String, DeskEntityInfo> entities;
  final List<DeskGroup> groups;
  final int waiting;
  final int conversations;
  final int archived;

  /// Whether the caller is told by e-mail of a question asked to them.
  final bool emailQuestions;

  bool publishes(String entityId) => shown == null || shown!.contains(entityId);

  factory DeskOverview.fromJson(Map<String, dynamic> json) {
    final counts = _map(json['counts']);
    final shown = json['shown'];
    return DeskOverview(
      brand: DeskBrand.fromJson(_map(json['brand'])),
      welcome: _text(json['welcome']),
      cockpits: _maps(json['cockpits']).map(DeskCockpit.fromJson).toList(growable: false),
      shown: shown is List ? _strings(shown) : null,
      entities: _map(json['entities']).map((id, info) => MapEntry(id, DeskEntityInfo.fromJson(_map(info)))),
      groups: _maps(json['groups']).map(DeskGroup.fromJson).toList(growable: false),
      waiting: (counts['waiting'] as num?)?.toInt() ?? 0,
      conversations: (counts['conversations'] as num?)?.toInt() ?? 0,
      archived: (counts['archived'] as num?)?.toInt() ?? 0,
      emailQuestions: json['emailQuestions'] != false,
    );
  }
}

/// How the Desk of the workspace looks and what it shows, as the Studio sets it.
@immutable
class DeskSetup {
  const DeskSetup({this.brand = DeskBrand.none, this.welcome, this.cockpits = const [], this.shown, this.entities = const {}});

  final DeskBrand brand;
  final String? welcome;
  final List<DeskCockpit> cockpits;

  /// The elements published to the Desk; null, all of them.
  final List<String>? shown;
  final Map<String, DeskEntityInfo> entities;

  factory DeskSetup.fromJson(Map<String, dynamic> json) {
    final shown = json['shown'];
    return DeskSetup(
      brand: DeskBrand.fromJson(_map(json['brand'])),
      welcome: _text(json['welcome']),
      cockpits: _maps(json['cockpits']).map(DeskCockpit.fromJson).toList(growable: false),
      shown: shown is List ? _strings(shown) : null,
      entities: _map(json['entities']).map((id, info) => MapEntry(id, DeskEntityInfo.fromJson(_map(info)))),
    );
  }

  Map<String, dynamic> toJson() => {
        'brand': brand.toJson(),
        'welcome': welcome,
        'cockpits': cockpits.map((c) => c.toJson()).toList(),
        'shown': shown,
        'entities': entities.map((id, info) => MapEntry(id, info.toJson())),
      };

  DeskSetup copyWith({DeskBrand? brand, String? welcome, List<DeskCockpit>? cockpits, List<String>? shown, bool showAll = false, Map<String, DeskEntityInfo>? entities}) => DeskSetup(
        brand: brand ?? this.brand,
        welcome: welcome ?? this.welcome,
        cockpits: cockpits ?? this.cockpits,
        shown: showAll ? null : shown ?? this.shown,
        entities: entities ?? this.entities,
      );
}

// ── Conversations ─────────────────────────────────────────────────────────

/// Where a conversation stands for the caller.
enum DeskConversationStatus {
  /// Something in it waits for their answer.
  waiting,

  /// It goes on.
  working,
  done,

  /// It failed or was stopped.
  stopped;

  static DeskConversationStatus of(String? raw) => DeskConversationStatus.values.firstWhere((s) => s.name == raw, orElse: () => DeskConversationStatus.working);
}

/// A conversation of the caller's, or one shared with them, as they keep it.
@immutable
class DeskConversation {
  const DeskConversation({
    required this.executionId,
    required this.title,
    required this.entityId,
    required this.entityKind,
    required this.status,
    this.entityName,
    this.state = '',
    this.waiting = 0,
    this.pinned = false,
    this.archived = false,
    this.groupId,
    this.cockpitIds = const [],
    this.participation,
    this.startedBy,
    this.createdAt,
    this.updatedAt,
    this.minutesSaved,
  });

  final String executionId;
  final String title;
  final String entityId;

  /// `agent`, `team` or `workflow`.
  final String entityKind;
  final String? entityName;
  final String state;
  final DeskConversationStatus status;

  /// How many questions in it wait for the caller's answer.
  final int waiting;
  final bool pinned;
  final bool archived;
  final String? groupId;
  final List<String> cockpitIds;

  /// `started` (theirs), `reply` or `read` (shared with them), `asked` (a question of it is asked to them).
  final String? participation;
  final String? startedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The time it saved, once done.
  final double? minutesSaved;

  bool get mine => participation == 'started' || participation == null;
  bool get mayReply => participation != 'read' && participation != 'asked';

  factory DeskConversation.fromJson(Map<String, dynamic> json) => DeskConversation(
        executionId: json['executionId']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        entityId: json['entityId']?.toString() ?? '',
        entityKind: (json['entityKind'] ?? '').toString().toLowerCase(),
        entityName: _text(json['entityName']),
        state: (json['state'] ?? '').toString().toLowerCase(),
        status: DeskConversationStatus.of(json['status']?.toString()),
        waiting: (json['waiting'] as num?)?.toInt() ?? 0,
        pinned: json['pinned'] == true,
        archived: json['archived'] == true,
        groupId: _text(json['groupId']),
        cockpitIds: _strings(json['cockpitIds']),
        participation: _text(json['participation']),
        startedBy: _text(json['startedBy']),
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
        minutesSaved: _number(json['minutesSaved']),
      );
}

/// A page of the caller's conversations, and how many there are in all.
@immutable
class DeskConversationPage {
  const DeskConversationPage({required this.total, required this.conversations});

  final int total;
  final List<DeskConversation> conversations;

  factory DeskConversationPage.fromJson(Map<String, dynamic> json) =>
      DeskConversationPage(total: (json['total'] as num?)?.toInt() ?? 0, conversations: _maps(json['conversations']).map(DeskConversation.fromJson).toList(growable: false));
}

/// What to list of the caller's conversations. Null: not filtered on it.
@immutable
class DeskConversationQuery {
  const DeskConversationQuery({this.search, this.statuses = const {}, this.cockpitIds = const {}, this.groupId, this.entityId, this.pinned, this.archived = false, this.recent = false, this.skip = 0, this.take = 50});

  final String? search;
  final Set<DeskConversationStatus> statuses;
  final Set<String> cockpitIds;

  /// A group of theirs, or `none` for those in no group.
  final String? groupId;
  final String? entityId;
  final bool? pinned;
  final bool archived;

  /// Those still recent: pinned, waiting or going on, or touched in the last 30 days; pinned first.
  final bool recent;
  final int skip;
  final int take;

  Map<String, dynamic> toQuery() => {
        if ((search ?? '').trim().isNotEmpty) 'q': search!.trim(),
        if (statuses.isNotEmpty) 'status': statuses.map((s) => s.name).toList(),
        if (cockpitIds.isNotEmpty) 'cockpit': cockpitIds.toList(),
        if (groupId != null) 'group': groupId,
        if (entityId != null) 'entity': entityId,
        if (pinned != null) 'pinned': pinned,
        if (archived) 'archived': true,
        if (recent) 'recent': true,
        'skip': skip,
        'take': take,
      };
}

/// A question or an approval waiting for the caller's answer.
@immutable
class DeskQuestion {
  const DeskQuestion({
    required this.requestId,
    required this.executionId,
    required this.entityId,
    required this.entityKind,
    this.entityName,
    this.kind,
    this.title,
    this.question,
    this.createdAt,
    this.startedBy,
    this.askedToYou = false,
  });

  final String requestId;
  final String executionId;
  final String entityId;
  final String entityKind;
  final String? entityName;

  /// What answer it waits for (`approval`, `choice`, `text`, `form`…).
  final String? kind;
  final String? title;
  final String? question;
  final DateTime? createdAt;
  final String? startedBy;

  /// Asked to them by name (an approval by a colleague), rather than waiting in a conversation of theirs.
  final bool askedToYou;

  /// Answered in one click: a yes or no.
  bool get quick => const {'approval', 'confirm', 'confirmation', 'yesno', 'yes_no'}.contains((kind ?? '').toLowerCase());

  factory DeskQuestion.fromJson(Map<String, dynamic> json) => DeskQuestion(
        requestId: json['requestId']?.toString() ?? '',
        executionId: json['executionId']?.toString() ?? '',
        entityId: json['entityId']?.toString() ?? '',
        entityKind: (json['entityKind'] ?? '').toString().toLowerCase(),
        entityName: _text(json['entityName']),
        kind: _text(json['kind']),
        title: _text(json['title']),
        question: _text(json['question']),
        createdAt: _date(json['createdAt']),
        startedBy: _text(json['startedBy']),
        askedToYou: json['askedToYou'] == true,
      );
}

/// A person a conversation is shared with.
@immutable
class DeskParticipant {
  const DeskParticipant({required this.personId, required this.name, required this.mayReply, this.askedTo = false});

  final String personId;
  final String name;
  final bool mayReply;

  /// There because a question of the conversation is asked to them, not shared by someone.
  final bool askedTo;

  factory DeskParticipant.fromJson(Map<String, dynamic> json) => DeskParticipant(
        personId: json['personId']?.toString() ?? '',
        name: (json['name'] ?? '').toString(),
        mayReply: json['mayReply'] == true,
        askedTo: json['askedTo'] == true,
      );
}

// ── Time saved ────────────────────────────────────────────────────────────

/// The time the teams saved the caller, in minutes; and, asked for a cockpit, what its teams saved this month.
@immutable
class DeskGains {
  const DeskGains({this.week = 0, this.year = 0, this.done = 0, this.days = const [], this.byEntity = const [], this.cockpit});

  final double week;
  final double year;

  /// How many of their conversations ended well this year.
  final int done;

  /// The last 14 days, oldest first.
  final List<double> days;

  /// This week, the elements that saved them the most.
  final List<({String entityId, String? name, double minutes})> byEntity;
  final DeskCockpitGains? cockpit;

  factory DeskGains.fromJson(Map<String, dynamic> json) {
    final cockpit = json['cockpit'];
    return DeskGains(
      week: _number(json['week']) ?? 0,
      year: _number(json['year']) ?? 0,
      done: (json['done'] as num?)?.toInt() ?? 0,
      days: json['days'] is List ? (json['days'] as List).map((d) => _number(d) ?? 0).toList(growable: false) : const [],
      byEntity: _maps(json['byEntity']).map((e) => (entityId: e['entityId']?.toString() ?? '', name: _text(e['name']), minutes: _number(e['minutes']) ?? 0)).toList(growable: false),
      cockpit: cockpit is Map ? DeskCockpitGains.fromJson(Map<String, dynamic>.from(cockpit)) : null,
    );
  }
}

/// What the teams of a cockpit saved this month: all the people of it, the caller's part, how many people and conversations.
@immutable
class DeskCockpitGains {
  const DeskCockpitGains({this.month = 0, this.mine = 0, this.people = 0, this.done = 0});

  final double month;
  final double mine;
  final int people;
  final int done;

  factory DeskCockpitGains.fromJson(Map<String, dynamic> json) => DeskCockpitGains(
        month: _number(json['month']) ?? 0,
        mine: _number(json['mine']) ?? 0,
        people: (json['people'] as num?)?.toInt() ?? 0,
        done: (json['done'] as num?)?.toInt() ?? 0,
      );
}
