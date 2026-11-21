import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/http_core.dart';
import '../domain/helpdesk_models.dart';
import '../domain/support_models.dart';

/// The help desk of the workspace. For the people of the Desk: ask for help and follow their requests. For its agents (Helpdesk
/// agent, Helpdesk lead): the inbox by team, answers, notes, transfers, and passing a request to the support of Agentivity.
class HelpdeskApi {
  HelpdeskApi(this._c);

  final AgentivityHttpCore _c;

  static const _upload = Duration(seconds: 90);

  List<Map<String, dynamic>> _files(List<SupportUpload> files) => [for (final f in files) f.toJson()];

  // GET /api/v1/helpdesk
  Future<HelpdeskAvailability> availability() async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/helpdesk'));
    return HelpdeskAvailability.fromJson(response.data ?? const {});
  }

  // ── The person who asks ──────────────────────────────────────────────

  // GET /api/v1/helpdesk/requests
  /// One's requests, the latest active first.
  Future<List<HelpdeskRequest>> requests() async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/helpdesk/requests'));
    final list = (response.data ?? const {})['requests'];
    return list is List ? list.whereType<Map>().map((e) => HelpdeskRequest.fromJson(Map<String, dynamic>.from(e))).toList(growable: false) : const [];
  }

  // POST /api/v1/helpdesk/requests
  Future<HelpdeskRequest> open({
    required String categoryId,
    required String subject,
    required String body,
    String? language,
    HelpdeskContext? context,
    List<SupportUpload> files = const [],
  }) async {
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/helpdesk/requests'),
      data: {'categoryId': categoryId, 'subject': subject, 'body': body, 'language': language, 'context': context?.toJson(), 'files': _files(files)},
      options: Options(sendTimeout: _upload),
    );
    return HelpdeskRequest.fromJson(response.data ?? const {});
  }

  // GET /api/v1/helpdesk/requests/{number}
  /// One of one's requests and its thread; what the help desk answered is no longer new once read.
  Future<HelpdeskRequest> request(int number) async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/helpdesk/requests/$number'));
    return HelpdeskRequest.fromJson(response.data ?? const {});
  }

  // POST /api/v1/helpdesk/requests/{number}/messages
  Future<HelpdeskRequest> reply(int number, String body, {List<SupportUpload> files = const []}) async {
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/helpdesk/requests/$number/messages'),
      data: {'body': body, 'files': _files(files)},
      options: Options(sendTimeout: _upload),
    );
    return HelpdeskRequest.fromJson(response.data ?? const {});
  }

  // POST /api/v1/helpdesk/requests/{number}/status
  Future<HelpdeskRequest> setResolved(int number, bool resolved) async {
    final response = await _c.post<Map<String, dynamic>>(AgentivityHttpCore.v1('/helpdesk/requests/$number/status'), data: {'resolved': resolved});
    return HelpdeskRequest.fromJson(response.data ?? const {});
  }

  // POST /api/v1/helpdesk/requests/{number}/rating
  Future<HelpdeskRequest> rate(int number, {required bool good, String? comment}) async {
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/helpdesk/requests/$number/rating'),
      data: {'rating': good ? 'good' : 'bad', 'comment': comment},
    );
    return HelpdeskRequest.fromJson(response.data ?? const {});
  }

  // GET /api/v1/helpdesk/requests/{number}/files/{fileId}
  Future<Uint8List> file(int number, String fileId) => _bytes('/helpdesk/requests/$number/files/${Uri.encodeComponent(fileId)}');

  // ── The agents ───────────────────────────────────────────────────────

  // GET /api/v1/helpdesk/inbox
  /// [view]: open, mine, team, unassigned, late, waiting_requester, escalated, resolved, closed, all.
  Future<HelpdeskInbox> inbox({String view = 'open', String? search}) async {
    final response = await _c.get<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/helpdesk/inbox'),
      queryParameters: {'view': view, if (search != null && search.trim().isNotEmpty) 'search': search.trim()},
    );
    return HelpdeskInbox.fromJson(response.data ?? const {});
  }

  // GET /api/v1/helpdesk/inbox/{number}
  Future<HelpdeskTicketDetail> ticket(int number) async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/helpdesk/inbox/$number'));
    return HelpdeskTicketDetail.fromJson(response.data ?? const {});
  }

  // POST /api/v1/helpdesk/inbox/{number}/reply
  /// Answers the person (told by e-mail); with [resolve], resolves the request with it.
  Future<HelpdeskTicket> answer(int number, String body, {bool resolve = false, List<SupportUpload> files = const []}) async {
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/helpdesk/inbox/$number/reply'),
      data: {'body': body, 'resolve': resolve, 'files': _files(files)},
      options: Options(sendTimeout: _upload),
    );
    return HelpdeskTicket.fromJson(response.data ?? const {});
  }

  // POST /api/v1/helpdesk/inbox/{number}/note
  /// A note for the help desk, that the person never sees.
  Future<HelpdeskTicket> note(int number, String body, {List<SupportUpload> files = const []}) async {
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/helpdesk/inbox/$number/note'),
      data: {'body': body, 'files': _files(files)},
      options: Options(sendTimeout: _upload),
    );
    return HelpdeskTicket.fromJson(response.data ?? const {});
  }

  // POST /api/v1/helpdesk/inbox/{number}/change
  /// Changes the status, the priority, who is on it ('' for nobody) or the team (a transfer).
  Future<HelpdeskTicket> change(int number, {HelpdeskStatus? status, HelpdeskPriority? priority, String? assigneeId, String? teamId}) async {
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/helpdesk/inbox/$number/change'),
      data: {'status': status?.code, 'priority': priority?.name, 'assigneeId': assigneeId, 'teamId': teamId},
    );
    return HelpdeskTicket.fromJson(response.data ?? const {});
  }

  // POST /api/v1/helpdesk/inbox/{number}/escalate
  /// Passes the request to the support of Agentivity, in the name of the agent; [joinThread] joins what the person and the help
  /// desk wrote (never the notes).
  Future<HelpdeskTicket> escalate(
    int number, {
    required SupportKind kind,
    SupportSeverity? severity,
    String? subject,
    required String body,
    bool joinThread = true,
    String? language,
    List<SupportUpload> files = const [],
  }) async {
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/helpdesk/inbox/$number/escalate'),
      data: {
        'kind': kind.name,
        'severity': severity?.name,
        'subject': subject,
        'body': body,
        'joinThread': joinThread,
        'language': language,
        'files': _files(files),
      },
      options: Options(sendTimeout: _upload),
    );
    return HelpdeskTicket.fromJson(response.data ?? const {});
  }

  // POST /api/v1/helpdesk/inbox/{number}/escalation/messages
  /// Writes to the support of Agentivity in the request this one was passed to.
  Future<void> writeToSupport(int number, String body, {List<SupportUpload> files = const []}) async {
    await _c.post<dynamic>(
      AgentivityHttpCore.v1('/helpdesk/inbox/$number/escalation/messages'),
      data: {'body': body, 'files': _files(files)},
      options: Options(sendTimeout: _upload),
    );
  }

  // GET /api/v1/helpdesk/inbox/{number}/files/{fileId}
  Future<Uint8List> ticketFile(int number, String fileId) => _bytes('/helpdesk/inbox/$number/files/${Uri.encodeComponent(fileId)}');

  // GET /api/v1/helpdesk/inbox/{number}/support-files/{attachmentId}
  Future<Uint8List> supportFile(int number, String attachmentId) => _bytes('/helpdesk/inbox/$number/support-files/${Uri.encodeComponent(attachmentId)}');

  // GET /api/v1/helpdesk/agents
  Future<List<HelpdeskAgentInfo>> agents() async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/helpdesk/agents'));
    final list = (response.data ?? const {})['agents'];
    return list is List ? list.whereType<Map>().map((e) => HelpdeskAgentInfo.fromJson(Map<String, dynamic>.from(e))).toList(growable: false) : const [];
  }

  // ── Setup ───────────────────────────────────────────────────────────

  // GET /api/v1/helpdesk/setup
  Future<HelpdeskSetup> setup() async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/helpdesk/setup'));
    return HelpdeskSetup.fromJson(response.data ?? const {});
  }

  // PUT /api/v1/helpdesk/setup
  /// Sets the teams, the categories, the saved replies and the target (leads only).
  Future<HelpdeskSetup> saveSetup(HelpdeskSetup setup) async {
    final response = await _c.put<Map<String, dynamic>>(AgentivityHttpCore.v1('/helpdesk/setup'), data: setup.toJson());
    return HelpdeskSetup.fromJson(response.data ?? const {});
  }

  Future<Uint8List> _bytes(String path) async {
    final response = await _c.get<List<int>>(AgentivityHttpCore.v1(path), options: Options(responseType: ResponseType.bytes));
    return Uint8List.fromList(response.data ?? const []);
  }
}
