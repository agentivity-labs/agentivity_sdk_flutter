import 'dart:async';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatController _controller() => ChatController.fromStream(events: const Stream<AgUiEvent>.empty());

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) => handler(options);

  @override
  void close({bool force = false}) {}
}

AgentivityClient _client(Future<ResponseBody> Function(RequestOptions) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/'))..httpClientAdapter = _Adapter(handler);
  return AgentivityClient(dio: dio, baseUrl: 'https://api.example.com');
}

Future<ResponseBody> _answer(int status) async => ResponseBody.fromString('{}', status, headers: {Headers.contentTypeHeader: ['application/json']});

void main() {
  group('ConnectionMonitor', () {
    testWidgets('goes offline on a failed request, probes on a growing delay and comes back when the server answers', (tester) async {
      final answers = [false, false, true];
      var probes = 0;
      final monitor = ConnectionMonitor(
        probe: () async {
          probes++;
          return answers.removeAt(0);
        },
        delays: const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)],
      );
      addTearDown(monitor.dispose);

      monitor.httpFailed('Connection refused');
      expect(monitor.value.offline, isTrue);
      expect(monitor.value.reason, 'Connection refused');
      expect(monitor.value.attempt, 0);

      await tester.pump(const Duration(seconds: 1));
      expect(probes, 1);
      expect(monitor.value.attempt, 1);
      expect(monitor.value.nextRetryAt, isNotNull);

      await tester.pump(const Duration(seconds: 2));
      expect(monitor.value.attempt, 2);

      await tester.pump(const Duration(seconds: 4));
      expect(monitor.value.offline, isFalse);
      expect(monitor.value.recoveredAt, isNotNull);
      expect(probes, 3);
    });

    testWidgets('is online again as soon as any request gets an answer, and stops probing', (tester) async {
      var probes = 0;
      final monitor = ConnectionMonitor(probe: () async => ++probes < 0, delays: const [Duration(seconds: 1)]);
      addTearDown(monitor.dispose);
      monitor.httpFailed();
      monitor.httpReachable();

      expect(monitor.value.offline, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(probes, 0);
    });

    testWidgets('retryNow probes at once', (tester) async {
      var probes = 0;
      final monitor = ConnectionMonitor(
        probe: () async {
          probes++;
          return true;
        },
        delays: const [Duration(minutes: 1)],
      );
      addTearDown(monitor.dispose);
      monitor.httpFailed();
      monitor.retryNow();
      await tester.pump();

      expect(probes, 1);
      expect(monitor.value.offline, isFalse);
    });

    test('follows a stream that is reconnecting, and can retry it', () {
      var retried = 0;
      final monitor = ConnectionMonitor();
      addTearDown(monitor.dispose);
      monitor.setStream('s1', StreamConnection(offline: true, attempt: 3, nextRetryAt: DateTime.now().add(const Duration(seconds: 12)), retry: () => retried++));

      expect(monitor.value.offline, isTrue);
      expect(monitor.value.attempt, 3);

      monitor.retryNow();
      expect(retried, 1);

      monitor.setStream('s1', const StreamConnection(offline: false));
      expect(monitor.value.offline, isFalse);
    });
  });

  group('the transport reports to the monitor', () {
    test('a request that gets no answer makes the client offline; the next answer (even an error) brings it back', () async {
      var up = false;
      final client = _client((options) async {
        if (!up) throw DioException(requestOptions: options, type: DioExceptionType.connectionError, message: 'Connection refused');
        return _answer(404);
      });
      addTearDown(client.connection.dispose);

      await expectLater(client.runs.fetchExecutionStatuses('e1'), completion(isNull));
      expect(client.connection.value.offline, isTrue);
      expect(client.connection.value.reason, contains('Connection refused'));

      up = true;
      await client.runs.fetchExecutionStatuses('e1');
      expect(client.connection.value.offline, isFalse);
    });

    test('a gateway error (502/503/504) counts as unreachable', () async {
      final client = _client((options) => _answer(503));
      addTearDown(client.connection.dispose);

      await client.runs.fetchExecutionStatuses('e1');
      expect(client.connection.value.offline, isTrue);
      expect(client.connection.value.reason, contains('503'));
    });
  });

  group('the connection notice', () {
    testWidgets('says the server cannot be reached, counts down to the next attempt and retries on demand', (tester) async {
      var retried = 0;
      final monitor = ConnectionMonitor();
      addTearDown(monitor.dispose);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: AgUiConnectionNotice(monitor: monitor))));
      expect(find.textContaining("Can't reach the server"), findsNothing);

      monitor.setStream('s', StreamConnection(offline: true, attempt: 1, nextRetryAt: DateTime.now().add(const Duration(seconds: 12)), reason: 'Connection refused', retry: () => retried++));
      await tester.pump();
      expect(find.text("Can't reach the server"), findsOneWidget);
      expect(find.textContaining('next attempt in'), findsOneWidget);
      expect(find.text('Connection refused'), findsOneWidget);

      await tester.tap(find.text('Retry now'));
      expect(retried, 1);

      monitor.setStream('s', const StreamConnection(offline: false));
      await tester.pump();
      expect(find.text('Connection restored'), findsOneWidget);
      // The notice reads the wall clock, which the test clock does not move: let 3 real seconds go by.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 3100)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Connection restored'), findsNothing);
    });

    test('words each state', () {
      final now = DateTime(2026, 10, 3, 12);
      expect(agUiDescribeConnection(const ServerConnectionState(offline: true, attempt: 2, retrying: true), now)?.detail, 'Trying to reconnect…');
      expect(agUiDescribeConnection(ServerConnectionState(offline: true, attempt: 1, nextRetryAt: now.add(const Duration(milliseconds: 9400))), now)?.secondsLeft, 10);
      expect(agUiDescribeConnection(ServerConnectionState.online, now), isNull);
    });

    testWidgets('appears in a conversation given the connection, with no other wiring', (tester) async {
      final monitor = ConnectionMonitor();
      addTearDown(monitor.dispose);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: AgUiChatDiscussion(controller: _controller(), threadId: 't1', connection: monitor))));
      monitor.httpFailed('Connection refused');
      await tester.pump();

      expect(find.text("Can't reach the server"), findsOneWidget);
      monitor.httpReachable();
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
