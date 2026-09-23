import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/http_core.dart';

/// Server-side voice transcription — the chat input's mic records audio and
/// uploads it here rather than running an on-device speech engine.
///
/// Deliberately OpenAI Whisper only, credential-gated: [checkStatus] tells the
/// caller upfront whether transcription is even configured, so a UI can hide
/// or disable the mic instead of discovering unavailability via a failed
/// upload.
class VoiceApi {
  VoiceApi(this._c);
  final AgentivityHttpCore _c;

  /// Whether the platform has a speech-to-text credential configured.
  Future<bool> checkStatus() async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/voice/status'));
    return (response.data ?? const <String, dynamic>{})['available'] == true;
  }

  /// Uploads [audioBytes] (e.g. a WAV file) for transcription.
  /// Returns the transcribed text, or throws [ApiException] on failure
  /// (including `stt_not_configured` if no credential is set).
  Future<String> transcribe(Uint8List audioBytes, String mimeType, {String? language}) async {
    final extension = mimeType.split('/').last;
    final formData = FormData.fromMap({
      'audio': MultipartFile.fromBytes(audioBytes, filename: 'audio.$extension', contentType: DioMediaType.parse(mimeType)),
      if (language != null && language.trim().isNotEmpty) 'language': language.trim(),
    });
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/voice/transcribe'),
      data: formData,
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    return (response.data ?? const <String, dynamic>{})['text'] as String? ?? '';
  }
}
