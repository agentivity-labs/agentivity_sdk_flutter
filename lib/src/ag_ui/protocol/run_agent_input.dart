// ── Message content parts ─────────────────────────────────────────────────────

/// A single part of a mixed-content message (text, image, or file).
///
/// Use [buildAgUiMessage] to compose a message entry for
/// [RunAgentInput.messages]:
///
/// ```dart
/// buildAgUiMessage('user',
///   text: 'Look at this image',
///   parts: [ImageUrlContentPart(url: 'https://...')],
/// )
/// ```
sealed class MessageContentPart {
  const MessageContentPart();
  Map<String, dynamic> toJson();
}

/// Plain text content part.
final class TextContentPart extends MessageContentPart {
  const TextContentPart(this.text);
  final String text;
  @override
  Map<String, dynamic> toJson() => {'type': 'text', 'text': text};
}

/// Image referenced by URL or data URI (`data:image/jpeg;base64,...`).
final class ImageUrlContentPart extends MessageContentPart {
  const ImageUrlContentPart({required this.url, this.detail});
  final String url;

  /// Resolution hint: `'low'`, `'high'`, or `'auto'` (model-dependent).
  final String? detail;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'image_url',
        'image_url': {
          'url': url,
          if (detail != null) 'detail': detail,
        },
      };
}

/// Audio input, inlined as base64 — mirrors OpenAI Chat Completions' `input_audio`
/// content part shape (`{type: "input_audio", input_audio: {data, format}}`).
///
/// Not currently produced or consumed by anything in this package — this is a
/// protocol-completeness addition so text, images, and audio all travel as content
/// parts on the *same* message channel (no separate upload/transcription endpoint
/// needed for a client that already has the audio bytes, e.g. after on-device
/// speech-to-text is not used and the model itself understands audio natively).
final class InputAudioContentPart extends MessageContentPart {
  const InputAudioContentPart({required this.data, required this.format});

  /// Base64-encoded audio bytes.
  final String data;

  /// `'wav'`, `'mp3'`, or another format the target model accepts.
  final String format;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'input_audio',
        'input_audio': {'data': data, 'format': format},
      };
}

/// A spoken reply, referenced by URL (e.g. from a server-side TTS step) or inlined
/// as base64 — the output-side counterpart to [InputAudioContentPart].
///
/// Lets an assistant message carry its own spoken audio as part of the *same*
/// response instead of a client having to make a second HTTP call to a separate
/// text-to-speech endpoint after receiving the text.
final class OutputAudioContentPart extends MessageContentPart {
  const OutputAudioContentPart({this.url, this.data, this.format, this.transcript}) : assert(url != null || data != null, 'Provide either url or data.');

  /// A fetchable URL for the audio, if the backend already synthesized and cached it.
  final String? url;

  /// Base64-encoded audio bytes, if inlined instead of referenced by URL.
  final String? data;

  /// `'wav'`, `'mp3'`, etc. — required when [data] is set; informational when [url] is set.
  final String? format;

  /// The text that was spoken, for accessibility/fallback rendering.
  final String? transcript;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'output_audio',
        'output_audio': {
          if (url != null) 'url': url,
          if (data != null) 'data': data,
          if (format != null) 'format': format,
          if (transcript != null) 'transcript': transcript,
        },
      };
}

/// File referenced by a backend-assigned file ID.
final class FileContentPart extends MessageContentPart {
  const FileContentPart({required this.fileId, this.mimeType, this.name});
  final String fileId;
  final String? mimeType;
  final String? name;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'file',
        'file': {
          'file_id': fileId,
          if (mimeType != null) 'mime_type': mimeType,
          if (name != null) 'name': name,
        },
      };
}

/// Builds a message entry for [RunAgentInput.messages] supporting mixed content.
///
/// If [parts] are provided, the message `content` field becomes an array;
/// otherwise it is a plain string.
Map<String, dynamic> buildAgUiMessage(
  String role, {
  String? text,
  List<MessageContentPart>? parts,
}) {
  if (parts != null && parts.isNotEmpty) {
    final allParts = [
      if (text != null && text.isNotEmpty) TextContentPart(text),
      ...parts,
    ];
    return {
      'role': role,
      'content': allParts.map((p) => p.toJson()).toList(),
    };
  }
  return {'role': role, 'content': text ?? ''};
}

// ── RunAgentInput ─────────────────────────────────────────────────────────────

/// The payload sent to the backend to start or resume an agent run.
///
/// ```dart
/// final input = RunAgentInput(
///   threadId: 'thread-1',
///   runId: 'run-42',
///   messages: history.map((m) => m.toHistoryEntry()).toList(),
/// );
/// await dio.post('/agent/run', data: input.toJson());
/// ```
///
/// To resume after an [AgUiInterruptOutcome], populate [resume] with one
/// [ResumePayload] per interrupt:
///
/// ```dart
/// final input = RunAgentInput(
///   threadId: 'thread-1',
///   runId: 'run-43',
///   messages: history,
///   resume: [
///     ResumePayload(
///       interruptId: interrupt.id,
///       status: ResumeStatus.resolved,
///       response: {'approved': true},
///     ),
///   ],
/// );
/// ```
class RunAgentInput {
  const RunAgentInput({
    required this.threadId,
    required this.runId,
    this.messages = const [],
    this.tools = const [],
    this.context = const [],
    this.state,
    this.forwardedProps,
    this.resume = const [],
  });

  final String threadId;
  final String runId;

  /// Full conversation history — each entry is a `{role, content}` map.
  final List<Map<String, dynamic>> messages;

  /// Tool definitions available to the agent for this run.
  final List<Map<String, dynamic>> tools;

  /// Arbitrary context entries passed through to the agent.
  final List<dynamic> context;

  /// Agent state carried over from a previous run (e.g. from STATE_SNAPSHOT).
  final dynamic state;

  /// Custom props forwarded verbatim to the backend.
  final Map<String, dynamic>? forwardedProps;

  /// Resume payloads for each open interrupt from the previous run.
  final List<ResumePayload> resume;

  Map<String, dynamic> toJson() => {
        'threadId': threadId,
        'runId': runId,
        'messages': messages,
        if (tools.isNotEmpty) 'tools': tools,
        if (context.isNotEmpty) 'context': context,
        if (state != null) 'state': state,
        if (forwardedProps != null) 'forwardedProps': forwardedProps,
        if (resume.isNotEmpty) 'resume': resume.map((r) => r.toJson()).toList(),
      };
}

/// One resolved or cancelled response to a single [AgUiInterrupt].
class ResumePayload {
  const ResumePayload({
    required this.interruptId,
    required this.status,
    this.response,
  });

  /// The [AgUiInterrupt.id] this payload addresses.
  final String interruptId;
  final ResumeStatus status;

  /// Required when [status] is [ResumeStatus.resolved]; must satisfy the
  /// interrupt's `responseSchema` if one was provided.
  final dynamic response;

  Map<String, dynamic> toJson() => {
        'interruptId': interruptId,
        'status': status.apiValue,
        if (response != null) 'response': response,
      };
}

enum ResumeStatus {
  resolved,
  cancelled;

  String get apiValue => switch (this) {
        ResumeStatus.resolved => 'resolved',
        ResumeStatus.cancelled => 'cancelled',
      };
}
