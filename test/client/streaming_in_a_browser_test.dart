@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// In a browser, a stream the server keeps open (the realtime events, a run, a chat) reaches the page as it comes. The
/// server here sends a first line, then keeps the connection open, as the platform's streams do.
///
/// Run with: flutter test --platform chrome test/client/streaming_in_a_browser_test.dart
void main() {
  late int port;

  setUpAll(() async {
    final server = spawnHybridCode(r'''
      import 'dart:io';
      import 'package:stream_channel/stream_channel.dart';

      Future<void> hybridMain(StreamChannel channel) async {
        final server = await HttpServer.bind('127.0.0.1', 0);
        server.listen((request) async {
          final response = request.response;
          response.headers.set('Access-Control-Allow-Origin', '*');
          response.headers.set('Access-Control-Allow-Headers', '*');
          response.headers.set('Access-Control-Allow-Methods', 'GET, POST');
          if (request.method == 'OPTIONS') {
            await response.close();
            return;
          }
          final body = await request.cast<List<int>>().transform(const SystemEncoding().decoder).join();
          response.headers.set('Content-Type', 'text/event-stream');
          response.bufferOutput = false;
          response.write('retry: 5000\n\ndata: {"seen":"${request.method} ${request.uri.path} $body"}\n\n');
          await response.flush();
          // Never closed: like the platform's streams.
        });
        channel.sink.add(server.port);
      }
    ''');
    port = await server.stream.first as int;
  });

  Future<String> firstLines(Stream<List<int>> stream) => stream.map(utf8.decode).firstWhere((text) => text.contains('data:')).timeout(const Duration(seconds: 5));

  test('the realtime stream reaches the page as it comes, though it never ends', () async {
    final client = AgentivityClient(baseUrl: 'http://127.0.0.1:$port');
    final cancel = CancelToken();
    addTearDown(cancel.cancel);

    final body = await client.runs.openEventStream('/api/v1/streams/runs/events', cancelToken: cancel).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Nothing came: the browser waits for the end of a stream that never ends.'),
        );

    expect(await firstLines(body.stream), contains('GET /api/v1/streams/runs/events'));
  });

  test('a stream asked with a message (a chat) reaches the page too, with what was sent', () async {
    final connector = AgUiGenericConnector(baseUrl: 'http://127.0.0.1:$port');

    final event = await connector.run(path: '/agui').first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Nothing came: the browser waits for the end of a stream that never ends.'),
        );

    // What the page sent (an empty input: "{}") reached the server.
    expect(event, isA<RunStartedEvent>().having((e) => e.runId, 'runId', 'posted 2'));
  });
}
