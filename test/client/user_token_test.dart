import 'dart:convert';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers as [answer] says, and keeps what each request was sent with.
class _Instance implements HttpClientAdapter {
  _Instance(this.answer);

  final ResponseBody Function(RequestOptions options) answer;
  final List<RequestOptions> asked = [];

  String? authorizationOf(int call) => asked[call].headers['Authorization'] as String?;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    asked.add(options);
    return answer(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {'content-type': ['application/json']});

DateTime _inMinutes(double minutes) => DateTime.now().add(Duration(milliseconds: (minutes * 60000).round()));

AgentivityClient _client(_Instance instance, {String? apiKey}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://instance.example.com/', headers: {if (apiKey != null) 'Authorization': 'Bearer $apiKey'}))..httpClientAdapter = instance;
  return AgentivityClient(dio: dio, baseUrl: 'https://instance.example.com/');
}

/// An app speaks for its user: each has their own conversations, with a token worth a few minutes.
void main() {
  demoVisitors();

  test('sends their token rather than the key', () async {
    final instance = _Instance((_) => _json([]));
    final client = _client(instance, apiKey: 'agv_server')..setUserToken(UserToken('agu_alice', expiresAt: _inMinutes(15)));

    await client.http.get<dynamic>('/api/v1/executions');

    expect(instance.authorizationOf(0), 'Bearer agu_alice');
    expect(client.http.dio.options.headers['Authorization'], 'Bearer agu_alice', reason: 'a stream on the web reads the headers of the client');
  });

  test('asks for a token at the first request, and for the next one before the end of the last', () async {
    final instance = _Instance((_) => _json([]));
    final given = [UserToken('agu_first', expiresAt: _inMinutes(0.5)), UserToken('agu_second', expiresAt: _inMinutes(15))];
    var asked = 0;
    final client = _client(instance)..setUserToken(null, renew: () async => given[asked++]);

    for (var i = 0; i < 3; i++) {
      await client.http.get<dynamic>('/api/v1/executions');
    }

    expect(asked, 2);
    expect([instance.authorizationOf(0), instance.authorizationOf(1), instance.authorizationOf(2)], ['Bearer agu_first', 'Bearer agu_second', 'Bearer agu_second']);
  });

  test('asks for a new one when the instance refuses it, and sends the request once more', () async {
    var refused = false;
    final instance = _Instance((_) {
      if (refused) return _json([]);
      refused = true;
      return _json({'error': 'invalid_user_token', 'message': 'No longer worth anything.'}, 401);
    });
    var asked = 0;
    final client = _client(instance)..setUserToken(const UserToken('agu_old'), renew: () async {
      asked++;
      return const UserToken('agu_next');
    });

    final response = await client.http.get<dynamic>('/api/v1/executions');

    expect(response.statusCode, 200);
    expect(asked, 1);
    expect([instance.authorizationOf(0), instance.authorizationOf(1)], ['Bearer agu_old', 'Bearer agu_next']);
  });

  test('a person signed in through the App: renewed with the token they have, then signed out', () async {
    final instance = _Instance((options) {
      if (options.path.endsWith('/sign-in')) {
        return _json({'token': 'agu_alice', 'expiresAt': _inMinutes(0.5).toUtc().toIso8601String(), 'user': {'id': 'u1', 'name': 'Alice', 'email': 'alice@example.test'}});
      }
      if (options.path.endsWith('/user-tokens/renew')) return _json({'token': 'agu_alice_2', 'expiresAt': _inMinutes(15).toUtc().toIso8601String()});
      return options.path.endsWith('/sign-out') ? ResponseBody.fromString('', 204) : _json([]);
    });
    final client = _client(instance);

    final signedIn = await client.apps.signIn(appId: 'hr', email: 'alice@example.test', password: 'secret');
    await client.http.get<dynamic>('/api/v1/executions');
    await client.apps.signOut('hr');
    await client.http.get<dynamic>('/api/v1/executions');

    expect(signedIn.name, 'Alice');
    expect(instance.asked[1].path, contains('/api/v1/apps/hr/user-tokens/renew'));
    expect(instance.authorizationOf(1), 'Bearer agu_alice');
    expect(instance.authorizationOf(2), 'Bearer agu_alice_2');
    expect(instance.asked[3].path, contains('/api/v1/apps/hr/sign-out'));
    expect(instance.authorizationOf(3), 'Bearer agu_alice_2');
    expect(instance.authorizationOf(4), isNull);
  });
}

class _Kept implements VisitorStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void demoVisitors() {
  test('a visitor of a demo is asked once, then kept for the next visit', () async {
    var given = 0;
    final instance = _Instance((options) => options.path.endsWith('/visitors')
        ? _json({'token': 'agu_visitor_${++given}', 'expiresAt': _inMinutes(60 * 24 * 7).toUtc().toIso8601String()})
        : _json([]));
    final kept = _Kept();

    final first = _client(instance)..apps.visitDemo('demo', store: kept);
    await first.http.get<dynamic>('/api/v1/executions');
    final again = _client(instance)..apps.visitDemo('demo', store: kept);
    await again.http.get<dynamic>('/api/v1/executions');

    expect(given, 1);
    expect(instance.asked[0].path, contains('/api/v1/apps/demo/visitors'));
    expect(instance.authorizationOf(1), 'Bearer agu_visitor_1');
    expect(instance.authorizationOf(2), 'Bearer agu_visitor_1');
  });
}
