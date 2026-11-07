import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/http_core.dart';
import '../../core/streaming_request.dart';
import '../domain/cockpit_models.dart';
import '../domain/desk_models.dart';

/// A person's own work on an instance, as Agentivity Desk shows it (it works only with Solutions): how the Desk looks and what it publishes, their conversations
/// as they keep them (searched, filtered, a page at a time; renamed, pinned, archived, in groups of theirs), what waits for their
/// answer, the people a conversation is shared with, and the time the teams saved them. Changing how the Desk looks is for who
/// changes the settings of the instance ([setup], [saveSetup]).
///
/// Part of [AgentivityPlatformClient].
class DeskApi {
  DeskApi(this._c);
  final AgentivityHttpCore _c;

  // GET /api/v1/desk
  Future<DeskOverview> overview() async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/desk'));
    return DeskOverview.fromJson(response.data ?? const {});
  }

  // GET /api/v1/desk/changes (text/event-stream)
  /// Each time something the Desk shows changes (a conversation that waits, ends, is archived, shared, deleted; a group, a
  /// cockpit), its number: the Desk then reads itself again. The first comes at once. The stream ends when the line is cut or
  /// [cancelToken] is cancelled; listening again is the caller's.
  Stream<int> changes({CancelToken? cancelToken}) async* {
    final body = await openStreamingRequest(
      _c.dio,
      'GET',
      AgentivityHttpCore.v1('/desk/changes'),
      headers: {Headers.acceptHeader: 'text/event-stream', 'Cache-Control': 'no-cache'},
      cancelToken: cancelToken,
    );
    final lines = body.stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final data = jsonDecode(line.substring(5).trim());
      if (data is Map && data['version'] is num) yield (data['version'] as num).toInt();
    }
  }

  // GET /api/v1/desk/conversations
  Future<DeskConversationPage> conversations([DeskConversationQuery query = const DeskConversationQuery()]) async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/desk/conversations'), queryParameters: query.toQuery());
    return DeskConversationPage.fromJson(response.data ?? const {});
  }

  // GET /api/v1/desk/conversations/{executionId}
  Future<DeskConversation> conversation(String executionId) async {
    final id = _c.requireNormalizedId(executionId, label: 'Execution id');
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/desk/conversations/$id'));
    return DeskConversation.fromJson(response.data ?? const {});
  }

  /// Renames, pins, archives or puts in a group (an empty [groupId]: in none) the conversations [executionIds]. An empty [title]
  /// gives a conversation its first words again. What is null stays as it is.
  // POST /api/v1/desk/conversations/marks
  Future<void> mark(List<String> executionIds, {String? title, bool? pinned, bool? archived, String? groupId}) async {
    await _c.post<dynamic>(AgentivityHttpCore.v1('/desk/conversations/marks'), data: {
      'executionIds': executionIds,
      if (title != null) 'title': title,
      if (pinned != null) 'pinned': pinned,
      if (archived != null) 'archived': archived,
      if (groupId != null) 'groupId': groupId,
    });
  }

  /// Deletes a conversation the caller started: stopped first if it goes on, its questions go with it, and it leaves every list.
  // DELETE /api/v1/desk/conversations/{executionId}
  Future<void> deleteConversation(String executionId) async {
    final id = _c.requireNormalizedId(executionId, label: 'Execution id');
    await _c.delete<dynamic>(AgentivityHttpCore.v1('/desk/conversations/$id'));
  }

  /// Adds a group of one's conversations ([groupId] null), or changes one: every conversation with one of [solutionIds] is in it by
  /// itself.
  // POST /api/v1/desk/groups, PUT /api/v1/desk/groups/{groupId}
  Future<void> saveGroup({String? groupId, required String name, required String colour, List<String> solutionIds = const []}) async {
    final data = {'name': name, 'colour': colour, 'solutionIds': solutionIds};
    if (groupId == null) {
      await _c.post<dynamic>(AgentivityHttpCore.v1('/desk/groups'), data: data);
    } else {
      await _c.put<dynamic>(AgentivityHttpCore.v1('/desk/groups/${Uri.encodeComponent(groupId)}'), data: data);
    }
  }

  /// Deletes a group of one's conversations: they stay, in no group.
  // DELETE /api/v1/desk/groups/{groupId}
  Future<void> deleteGroup(String groupId) async {
    await _c.delete<dynamic>(AgentivityHttpCore.v1('/desk/groups/${Uri.encodeComponent(groupId)}'));
  }

  /// Whether one is told by e-mail of a question asked to them.
  // PUT /api/v1/desk/notifications
  Future<void> setEmailQuestions(bool email) async {
    await _c.put<dynamic>(AgentivityHttpCore.v1('/desk/notifications'), data: {'emailQuestions': email});
  }

  /// The time the teams saved the caller; with [cockpitId], also what the teams of that cockpit saved this month.
  // GET /api/v1/desk/gains
  Future<DeskGains> gains({String? cockpitId}) async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/desk/gains'), queryParameters: {if (cockpitId != null) 'cockpit': cockpitId});
    return DeskGains.fromJson(response.data ?? const {});
  }

  /// A cockpit as the caller sees it: as published; or its [draft], for who may change it (a preview from the Studio).
  // GET /api/v1/desk/cockpits/{cockpitId}
  Future<CockpitView> cockpit(String cockpitId, {bool draft = false}) async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/desk/cockpits/${Uri.encodeComponent(cockpitId)}'), queryParameters: {if (draft) 'draft': true});
    return CockpitView.fromJson(response.data ?? const {});
  }

  /// What a block of a cockpit shows of a Data Table: its figure, or its rows.
  // GET /api/v1/desk/cockpits/{cockpitId}/blocks/{blockId}
  Future<CockpitBlockData> cockpitBlock(String cockpitId, String blockId, {bool draft = false}) async {
    final response = await _c.get<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/desk/cockpits/${Uri.encodeComponent(cockpitId)}/blocks/${Uri.encodeComponent(blockId)}'),
      queryParameters: {if (draft) 'draft': true},
    );
    return CockpitBlockData.fromJson(response.data ?? const {});
  }

  /// The questions and approvals waiting for the caller's answer, newest first.
  // GET /api/v1/questions
  Future<List<DeskQuestion>> questions() async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/questions'));
    final list = (response.data ?? const {})['questions'];
    return list is List ? list.whereType<Map>().map((q) => DeskQuestion.fromJson(Map<String, dynamic>.from(q))).toList(growable: false) : const [];
  }

  /// The people a conversation is shared with, and those a question of it is asked to.
  // GET /api/v1/executions/{executionId}/participants
  Future<List<DeskParticipant>> participants(String executionId) async {
    final id = _c.requireNormalizedId(executionId, label: 'Execution id');
    final data = (await _c.get<dynamic>(AgentivityHttpCore.v1('/executions/$id/participants'))).data;
    final list = data is Map ? data['participants'] : data;
    return list is List ? list.whereType<Map>().map((p) => DeskParticipant.fromJson(Map<String, dynamic>.from(p))).toList(growable: false) : const [];
  }

  /// Shares a conversation with [person] (their e-mail or id): to read it, or to reply in it too.
  // PUT /api/v1/executions/{executionId}/participants/{person}
  Future<void> share(String executionId, String person, {required bool mayReply}) async {
    final id = _c.requireNormalizedId(executionId, label: 'Execution id');
    await _c.put<dynamic>(AgentivityHttpCore.v1('/executions/$id/participants/${Uri.encodeComponent(person)}'), data: {'mayReply': mayReply});
  }

  /// Stops sharing a conversation with [personId]; for oneself, leaves it.
  // DELETE /api/v1/executions/{executionId}/participants/{personId}
  Future<void> unshare(String executionId, String personId) async {
    final id = _c.requireNormalizedId(executionId, label: 'Execution id');
    await _c.delete<dynamic>(AgentivityHttpCore.v1('/executions/$id/participants/${Uri.encodeComponent(personId)}'));
  }

  /// How the Desk looks and what it shows, to set it (who changes the settings of the instance).
  // GET /api/v1/desk/setup
  Future<DeskSetup> setup() async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/desk/setup'));
    return DeskSetup.fromJson(response.data ?? const {});
  }

  // PUT /api/v1/desk/setup
  Future<DeskSetup> saveSetup(DeskSetup setup) async {
    final response = await _c.put<Map<String, dynamic>>(AgentivityHttpCore.v1('/desk/setup'), data: setup.toJson());
    return DeskSetup.fromJson(response.data ?? const {});
  }
}
