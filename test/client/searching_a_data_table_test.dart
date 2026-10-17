@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reading a Data Table a page at a time: the SDK sends the search (conditions, sort, page) and gives back the rows of the page with
/// the total the platform found — never a page taken for the whole table.
void main() {
  late HttpServer server;
  late List<Uri> calls;
  late String baseUrl;
  String? totalHeader;

  setUp(() async {
    calls = [];
    totalHeader = '250';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      calls.add(request.uri);
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      if (totalHeader != null) request.response.headers.set('X-Total-Count', totalHeader!);
      request.response.write(jsonEncode([
        {'id': 101, 'customer': 'Alice'},
        {'id': 102, 'customer': 'Bob'},
      ]));
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  test('a page comes with the total found', () async {
    final client = AgentivityClient(baseUrl: baseUrl);

    final page = await client.dataTables.fetchDataTableRowsPage(
      'table-1',
      where: [
        {'column': 'amount', 'op': '>', 'value': 10},
      ],
      orderBy: 'amount desc',
      limit: 2,
      offset: 100,
    );

    expect(page.rows.map((r) => r['customer']), ['Alice', 'Bob']);
    expect(page.total, 250);
    expect(page.offset, 100);
    expect(page.hasMore, isTrue);
    final query = calls.single.queryParameters;
    expect(calls.single.path, '/api/v1/datatables/table-1/rows');
    expect(jsonDecode(query['where']!), [
      {'column': 'amount', 'op': '>', 'value': 10},
    ]);
    expect(query['orderBy'], 'amount desc');
    expect(query['limit'], '2');
    expect(query['offset'], '100');
  });

  test('without a search, nothing is sent but the page', () async {
    final client = AgentivityClient(baseUrl: baseUrl);

    await client.dataTables.fetchDataTableRowsPage('table-1', limit: 100);

    expect(calls.single.queryParameters, {'limit': '100'});
  });

  test('a platform that does not say the total: the rows received are the total', () async {
    totalHeader = null;
    final client = AgentivityClient(baseUrl: baseUrl);

    final page = await client.dataTables.fetchDataTableRowsPage('table-1');

    expect(page.total, 2);
    expect(page.hasMore, isFalse);
  });
}
