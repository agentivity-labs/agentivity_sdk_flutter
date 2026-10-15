import 'dart:async';
import 'dart:typed_data';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Kept apart from ag_ui_sse_channel_test.dart: that file runs without a Flutter binding
// (as AgentivityPlatformConnector may), this one initialises it to exercise the
// foreground-resume reconnect.

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // Builds a channel whose every connection ends at once, so it sits in its backoff wait.
  ({AgUiSseChannel<String> channel, int Function() opens}) droppingChannel() {
    var opens = 0;
    final channel = AgUiSseChannel<String>(
      opener: (_, {lastEventId, cancelToken}) async {
        opens++;
        final body = StreamController<Uint8List>();
        unawaited(body.close());
        return ResponseBody(body.stream, 200, headers: {});
      },
      path: '/',
      parser: (_, __, d) => d,
    );
    return (channel: channel, opens: () => opens);
  }

  void backgroundThenResume() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  test('app resume reconnects at once instead of waiting out the backoff', () {
    fakeAsync((fake) {
      final (:channel, :opens) = droppingChannel();
      channel.start();
      fake.flushMicrotasks();
      expect(opens(), 1);
      expect(channel.isConnected, isFalse);

      // Well inside the 5 s backoff: only the resume can trigger a new connection.
      fake.elapse(const Duration(seconds: 1));
      backgroundThenResume();
      fake.flushMicrotasks();
      expect(opens(), 2);

      channel.dispose();
      fake.flushMicrotasks();
    });
  });

  test('a disposed channel stops reacting to app resume', () {
    fakeAsync((fake) {
      final (:channel, :opens) = droppingChannel();
      channel.start();
      fake.flushMicrotasks();
      channel.dispose();
      fake.flushMicrotasks();

      backgroundThenResume();
      fake.flushMicrotasks();
      expect(opens(), 1);
    });
  });
}
