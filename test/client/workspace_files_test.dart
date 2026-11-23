@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// The files of the workspace: several uploaded in one request come back as files, in order; a file is read back as its bytes; a
/// link that opens it for a time is asked for as long as wanted; a file reads as the platform writes it, and back.
void main() {
  late HttpServer server;
  late List<HttpRequest> calls;
  late List<String> bodies;
  late String baseUrl;

  setUp(() async {
    calls = [];
    bodies = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      calls.add(request);
      bodies.add(latin1.decode(await request.fold<List<int>>([], (all, chunk) => all..addAll(chunk))));
      final path = request.uri.path;
      if (path == '/api/v1/uploads') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'files': [
            {'id': 'a' * 32, 'area': 'uploads', 'name': 'kitchen.jpg', 'mime_type': 'image/jpeg', 'size_bytes': 7},
            {'id': 'b' * 32, 'area': 'uploads', 'name': 'report.pdf', 'mime_type': 'application/pdf', 'size_bytes': 4},
          ],
        }));
      } else if (path.endsWith('/link')) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'path': '/api/v1/files/x/content?token=t', 'url': '$baseUrl/api/v1/files/x/content?token=t', 'expiresAt': '2026-11-23T10:00:00Z'}));
      } else {
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add([1, 2, 3]);
      }
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  test('several files are uploaded in one request and come back in order', () async {
    final client = AgentivityClient(baseUrl: baseUrl);

    final files = await client.files.upload([
      FileUpload(name: 'kitchen.jpg', bytes: Uint8List.fromList(utf8.encode('kitchen')), contentType: 'image/jpeg'),
      FileUpload(name: 'report.pdf', bytes: Uint8List.fromList(utf8.encode('%PDF'))),
    ]);

    expect(files.map((f) => f.name), ['kitchen.jpg', 'report.pdf']);
    expect(files.first.isImage, isTrue);
    expect(files.last.isImage, isFalse);
    expect(calls.single.uri.path, '/api/v1/uploads');
    expect('name="files"'.allMatches(bodies.single).length, 2);
    expect(bodies.single, contains('filename="kitchen.jpg"'));
  });

  test('a file is read back as its bytes, and a link is asked for as long as wanted', () async {
    final client = AgentivityClient(baseUrl: baseUrl);

    expect(await client.files.bytes('a' * 32), [1, 2, 3]);
    expect(calls.last.uri.path, '/api/v1/files/${'a' * 32}');

    final link = await client.files.link('x', minutes: 120);
    expect(calls.last.uri.queryParameters['minutes'], '120');
    expect(link.path, '/api/v1/files/x/content?token=t');
    expect(link.expiresAt, DateTime.utc(2026, 11, 23, 10));
  });

  test('a file reads as the platform writes it, and back', () {
    final file = FileRef.fromJson({'id': 'f1', 'area': 'files', 'name': 'report.pdf', 'mime_type': 'application/pdf', 'size_bytes': 12, 'execution_id': 'e1'});

    expect(file.sizeBytes, 12);
    expect(file.executionId, 'e1');
    expect(FileRef.fromJson(file.toJson()), file);
    expect(file.toJson().containsKey('url'), isFalse);
    // An upload as it answered before files: its fileId.
    expect(FileRef.fromJson({'fileId': 'u1', 'name': 'cv.pdf', 'mimeType': 'application/pdf', 'size': 3}).id, 'u1');
  });
}
