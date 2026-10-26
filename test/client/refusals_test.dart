import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:agentivity_sdk/src/ag_ui/protocol/api_contract.dart' as panels;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

ApiException _refused(Object? body, int status) => ApiException(payload: ApiErrorPayload.fromDynamic(body, httpStatus: status));

// An opener the instance answers with [status] and [body], as Dio does for a stream request: the body comes as bytes.
AgUiSseOpener _answering(int status, Object body, {required void Function() onCall}) => (path, {lastEventId, cancelToken}) async {
      onCall();
      final options = RequestOptions(path: path, responseType: ResponseType.stream);
      throw DioException.badResponse(
        statusCode: status,
        requestOptions: options,
        response: Response<ResponseBody>(
          requestOptions: options,
          statusCode: status,
          data: ResponseBody(Stream.value(Uint8List.fromList(utf8.encode(jsonEncode(body)))), status),
        ),
      );
    };

void main() {
  group('a refusal of the instance', () {
    test('says its code and its words, from the answers of the identity of the instance', () {
      final refused = _refused({'error': 'permission_denied', 'permission': 'runs.start', 'message': 'Your role does not allow this.'}, 403);

      expect(refused.code, 'permission_denied');
      expect(refused.userMessage, 'Your role does not allow this.');
      expect(refused.permission, 'runs.start');
      expect(refused.kind, ApiFailureKind.forbidden);
      expect(refused.isFinal, isTrue);
    });

    test('says its code and its words, from the answers of the rest of the API', () {
      final refused = _refused({'code': 'credentials_not_found', 'userMessage': 'These credentials could not be found.', 'httpStatus': 404}, 404);

      expect(refused.code, 'credentials_not_found');
      expect(refused.userMessage, 'These credentials could not be found.');
      expect(refused.kind, ApiFailureKind.notFound);
    });

    test('is said in words when the instance gives only its code', () {
      expect(_refused({'error': 'sign_in_required'}, 401).userMessage, contains('give the SDK an API key (agv_'));
      expect(_refused({'error': 'origin_not_allowed'}, 403).userMessage, contains('add it to the sites of the key'));
      expect(_refused({'error': 'sign_in_required'}, 401).kind, ApiFailureKind.key);
    });

    test('is said in words by the AG-UI panels too', () {
      final options = RequestOptions(path: '/api/v1/agents/a1/runs');
      final error = DioException.badResponse(
        statusCode: 401,
        requestOptions: options,
        response: Response<Object>(requestOptions: options, statusCode: 401, data: <String, dynamic>{'error': 'invalid_key'}),
      );

      expect(panels.userFacingErrorMessage(error), contains('The key is not valid'));
      expect(panels.ApiException.fromDio(error).errorCode, 'invalid_key');
    });

    test('is final, but too many calls, a timeout and the server are tried again', () {
      expect(_refused({'error': 'invalid_key'}, 401).isFinal, isTrue);
      expect(_refused({'error': 'too_many_starts'}, 429).isFinal, isFalse);
      expect(_refused(null, 408).isFinal, isFalse);
      expect(_refused(null, 503).isFinal, isFalse);
      final offline = ApiException.fromDio(DioException.connectionError(requestOptions: RequestOptions(path: '/'), reason: 'offline'));
      expect(offline.kind, ApiFailureKind.network);
      expect(offline.isFinal, isFalse);
    });
  });

  group('a stream the instance refuses', () {
    test('stops and says why, instead of reconnecting for ever', () async {
      var calls = 0;
      final channel = AgUiSseChannel<String>(
        opener: _answering(401, {'error': 'invalid_key', 'message': 'The key is not valid.'}, onCall: () => calls++),
        path: '/api/v1/streams/s1',
        parser: (_, __, data) => data,
      );
      final stopped = Completer<AgUiConnectionState>();
      channel.connectionStateNotifier.addListener(() {
        final state = channel.connectionStateNotifier.value;
        if (state.status == AgUiConnectionStatus.terminated && !stopped.isCompleted) stopped.complete(state);
      });

      channel.start();
      final state = await stopped.future.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(calls, 1);
      expect(state.refusal?.code, 'invalid_key');
      expect(state.refusal?.userMessage, 'The key is not valid.');
      expect(channel.isConnected, isFalse);
      await channel.dispose();
    });

    test('is tried again when the server is not there', () async {
      var calls = 0;
      final channel = AgUiSseChannel<String>(
        opener: _answering(503, {}, onCall: () => calls++),
        path: '/api/v1/streams/s1',
        parser: (_, __, data) => data,
      );
      final retrying = Completer<AgUiConnectionState>();
      channel.connectionStateNotifier.addListener(() {
        final state = channel.connectionStateNotifier.value;
        if (state.status == AgUiConnectionStatus.reconnecting && !retrying.isCompleted) retrying.complete(state);
      });

      channel.start();
      final state = await retrying.future.timeout(const Duration(seconds: 5));

      expect(calls, 1);
      expect(state.refusal, isNull);
      await channel.dispose();
    });
  });

  // Dio's own text ("RequestOptions.connectTimeout…") once showed under the message, as its detail: plain words only.
  test('a call that did not get through is said in plain words, without the text of Dio', () {
    final options = RequestOptions(path: '/api/v1/prompts/p1/testcases/execute-all');
    for (final error in [
      DioException.connectionTimeout(requestOptions: options, timeout: const Duration(seconds: 10)),
      DioException.receiveTimeout(requestOptions: options, timeout: const Duration(seconds: 10)),
      DioException.connectionError(requestOptions: options, reason: 'The XMLHttpRequest onError callback was called.'),
    ]) {
      final said = ApiException.fromDio(error);
      expect(said.payload.detail, isNull);
      expect(said.userMessage, isNot(contains('RequestOptions')));
      expect(said.userMessage, isNot(contains('XMLHttpRequest')));
    }
  });
}

