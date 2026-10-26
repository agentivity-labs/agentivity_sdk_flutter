import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers after [delay]; the workspace that wakes up, held by its gateway.
class _Late implements HttpClientAdapter {
  _Late(this.delay);

  final Duration delay;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    await Future<void>.delayed(delay);
    return ResponseBody.fromString('{}', 200, headers: {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('a call that waits past a few seconds is said, and no longer once answered', () async {
    final core = AgentivityHttpCore(dio: Dio(BaseOptions(baseUrl: 'https://acme.agentivity.app/'))..httpClientAdapter = _Late(const Duration(milliseconds: 300)), baseUrl: 'https://acme.agentivity.app/');
    final slow = SlowCalls(after: const Duration(milliseconds: 100));
    final seen = <DateTime?>[];
    slow.addListener(() => seen.add(slow.value));

    await slow.follow(() => core.get<dynamic>('/api/v1/workflows'));
    expect(seen, hasLength(2));
    expect(seen.first, isNotNull);
    expect(seen.last, isNull);

    await WorkspaceSleepGate.inBackground(() => slow.follow(() => core.get<dynamic>('/api/v1/workflows')));
    expect(seen, hasLength(2), reason: 'a read the app makes by itself: nobody waits for it');
  });

  test('a call waits as long as the gateway holds it for a workspace that wakes up', () {
    expect(AgentivityHttpCore.wakeWait, greaterThan(const Duration(minutes: 2)));
    final core = AgentivityHttpCore(baseUrl: 'https://acme.agentivity.app/');
    expect(core.dio.options.receiveTimeout, AgentivityHttpCore.wakeWait);
  });

  testWidgets('the notice says a moment, then almost there, then longer than usual, and goes', (tester) async {
    final waiting = ValueNotifier<DateTime?>(null);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AgUiWaitOverlay(waiting: waiting, onRetry: () {}, child: const Text('the app')))));
    expect(find.text('Just a moment…'), findsNothing);

    waiting.value = DateTime.now();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Just a moment…'), findsOneWidget);
    expect(find.text('Getting things ready.'), findsOneWidget);
    expect(find.text('the app'), findsOneWidget);

    waiting.value = DateTime.now().subtract(const Duration(seconds: 20));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Almost there…'), findsOneWidget);

    waiting.value = DateTime.now().subtract(const Duration(seconds: 70));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Taking a bit longer than usual.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    waiting.value = null;
    await tester.pumpAndSettle();
    expect(find.text('Just a moment…'), findsNothing);
  });
}
