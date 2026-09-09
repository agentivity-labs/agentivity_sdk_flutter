import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageContentPart', () {
    test('TextContentPart serializes to {type, text}', () {
      expect(const TextContentPart('hello').toJson(), {'type': 'text', 'text': 'hello'});
    });

    test('ImageUrlContentPart serializes to OpenAI image_url shape', () {
      const part = ImageUrlContentPart(url: 'https://example.com/cat.png', detail: 'high');
      expect(part.toJson(), {
        'type': 'image_url',
        'image_url': {'url': 'https://example.com/cat.png', 'detail': 'high'},
      });
    });

    test('ImageUrlContentPart omits detail when absent', () {
      const part = ImageUrlContentPart(url: 'data:image/png;base64,abc123');
      expect(part.toJson(), {
        'type': 'image_url',
        'image_url': {'url': 'data:image/png;base64,abc123'},
      });
    });

    test('InputAudioContentPart serializes to OpenAI input_audio shape', () {
      const part = InputAudioContentPart(data: 'YmFzZTY0', format: 'wav');
      expect(part.toJson(), {
        'type': 'input_audio',
        'input_audio': {'data': 'YmFzZTY0', 'format': 'wav'},
      });
    });

    test('OutputAudioContentPart with a URL', () {
      const part = OutputAudioContentPart(url: '/api/v1/resources/abc', transcript: 'Hello there');
      expect(part.toJson(), {
        'type': 'output_audio',
        'output_audio': {'url': '/api/v1/resources/abc', 'transcript': 'Hello there'},
      });
    });

    test('OutputAudioContentPart with inline base64 data', () {
      const part = OutputAudioContentPart(data: 'YmFzZTY0', format: 'mp3');
      expect(part.toJson(), {
        'type': 'output_audio',
        'output_audio': {'data': 'YmFzZTY0', 'format': 'mp3'},
      });
    });

    test('OutputAudioContentPart requires url or data', () {
      expect(() => OutputAudioContentPart(url: null, data: null), throwsA(isA<AssertionError>()));
    });

    test('FileContentPart serializes to file shape', () {
      const part = FileContentPart(fileId: 'file-1', mimeType: 'application/pdf', name: 'report.pdf');
      expect(part.toJson(), {
        'type': 'file',
        'file': {'file_id': 'file-1', 'mime_type': 'application/pdf', 'name': 'report.pdf'},
      });
    });
  });

  group('buildAgUiMessage', () {
    test('plain text message has a string content field', () {
      expect(buildAgUiMessage('user', text: 'hi'), {'role': 'user', 'content': 'hi'});
    });

    test('message with parts becomes a content-parts array, text first', () {
      final message = buildAgUiMessage(
        'user',
        text: 'What is in this image?',
        parts: [const ImageUrlContentPart(url: 'https://example.com/cat.png')],
      );
      expect(message, {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'What is in this image?'},
          {
            'type': 'image_url',
            'image_url': {'url': 'https://example.com/cat.png'},
          },
        ],
      });
    });

    test('mixed text, image, and audio parts all ride the same content array', () {
      final message = buildAgUiMessage(
        'user',
        text: 'Compare this photo to what I just said.',
        parts: [
          const ImageUrlContentPart(url: 'https://example.com/cat.png'),
          const InputAudioContentPart(data: 'YmFzZTY0', format: 'wav'),
        ],
      );
      final content = message['content'] as List;
      expect(content, hasLength(3));
      expect(content[0]['type'], 'text');
      expect(content[1]['type'], 'image_url');
      expect(content[2]['type'], 'input_audio');
    });
  });
}
