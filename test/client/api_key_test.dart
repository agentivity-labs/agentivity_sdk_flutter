import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// On an instance that asks to sign in, a program gives the key a person made for it: the client sends it with every request.
void main() {
  test('a client given a key sends it with every request', () {
    final client = AgentivityClient(baseUrl: 'https://instance.example.com', apiKey: ' agv_0a1b2c3d4e5f_secret ');

    expect(client.http.dio.options.headers['Authorization'], 'Bearer agv_0a1b2c3d4e5f_secret');
  });

  test('the platform client given a key sends it too', () {
    final client = AgentivityPlatformClient(baseUrl: 'https://instance.example.com', apiKey: 'agv_0a1b2c3d4e5f_secret');

    expect(client.http.dio.options.headers['Authorization'], 'Bearer agv_0a1b2c3d4e5f_secret');
  });

  test('a client without a key sends none', () {
    final client = AgentivityClient(baseUrl: 'http://localhost:5005');

    expect(client.http.dio.options.headers.containsKey('Authorization'), isFalse);
  });
}
