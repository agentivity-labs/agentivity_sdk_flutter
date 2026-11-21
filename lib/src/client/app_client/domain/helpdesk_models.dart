import 'package:flutter/foundation.dart';

import 'support_models.dart';

// The help desk of the workspace: what the people of the Desk ask, and how its agents answer them, by team, passing to the support
// of Agentivity what is beyond them. The person who asks never sees the notes of the help desk, nor what was said with Agentivity.

String? _text(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _date(dynamic raw) => raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();

Map<String, dynamic> _map(dynamic raw) => raw is Map<String, dynamic> ? raw : raw is Map ? Map<String, dynamic>.from(raw) : const {};

List<Map<String, dynamic>> _maps(dynamic raw) => raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false) : const [];

int _int(dynamic raw, [int otherwise = 0]) => (raw as num?)?.toInt() ?? otherwise;

/// Where a request of the help desk stands.
enum HelpdeskStatus {
  /// Waiting for the help desk.
  open,

  /// The help desk waits for the person's reply.
  waitingRequester,
  resolved,
  closed;

  String get code => switch (this) {
        HelpdeskStatus.open => 'open',
        HelpdeskStatus.waitingRequester => 'waiting_requester',
        HelpdeskStatus.resolved => 'resolved',
        HelpdeskStatus.closed => 'closed',
      };

  static HelpdeskStatus parse(dynamic raw) => switch (raw) {
        'waiting_requester' => HelpdeskStatus.waitingRequester,
        'resolved' => HelpdeskStatus.resolved,
        'closed' => HelpdeskStatus.closed,
        _ => HelpdeskStatus.open,
      };

  bool get active => this == HelpdeskStatus.open || this == HelpdeskStatus.waitingRequester;
}

enum HelpdeskPriority {
  low,
  normal,
  high,
  urgent;

  static HelpdeskPriority parse(dynamic raw) => HelpdeskPriority.values.where((p) => p.name == raw).firstOrNull ?? HelpdeskPriority.normal;
}

/// What one may ask the help desk for (an access, a Solution that is wrong…).
@immutable
class HelpdeskCategory {
  const HelpdeskCategory({required this.id, required this.name, this.description = '', this.teamId});

  final String id;
  final String name;
  final String description;

  /// The team that handles it; none: every agent sees what is asked in it.
  final String? teamId;

  factory HelpdeskCategory.fromJson(Map<String, dynamic> json) =>
      HelpdeskCategory(id: _text(json['id']) ?? '', name: _text(json['name']) ?? '', description: _text(json['description']) ?? '', teamId: _text(json['teamId']));

  Map<String, dynamic> toJson() => {'id': id.isEmpty ? null : id, 'name': name, 'description': description, 'teamId': teamId};
}

/// Whether one may ask the help desk, what for, and how many of its answers one has not read; whether one handles it.
@immutable
class HelpdeskAvailability {
  const HelpdeskAvailability({
    required this.open,
    this.categories = const [],
    this.unread = 0,
    this.handles = false,
    this.leads = false,
    this.canEscalate = false,
    this.targetDays = 1,
  });

  /// The help desk has categories: the people of the Desk may ask.
  final bool open;
  final List<HelpdeskCategory> categories;
  final int unread;

  /// The person is an agent of the help desk (Helpdesk agent).
  final bool handles;

  /// The person leads the help desk (Helpdesk lead): its teams, its categories, its saved replies.
  final bool leads;

  /// The workspace is hosted by Agentivity: a request may be passed to its support.
  final bool canEscalate;
  final int targetDays;

  factory HelpdeskAvailability.fromJson(Map<String, dynamic> json) => HelpdeskAvailability(
        open: json['open'] == true,
        categories: _maps(json['categories']).map(HelpdeskCategory.fromJson).toList(growable: false),
        unread: _int(json['unread']),
        handles: json['handles'] == true,
        leads: json['leads'] == true,
        canEscalate: json['canEscalate'] == true,
        targetDays: _int(json['targetDays'], 1),
      );
}

/// What the Desk joins of itself: the conversation concerned and its Solution.
@immutable
class HelpdeskContext {
  const HelpdeskContext({this.conversationId, this.solutionId, this.solutionName, this.page});

  final String? conversationId;
  final String? solutionId;
  final String? solutionName;
  final String? page;

  bool get isEmpty => conversationId == null && solutionId == null && solutionName == null && page == null;

  factory HelpdeskContext.fromJson(Map<String, dynamic> json) => HelpdeskContext(
        conversationId: _text(json['conversationId']),
        solutionId: _text(json['solutionId']),
        solutionName: _text(json['solutionName']),
        page: _text(json['page']),
      );

  Map<String, dynamic> toJson() => {'conversationId': conversationId, 'solutionId': solutionId, 'solutionName': solutionName, 'page': page};
}

@immutable
class HelpdeskFileInfo {
  const HelpdeskFileInfo({required this.id, required this.name, required this.contentType, required this.size});

  final String id;
  final String name;
  final String contentType;
  final int size;

  bool get image => contentType.startsWith('image/');

  factory HelpdeskFileInfo.fromJson(Map<String, dynamic> json) => HelpdeskFileInfo(
        id: _text(json['id']) ?? '',
        name: _text(json['name']) ?? 'file',
        contentType: _text(json['contentType']) ?? 'application/octet-stream',
        size: _int(json['size']),
      );
}

/// A message of a request: the person's, an agent's, a note of the help desk (never shown to the person), what the platform says
/// to the person (system), or what only the help desk sees (event: who took it, a transfer…).
@immutable
class HelpdeskMessage {
  const HelpdeskMessage({required this.id, required this.author, this.authorId, this.authorName, required this.body, this.at, this.files = const []});

  final String id;

  /// requester, agent, note, system, event.
  final String author;
  final String? authorId;
  final String? authorName;
  final String body;
  final DateTime? at;
  final List<HelpdeskFileInfo> files;

  bool get fromRequester => author == 'requester';
  bool get fromAgent => author == 'agent';
  bool get isNote => author == 'note';
  bool get isSystem => author == 'system' || author == 'event';

  factory HelpdeskMessage.fromJson(Map<String, dynamic> json) => HelpdeskMessage(
        id: _text(json['id']) ?? '',
        author: _text(json['author']) ?? 'requester',
        authorId: _text(json['authorId']),
        authorName: _text(json['authorName']),
        body: _text(json['body']) ?? '',
        at: _date(json['at']),
        files: _maps(json['files']).map(HelpdeskFileInfo.fromJson).toList(growable: false),
      );
}

/// A request of the help desk as the person who asked sees it.
@immutable
class HelpdeskRequest {
  const HelpdeskRequest({
    required this.number,
    required this.reference,
    required this.subject,
    required this.categoryId,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.rating,
    this.unread = false,
    this.assigneeName,
    this.withAgentivity = false,
    this.context,
    this.messages = const [],
  });

  final int number;

  /// "HD-1001".
  final String reference;
  final String subject;
  final String categoryId;
  final HelpdeskStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final String? rating;

  /// The help desk wrote what the person has not read yet.
  final bool unread;
  final String? assigneeName;

  /// Passed to the support of Agentivity, still with them.
  final bool withAgentivity;
  final HelpdeskContext? context;
  final List<HelpdeskMessage> messages;

  factory HelpdeskRequest.fromJson(Map<String, dynamic> json) => HelpdeskRequest(
        number: _int(json['number']),
        reference: _text(json['reference']) ?? 'HD-${json['number']}',
        subject: _text(json['subject']) ?? '',
        categoryId: _text(json['categoryId']) ?? '',
        status: HelpdeskStatus.parse(json['status']),
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
        resolvedAt: _date(json['resolvedAt']),
        rating: _text(json['rating']),
        unread: json['unread'] == true,
        assigneeName: _text(json['assigneeName']),
        withAgentivity: json['withAgentivity'] == true,
        context: json['context'] is Map ? HelpdeskContext.fromJson(_map(json['context'])) : null,
        messages: _maps(json['messages']).map(HelpdeskMessage.fromJson).toList(growable: false),
      );
}

@immutable
class HelpdeskTeamRef {
  const HelpdeskTeamRef({required this.id, required this.name, required this.colour});

  final String id;
  final String name;

  /// #RRGGBB.
  final String colour;

  factory HelpdeskTeamRef.fromJson(Map<String, dynamic> json) =>
      HelpdeskTeamRef(id: _text(json['id']) ?? '', name: _text(json['name']) ?? '', colour: _text(json['colour']) ?? '#4F46E5');
}

@immutable
class HelpdeskPerson {
  const HelpdeskPerson({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  factory HelpdeskPerson.fromJson(Map<String, dynamic> json) =>
      HelpdeskPerson(id: _text(json['id']) ?? '', name: _text(json['name']) ?? '', email: _text(json['email']) ?? '');
}

/// The request passed to the support of Agentivity: its reference there (SUP-n) and its status there.
@immutable
class HelpdeskEscalation {
  const HelpdeskEscalation({required this.reference, required this.number, required this.status, this.byId, this.byName, this.at});

  final String reference;
  final int number;

  /// waiting_us, waiting_customer, resolved, closed (as the support of Agentivity says it).
  final String status;
  final String? byId;
  final String? byName;
  final DateTime? at;

  /// The support of Agentivity answered and waits for the help desk.
  bool get answered => status == 'waiting_customer';
  bool get done => status == 'resolved' || status == 'closed';

  factory HelpdeskEscalation.fromJson(Map<String, dynamic> json) => HelpdeskEscalation(
        reference: _text(json['reference']) ?? 'SUP-${json['number']}',
        number: _int(json['number']),
        status: _text(json['status']) ?? 'waiting_us',
        byId: _text(json['byId']),
        byName: _text(json['byName']),
        at: _date(json['at']),
      );
}

/// A request of the help desk as its agents see it: a row of the inbox, or the whole of it.
@immutable
class HelpdeskTicket {
  const HelpdeskTicket({
    required this.number,
    required this.reference,
    required this.subject,
    this.categoryId,
    this.category,
    this.team,
    required this.status,
    required this.priority,
    required this.requester,
    this.assigneeId,
    this.assigneeName,
    this.createdAt,
    this.updatedAt,
    this.respondBy,
    this.firstResponseAt,
    this.resolvedAt,
    this.late = false,
    this.lastAuthor,
    this.rating,
    this.ratingComment,
    this.context,
    this.escalation,
    this.messageCount = 0,
    this.messages = const [],
  });

  final int number;
  final String reference;
  final String subject;
  final String? categoryId;
  final String? category;
  final HelpdeskTeamRef? team;
  final HelpdeskStatus status;
  final HelpdeskPriority priority;
  final HelpdeskPerson requester;
  final String? assigneeId;
  final String? assigneeName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The target of a first answer (a target of the help desk, never a promise).
  final DateTime? respondBy;
  final DateTime? firstResponseAt;
  final DateTime? resolvedAt;

  /// Waiting for a first answer past its target.
  final bool late;

  /// requester or agent: who wrote last.
  final String? lastAuthor;
  final String? rating;
  final String? ratingComment;
  final HelpdeskContext? context;
  final HelpdeskEscalation? escalation;
  final int messageCount;
  final List<HelpdeskMessage> messages;

  /// The person wrote last, and the request waits for the help desk.
  bool get requesterWaiting => status == HelpdeskStatus.open && lastAuthor == 'requester';

  factory HelpdeskTicket.fromJson(Map<String, dynamic> json) => HelpdeskTicket(
        number: _int(json['number']),
        reference: _text(json['reference']) ?? 'HD-${json['number']}',
        subject: _text(json['subject']) ?? '',
        categoryId: _text(json['categoryId']),
        category: _text(json['category']),
        team: json['team'] is Map ? HelpdeskTeamRef.fromJson(_map(json['team'])) : null,
        status: HelpdeskStatus.parse(json['status']),
        priority: HelpdeskPriority.parse(json['priority']),
        requester: HelpdeskPerson.fromJson(_map(json['requester'])),
        assigneeId: _text(json['assigneeId']),
        assigneeName: _text(json['assigneeName']),
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
        respondBy: _date(json['respondBy']),
        firstResponseAt: _date(json['firstResponseAt']),
        resolvedAt: _date(json['resolvedAt']),
        late: json['late'] == true,
        lastAuthor: _text(json['lastAuthor']),
        rating: _text(json['rating']),
        ratingComment: _text(json['ratingComment']),
        context: json['context'] is Map ? HelpdeskContext.fromJson(_map(json['context'])) : null,
        escalation: json['escalation'] is Map ? HelpdeskEscalation.fromJson(_map(json['escalation'])) : null,
        messageCount: _int(json['messages'] is List ? (json['messages'] as List).length : json['messages']),
        messages: _maps(json['messages']).map(HelpdeskMessage.fromJson).toList(growable: false),
      );
}

/// How many requests wait in each view of the inbox.
@immutable
class HelpdeskCounts {
  const HelpdeskCounts({this.open = 0, this.mine = 0, this.team = 0, this.unassigned = 0, this.late = 0, this.waitingRequester = 0, this.escalated = 0});

  final int open;
  final int mine;
  final int team;
  final int unassigned;
  final int late;
  final int waitingRequester;
  final int escalated;

  factory HelpdeskCounts.fromJson(Map<String, dynamic> json) => HelpdeskCounts(
        open: _int(json['open']),
        mine: _int(json['mine']),
        team: _int(json['team']),
        unassigned: _int(json['unassigned']),
        late: _int(json['late']),
        waitingRequester: _int(json['waitingRequester']),
        escalated: _int(json['escalated']),
      );
}

@immutable
class HelpdeskInbox {
  const HelpdeskInbox({required this.requests, required this.counts});

  final List<HelpdeskTicket> requests;
  final HelpdeskCounts counts;

  factory HelpdeskInbox.fromJson(Map<String, dynamic> json) => HelpdeskInbox(
        requests: _maps(json['requests']).map(HelpdeskTicket.fromJson).toList(growable: false),
        counts: HelpdeskCounts.fromJson(_map(json['counts'])),
      );
}

/// A request with what the agent needs beside it: the other requests of its person, and the thread at the support of Agentivity.
@immutable
class HelpdeskTicketDetail {
  const HelpdeskTicketDetail({required this.ticket, this.requesterRequests = const [], this.support, this.supportUnreachable = false, this.canEscalate = false});

  final HelpdeskTicket ticket;
  final List<HelpdeskRequest> requesterRequests;

  /// The request at the support of Agentivity and its thread, when it was passed there and could be read.
  final SupportThread? support;
  final bool supportUnreachable;
  final bool canEscalate;

  factory HelpdeskTicketDetail.fromJson(Map<String, dynamic> json) {
    final support = _map(json['support']);
    final thread = support['thread'];
    return HelpdeskTicketDetail(
      ticket: HelpdeskTicket.fromJson(_map(json['request'])),
      requesterRequests: _maps(json['requesterRequests']).map(HelpdeskRequest.fromJson).toList(growable: false),
      support: thread is Map ? SupportThread.fromJson(_map(thread)) : null,
      supportUnreachable: support['unreachable'] == true,
      canEscalate: json['canEscalate'] == true,
    );
  }
}

/// Someone who handles the help desk.
@immutable
class HelpdeskAgentInfo {
  const HelpdeskAgentInfo({required this.id, required this.name, required this.email, this.lead = false});

  final String id;
  final String name;
  final String email;
  final bool lead;

  factory HelpdeskAgentInfo.fromJson(Map<String, dynamic> json) =>
      HelpdeskAgentInfo(id: _text(json['id']) ?? '', name: _text(json['name']) ?? '', email: _text(json['email']) ?? '', lead: json['lead'] == true);
}

@immutable
class HelpdeskTeam {
  const HelpdeskTeam({this.id = '', required this.name, this.colour = '#4F46E5', this.memberIds = const []});

  final String id;
  final String name;
  final String colour;
  final List<String> memberIds;

  HelpdeskTeam copyWith({String? name, String? colour, List<String>? memberIds}) =>
      HelpdeskTeam(id: id, name: name ?? this.name, colour: colour ?? this.colour, memberIds: memberIds ?? this.memberIds);

  factory HelpdeskTeam.fromJson(Map<String, dynamic> json) => HelpdeskTeam(
        id: _text(json['id']) ?? '',
        name: _text(json['name']) ?? '',
        colour: _text(json['colour']) ?? '#4F46E5',
        memberIds: (json['memberIds'] as List? ?? const []).map((e) => e.toString()).toList(growable: false),
      );

  Map<String, dynamic> toJson() => {'id': id.isEmpty ? null : id, 'name': name, 'colour': colour, 'memberIds': memberIds};
}

@immutable
class HelpdeskSavedReply {
  const HelpdeskSavedReply({this.id = '', required this.title, required this.body});

  final String id;
  final String title;
  final String body;

  factory HelpdeskSavedReply.fromJson(Map<String, dynamic> json) => HelpdeskSavedReply(id: _text(json['id']) ?? '', title: _text(json['title']) ?? '', body: _text(json['body']) ?? '');

  Map<String, dynamic> toJson() => {'id': id.isEmpty ? null : id, 'title': title, 'body': body};
}

/// How the help desk is set: its teams, its categories, its saved replies, its target of a first answer (working days).
@immutable
class HelpdeskSetup {
  const HelpdeskSetup({this.teams = const [], this.categories = const [], this.replies = const [], this.targetDays = 1});

  final List<HelpdeskTeam> teams;
  final List<HelpdeskCategory> categories;
  final List<HelpdeskSavedReply> replies;
  final int targetDays;

  HelpdeskSetup copyWith({List<HelpdeskTeam>? teams, List<HelpdeskCategory>? categories, List<HelpdeskSavedReply>? replies, int? targetDays}) => HelpdeskSetup(
        teams: teams ?? this.teams,
        categories: categories ?? this.categories,
        replies: replies ?? this.replies,
        targetDays: targetDays ?? this.targetDays,
      );

  factory HelpdeskSetup.fromJson(Map<String, dynamic> json) => HelpdeskSetup(
        teams: _maps(json['teams']).map(HelpdeskTeam.fromJson).toList(growable: false),
        categories: _maps(json['categories']).map(HelpdeskCategory.fromJson).toList(growable: false),
        replies: _maps(json['replies']).map(HelpdeskSavedReply.fromJson).toList(growable: false),
        targetDays: _int(json['targetDays'], 1),
      );

  Map<String, dynamic> toJson() => {
        'teams': [for (final t in teams) t.toJson()],
        'categories': [for (final c in categories) c.toJson()],
        'replies': [for (final r in replies) r.toJson()],
        'targetDays': targetDays,
      };
}
