import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AgArtifactLinks.instanceBaseUrl = null;
    AgArtifactLinks.onOpen = null;
  });

  test('a picture the instance keeps is read from it once it is known, and only then', () {
    expect(agSafeImageUrl('/api/v1/resources/abc'), isNull);
    AgArtifactLinks.instanceBaseUrl = 'https://my.agentivity.app/';
    expect(agSafeImageUrl('/api/v1/resources/abc'), 'https://my.agentivity.app/api/v1/resources/abc');
    expect(agSafeImageUrl('/etc/passwd'), isNull);
  });

  test('it is saved as a download, an image elsewhere is opened', () {
    expect(AgArtifactLinks.downloadUrl('https://my.agentivity.app/api/v1/resources/abc'), 'https://my.agentivity.app/api/v1/resources/abc?download=true');
    expect(AgArtifactLinks.downloadUrl('https://img.recraft.ai/a.png'), 'https://img.recraft.ai/a.png');
  });

  testWidgets('the gallery has a Download button for a picture that says how to save it', (tester) async {
    AgArtifactLinks.instanceBaseUrl = 'https://my.agentivity.app';
    Uri? opened;
    AgArtifactLinks.onOpen = (uri) => opened = uri;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AgImageGallery(props: const {
            'images': [
              {'url': '/api/v1/resources/abc', 'download': 'abc.png'},
              {'url': 'https://x.test/b.png'},
            ],
          }),
        ),
      ),
    ));

    expect(find.text('Download'), findsOneWidget);
    await tester.tap(find.text('Download'));
    expect(opened.toString(), 'https://my.agentivity.app/api/v1/resources/abc?download=true');
  });
}
