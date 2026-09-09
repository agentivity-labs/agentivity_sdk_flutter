import '../../core/http_core.dart';
import '../domain/chat_models.dart';

/// Conversation history endpoints.
///
/// Part of the lightweight [AgentivityClient].
class ConversationsApi {
  ConversationsApi(this._c);
  final AgentivityHttpCore _c;

  // ---------------------------------------------------------------------------
  // GET /api/v1/executions/{executionId}/threads
  // GET /api/v1/executions/{executionId}/threads/{threadId}/messages
  // ---------------------------------------------------------------------------

  Future<List<InteractionThread>> fetchExecutionThreads(String executionId) async {
    final normalized = _c.requireNormalizedId(executionId, label: 'Execution id');
    final response = await _c.get<List<dynamic>>(
      AgentivityHttpCore.v1('/executions/$normalized/threads'),
    );
    final data = response.data ?? const <dynamic>[];
    return data.map((entry) {
      if (entry is Map<String, dynamic>) return InteractionThread.fromJson(entry);
      if (entry is Map) return InteractionThread.fromJson(Map<String, dynamic>.from(entry));
      throw StateError('Unsupported thread payload: ${entry.runtimeType}');
    }).toList(growable: false);
  }

  Future<List<ThreadMessage>> fetchExecutionThreadMessages({
    required String executionId,
    required String threadId,
  }) async {
    final normalizedExecution = _c.requireNormalizedId(executionId, label: 'Execution id');
    final normalizedThread = _c.requireNormalizedId(threadId, label: 'Thread id');
    final response = await _c.get<List<dynamic>>(
      AgentivityHttpCore.v1(
        '/executions/$normalizedExecution/threads/$normalizedThread/messages',
      ),
    );
    final data = response.data ?? const <dynamic>[];
    return data.map((entry) {
      if (entry is Map<String, dynamic>) return ThreadMessage.fromJson(entry);
      if (entry is Map) return ThreadMessage.fromJson(Map<String, dynamic>.from(entry));
      throw StateError('Unsupported message payload: ${entry.runtimeType}');
    }).toList(growable: false);
  }
}
