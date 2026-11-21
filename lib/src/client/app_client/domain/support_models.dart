import 'dart:convert';

import 'package:flutter/foundation.dart';

// The support of Agentivity, as a person of a hosted workspace sees it: whether there is one, their requests, a request's thread
// and its files. Ops' internal notes never reach them.

String? _text(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _date(dynamic raw) => raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();

Map<String, dynamic> _map(dynamic raw) => raw is Map<String, dynamic> ? raw : raw is Map ? Map<String, dynamic>.from(raw) : const {};

List<Map<String, dynamic>> _maps(dynamic raw) => raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false) : const [];

/// Whether this workspace has the support of Agentivity (a hosted one); without it (Community), where to find help.
@immutable
class SupportAvailability {
  const SupportAvailability({required this.available, this.community, this.docs});

  final bool available;
  final String? community;
  final String? docs;

  factory SupportAvailability.fromJson(Map<String, dynamic> json) =>
      SupportAvailability(available: json['available'] == true, community: _text(json['community']), docs: _text(json['docs']));
}

/// What a request is about.
enum SupportKind { question, bug, billing, other }

/// How much a problem gets in the way.
enum SupportSeverity { blocking, annoying, minor }

/// Where a request stands, as the person reads it.
enum SupportState {
  /// Sent, nobody answered yet.
  sent,

  /// The support works on it.
  inProgress,

  /// The support waits for the person's reply.
  waitingForYou,
  resolved,
  closed,
}

/// A request to the support.
@immutable
class SupportTicket {
  const SupportTicket({
    required this.number,
    required this.reference,
    required this.subject,
    required this.kind,
    this.severity,
    required this.status,
    required this.answered,
    required this.targetDays,
    this.createdAt,
    this.updatedAt,
    this.firstResponseAt,
    this.resolvedAt,
    this.closedAt,
    this.rating,
  });

  final int number;

  /// "SUP-1042".
  final String reference;
  final String subject;
  final SupportKind kind;
  final SupportSeverity? severity;

  /// waiting_us, waiting_customer, resolved, closed.
  final String status;

  /// The support answered at least once.
  final bool answered;

  /// The target of a first answer, in working days (a target, never a promise).
  final int targetDays;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? firstResponseAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;

  /// good or bad, once said.
  final String? rating;

  SupportState get state => switch (status) {
        'waiting_customer' => SupportState.waitingForYou,
        'resolved' => SupportState.resolved,
        'closed' => SupportState.closed,
        _ => answered ? SupportState.inProgress : SupportState.sent,
      };

  bool get open => state != SupportState.resolved && state != SupportState.closed;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        number: (json['number'] as num?)?.toInt() ?? 0,
        reference: _text(json['reference']) ?? 'SUP-${json['number']}',
        subject: _text(json['subject']) ?? '',
        kind: SupportKind.values.firstWhere((k) => k.name == json['kind'], orElse: () => SupportKind.question),
        severity: SupportSeverity.values.where((s) => s.name == json['severity']).firstOrNull,
        status: _text(json['status']) ?? 'waiting_us',
        answered: json['answered'] == true,
        targetDays: (json['targetDays'] as num?)?.toInt() ?? 2,
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
        firstResponseAt: _date(json['firstResponseAt']),
        resolvedAt: _date(json['resolvedAt']),
        closedAt: _date(json['closedAt']),
        rating: _text(json['rating']),
      );
}

/// A file of a request's thread, without its content.
@immutable
class SupportFileInfo {
  const SupportFileInfo({required this.attachmentId, required this.name, required this.contentType, required this.size});

  final String attachmentId;
  final String name;
  final String contentType;
  final int size;

  bool get image => contentType.startsWith('image/');

  factory SupportFileInfo.fromJson(Map<String, dynamic> json) => SupportFileInfo(
        attachmentId: _text(json['attachmentId']) ?? '',
        name: _text(json['name']) ?? 'file',
        contentType: _text(json['contentType']) ?? 'application/octet-stream',
        size: (json['size'] as num?)?.toInt() ?? 0,
      );
}

/// A message of a request's thread: the person's, the support's, or what the system says (resolved, reopened, closed).
@immutable
class SupportMessage {
  const SupportMessage({required this.messageId, required this.author, required this.authorName, required this.body, this.createdAt, this.files = const []});

  final String messageId;

  /// customer, support, system.
  final String author;
  final String authorName;
  final String body;
  final DateTime? createdAt;
  final List<SupportFileInfo> files;

  bool get fromSupport => author == 'support' || author == 'operator';
  bool get fromSystem => author == 'system';

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        messageId: _text(json['messageId']) ?? '',
        author: _text(json['author']) ?? 'customer',
        authorName: _text(json['authorName']) ?? '',
        body: _text(json['body']) ?? '',
        createdAt: _date(json['createdAt']),
        files: _maps(json['files']).map(SupportFileInfo.fromJson).toList(growable: false),
      );
}

/// A request and its thread.
@immutable
class SupportThread {
  const SupportThread({required this.ticket, required this.messages});

  final SupportTicket ticket;
  final List<SupportMessage> messages;

  factory SupportThread.fromJson(Map<String, dynamic> json) => SupportThread(
        ticket: SupportTicket.fromJson(_map(json['ticket'])),
        messages: _maps(json['messages']).map(SupportMessage.fromJson).toList(growable: false),
      );
}

/// A file joined to a message: 5 at most, 5 MB each.
@immutable
class SupportUpload {
  const SupportUpload({required this.name, required this.bytes, this.contentType});

  static const sizeMost = 5 * 1024 * 1024;
  static const perMessageMost = 5;

  final String name;
  final Uint8List bytes;
  final String? contentType;

  Map<String, dynamic> toJson() => {'name': name, 'contentType': contentType, 'data': base64Encode(bytes)};
}
