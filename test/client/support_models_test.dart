import 'dart:convert';
import 'dart:typed_data';

import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a request says where it stands as the person reads it', () {
    SupportTicket of(String status, {bool answered = false}) =>
        SupportTicket.fromJson({'number': 1042, 'subject': 'It stops', 'kind': 'bug', 'severity': 'blocking', 'status': status, 'answered': answered, 'targetDays': 1});

    expect(of('waiting_us').state, SupportState.sent);
    expect(of('waiting_us', answered: true).state, SupportState.inProgress);
    expect(of('waiting_customer', answered: true).state, SupportState.waitingForYou);
    expect(of('resolved').state, SupportState.resolved);
    expect(of('closed').open, isFalse);
    expect(of('waiting_us').reference, 'SUP-1042');
    expect(of('waiting_us').severity, SupportSeverity.blocking);
    expect(of('waiting_us').targetDays, 1);
  });

  test('a thread holds the messages of the person and of the support, with their files', () {
    final thread = SupportThread.fromJson({
      'ticket': {'number': 1043, 'reference': 'SUP-1043', 'subject': 'Billing', 'kind': 'billing', 'status': 'waiting_customer', 'answered': true},
      'messages': [
        {'messageId': 'm1', 'author': 'customer', 'authorName': 'Sam', 'body': 'Why two invoices?', 'files': [
          {'attachmentId': 'f1', 'name': 'invoice.png', 'contentType': 'image/png', 'size': 1200},
        ]},
        {'messageId': 'm2', 'author': 'support', 'authorName': 'Krys', 'body': 'One is for the seats.'},
      ],
    });

    expect(thread.ticket.kind, SupportKind.billing);
    expect(thread.messages.first.files.single.image, isTrue);
    expect(thread.messages.last.fromSupport, isTrue);
  });

  test('a file joined goes as base64, with its name and type', () {
    final json = SupportUpload(name: 'log.txt', contentType: 'text/plain', bytes: Uint8List.fromList(utf8.encode('hello'))).toJson();
    expect(json['data'], base64Encode(utf8.encode('hello')));
    expect(json['name'], 'log.txt');
  });

  test('a workspace not hosted by Agentivity has no support, and says where to find help', () {
    final none = SupportAvailability.fromJson({'available': false, 'community': 'https://github.com/x/discussions'});
    expect(none.available, isFalse);
    expect(none.community, startsWith('https://'));
  });
}
