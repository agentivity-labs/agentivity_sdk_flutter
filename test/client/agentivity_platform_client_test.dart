import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('AgentivityPlatformClient', () {
    test('constructs with the base client APIs and the SDK extras wired', () {
      final client = AgentivityPlatformClient(baseUrl: 'http://localhost:5005');

      // Base AgentivityClient surface.
      expect(client.entities, isNotNull);
      expect(client.runs, isNotNull);
      expect(client.conversations, isNotNull);
      expect(client.agenticFolders, isNotNull);

      // SDK extras (chat, AG-UI bundles, icons) — read/execute/history only.
      expect(client.chat, isNotNull);
      expect(client.agUiBundles, isNotNull);
      expect(client.svgIcons, isNotNull);
    });
  });

  group('ApiErrorPayload', () {
    test('parses a standard {error:{code,message}} envelope', () {
      final payload = ApiErrorPayload.tryParse({
        'error': {'code': 'not_found', 'message': 'Agent not found'},
      }, httpStatus: 404);

      expect(payload, isNotNull);
      expect(payload!.code, 'not_found');
      expect(payload.resolvedUserMessage, 'Agent not found');
      expect(payload.isFailureStatus, isTrue);
    });

    test('falls back to a generic message for a bare HTTP status', () {
      final payload = ApiErrorPayload(httpStatus: 500);
      expect(payload.resolvedUserMessage, 'The server is currently unavailable or encountered an error.');
    });
  });
}
