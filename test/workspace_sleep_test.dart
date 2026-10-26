import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Always answers; counts the calls that reached it.
class _Counting implements HttpClientAdapter {
  int calls = 0;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    seen.add(options);
    return ResponseBody.fromString('{}', 200, headers: {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  tearDown(WorkspaceSleepGate.wake);

  test('while the workspace sleeps nothing reaches it, but the call that wakes it', () async {
    final adapter = _Counting();
    final core = AgentivityHttpCore(dio: Dio(BaseOptions(baseUrl: 'https://acme.agentivity.app/'))..httpClientAdapter = adapter, baseUrl: 'https://acme.agentivity.app/');

    WorkspaceSleepGate.fallAsleep();
    await expectLater(core.get<dynamic>('/api/v1/workflows'), throwsA(isA<ApiException>()));
    await expectLater(openStreamingRequest(core.dio, 'GET', '/api/v1/streams/s1/events'), throwsA(isA<DioException>()));
    expect(adapter.calls, 0);

    await core.post<dynamic>('/api/v1/hosting/awake', options: Options(extra: {WorkspaceSleepGate.wakesKey: true}));
    expect(adapter.calls, 1);

    WorkspaceSleepGate.wake();
    await core.get<dynamic>('/api/v1/workflows');
    expect(adapter.calls, 2);
  });

  test('when it sleeps is read against the clock of the server', () {
    final received = DateTime(2031, 3, 4, 10, 0, 0);
    final said = WorkspaceSleep.fromJson({'sleeps': true, 'sleepsAt': '2031-03-04T09:08:00Z', 'now': '2031-03-04T09:00:00Z', 'idleMinutes': 10}, receivedAt: received);
    expect(said.sleeps, isTrue);
    expect(said.sleepsAt, received.add(const Duration(minutes: 8)), reason: 'eight minutes left, whatever the clock here');
    expect(said.idleMinutes, 10);

    final held = WorkspaceSleep.fromJson({'sleeps': true, 'sleepsAt': null, 'heldBy': 'going on: 1 workflow', 'now': '2031-03-04T09:00:00Z'});
    expect(held.sleepsAt, isNull);
    expect(held.heldBy, 'going on: 1 workflow');
  });

  test('waking it goes through the gate, then opens it', () async {
    final adapter = _Counting();
    final client = AgentivityClient(dio: Dio(BaseOptions(baseUrl: 'https://acme.agentivity.app/'))..httpClientAdapter = adapter, baseUrl: 'https://acme.agentivity.app/');

    WorkspaceSleepGate.fallAsleep();
    await client.sleep.wake();
    expect(adapter.calls, 1);
    expect(WorkspaceSleepGate.asleep, isFalse);
  });

  test('a read made in the background is marked, what a person asks is not', () async {
    final adapter = _Counting();
    final core = AgentivityHttpCore(dio: Dio(BaseOptions(baseUrl: 'https://acme.agentivity.app/'))..httpClientAdapter = adapter, baseUrl: 'https://acme.agentivity.app/');

    await WorkspaceSleepGate.inBackground(() => core.get<dynamic>('/api/v1/runs'));
    await core.get<dynamic>('/api/v1/workflows');

    expect(adapter.seen[0].headers[WorkspaceSleepGate.backgroundHeader], '1');
    expect(adapter.seen[1].headers.containsKey(WorkspaceSleepGate.backgroundHeader), isFalse);
  });
}
