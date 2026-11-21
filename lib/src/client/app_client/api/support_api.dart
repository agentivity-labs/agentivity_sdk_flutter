import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/http_core.dart';
import '../domain/support_models.dart';

/// The support of Agentivity for the person signed in on a hosted workspace: ask, follow one's requests, write in them, resolve or
/// reopen them, rate them, read their files. A workspace not hosted by Agentivity (Community) has none: [availability] says so.
class SupportApi {
  SupportApi(this._c);

  final AgentivityHttpCore _c;

  // GET /api/v1/support
  Future<SupportAvailability> availability() async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/support'));
    return SupportAvailability.fromJson(response.data ?? const {});
  }

  // GET /api/v1/support/tickets
  /// One's requests, the latest first.
  Future<List<SupportTicket>> tickets() async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/support/tickets'));
    final list = (response.data ?? const {})['tickets'];
    return list is List ? list.whereType<Map>().map((e) => SupportTicket.fromJson(Map<String, dynamic>.from(e))).toList(growable: false) : const [];
  }

  // POST /api/v1/support/tickets
  /// Asks the support. [context] is what the app joins of itself (page, platform, the execution concerned); the workspace adds
  /// who asks, its plan and its version.
  Future<SupportTicket> open({
    required SupportKind kind,
    SupportSeverity? severity,
    required String subject,
    required String body,
    String? language,
    Map<String, dynamic>? context,
    List<SupportUpload> files = const [],
  }) async {
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/support/tickets'),
      data: {
        'kind': kind.name,
        'severity': severity?.name,
        'subject': subject,
        'body': body,
        'language': language,
        'context': context,
        'files': [for (final f in files) f.toJson()],
      },
      options: Options(sendTimeout: const Duration(seconds: 90)),
    );
    return SupportTicket.fromJson(response.data ?? const {});
  }

  // GET /api/v1/support/tickets/{number}
  Future<SupportThread> thread(int number) async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/support/tickets/$number'));
    return SupportThread.fromJson(response.data ?? const {});
  }

  // POST /api/v1/support/tickets/{number}/messages
  /// Writes in one's request; a resolved one reopens.
  Future<SupportTicket> reply(int number, String body, {List<SupportUpload> files = const []}) async {
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/support/tickets/$number/messages'),
      data: {'body': body, 'files': [for (final f in files) f.toJson()]},
      options: Options(sendTimeout: const Duration(seconds: 90)),
    );
    return SupportTicket.fromJson(response.data ?? const {});
  }

  // POST /api/v1/support/tickets/{number}/status
  /// Says the request is resolved ([resolved] true), or reopens it.
  Future<SupportTicket> setResolved(int number, bool resolved) async {
    final response = await _c.post<Map<String, dynamic>>(AgentivityHttpCore.v1('/support/tickets/$number/status'), data: {'resolved': resolved});
    return SupportTicket.fromJson(response.data ?? const {});
  }

  // POST /api/v1/support/tickets/{number}/rating
  /// How the request was handled: good or bad, and a word.
  Future<SupportTicket> rate(int number, {required bool good, String? comment}) async {
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/support/tickets/$number/rating'),
      data: {'rating': good ? 'good' : 'bad', 'comment': comment},
    );
    return SupportTicket.fromJson(response.data ?? const {});
  }

  // GET /api/v1/support/tickets/{number}/files/{attachmentId}
  Future<Uint8List> file(int number, String attachmentId) async {
    final response = await _c.get<List<int>>(
      AgentivityHttpCore.v1('/support/tickets/$number/files/${Uri.encodeComponent(attachmentId)}'),
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }
}
