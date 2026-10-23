import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers 502 [asleep] times (the gateway, while the workspace starts), then 200; counts the calls.
class _Waking implements HttpClientAdapter {
  _Waking(this.asleep);

  int asleep;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    if (asleep-- > 0) return ResponseBody.fromString('', 502, headers: {'retry-after': ['1']});
    return ResponseBody.fromString('[]', 200, headers: {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('a read waits for a workspace that wakes up, and comes back', () async {
    final adapter = _Waking(2);
    final core = AgentivityHttpCore(dio: Dio(BaseOptions(baseUrl: 'https://acme.agentivity.app/'))..httpClientAdapter = adapter, baseUrl: 'https://acme.agentivity.app/');

    final response = await core.get<List<dynamic>>('/api/v1/workflows');

    expect(response.statusCode, 200);
    expect(adapter.calls, 3);
  });

  test('a write is never sent twice', () async {
    final adapter = _Waking(5);
    final core = AgentivityHttpCore(dio: Dio(BaseOptions(baseUrl: 'https://acme.agentivity.app/'))..httpClientAdapter = adapter, baseUrl: 'https://acme.agentivity.app/');

    await expectLater(core.post<dynamic>('/api/v1/executions', data: {'entityId': 'w1'}), throwsA(isA<ApiException>()));
    expect(adapter.calls, 1);
  });

  test('a read stops waiting after its wait, and says the server is out of reach', () {
    expect(WakingWorkspaceInterceptor.waitBeforeAskingAgain('GET', 503, null, const Duration(seconds: 58), const Duration(minutes: 1)), isNull);
    expect(WakingWorkspaceInterceptor.waitBeforeAskingAgain('GET', 503, '2', Duration.zero, const Duration(minutes: 1)), const Duration(seconds: 2));
    expect(WakingWorkspaceInterceptor.waitBeforeAskingAgain('GET', 500, null, Duration.zero, const Duration(minutes: 1)), isNull, reason: 'the workspace answered');
  });
}
