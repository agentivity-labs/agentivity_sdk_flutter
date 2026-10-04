import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// A 1×1 PNG, so a picture can be shown without any network.
const _photo =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  tearDown(() => AgArtifactLinks.onOpen = null);

  group('image addresses coming from an agent', () {
    test('accepts http(s) and raster data images only', () {
      expect(agSafeImageUrl('https://i5.walmartimages.com/p.jpeg'), isNotNull);
      expect(agSafeImageUrl(_photo), isNotNull);
      expect(agSafeImageUrl('javascript:alert(1)'), isNull);
      expect(agSafeImageUrl('data:image/svg+xml;base64,AAAA'), isNull);
      expect(agSafeImageUrl('/relative/photo.jpg'), isNull);
      expect(agSafeImageUrl(42), isNull);
      expect(agSafeHttpUrl('javascript:alert(1)'), isNull);
      expect(agSafeHttpUrl('https://shop.example/p/1'), 'https://shop.example/p/1');
    });
  });

  group('AgArtifactImage', () {
    testWidgets('shows the picture', (tester) async {
      await tester.pumpWidget(_wrap(const AgArtifactImage(src: _photo, alt: 'Roomba')));
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows the initial of the description when the address is missing or unsafe', (tester) async {
      await tester.pumpWidget(_wrap(const Column(children: [
        AgArtifactImage(alt: 'Roomba'),
        AgArtifactImage(src: 'javascript:alert(1)', alt: 'Dreame'),
      ])));
      expect(find.byType(Image), findsNothing);
      expect(find.text('R'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('shows the placeholder for bytes that are not a picture, instead of a broken image', (tester) async {
      await tester.pumpWidget(_wrap(const AgArtifactImage(src: 'data:image/png;base64,@@@', alt: 'Roomba')));
      expect(find.byType(Image), findsNothing);
      expect(find.text('R'), findsOneWidget);
    });
  });

  group('AgSummaryCard pictures', () {
    final sections = [
      {
        'label': 'Roomba Combo',
        'badge': 'Best overall',
        'imageUrl': _photo,
        'url': 'https://shop.example/roomba',
        'items': [
          {'key': 'Price', 'value': '\$499', 'highlight': true},
        ],
      },
      {
        'label': 'Dreame X60',
        'items': [
          {'key': 'Price', 'value': '\$699'},
        ],
      },
    ];

    testWidgets('shows a product sheet: photo, badge and the facts', (tester) async {
      await tester.pumpWidget(_wrap(AgSummaryCard(props: {'title': 'Top picks', 'sections': sections})));
      expect(find.byType(Image), findsOneWidget); // only the first section has a picture
      expect(find.text('Best overall'), findsOneWidget);
      expect(find.text('ROOMBA COMBO'), findsOneWidget);
      expect(find.text('\$699'), findsOneWidget);
    });

    testWidgets('a section with a link opens it through the app-provided handler', (tester) async {
      Uri? opened;
      AgArtifactLinks.onOpen = (uri) => opened = uri;
      await tester.pumpWidget(_wrap(AgSummaryCard(props: {'title': 'Top picks', 'sections': sections})));

      await tester.tap(find.text('ROOMBA COMBO'));
      expect(opened, Uri.parse('https://shop.example/roomba'));
    });

    testWidgets('without a handler a tap copies the link', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(_wrap(AgSummaryCard(props: {'title': 'Top picks', 'sections': sections})));
      await tester.tap(find.text('ROOMBA COMBO'));
      await tester.pump();
      expect(copied, 'https://shop.example/roomba');
    });

    testWidgets('shows a banner picture on the card itself', (tester) async {
      await tester.pumpWidget(_wrap(AgSummaryCard(props: {
        'title': 'Trip',
        'imageUrl': _photo,
        'sections': [
          {'items': [{'key': 'Days', 'value': '5'}]},
        ],
      })));
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('keeps working without any picture and ignores an unsafe link', (tester) async {
      AgArtifactLinks.onOpen = (_) => fail('an unsafe link must never be opened');
      await tester.pumpWidget(_wrap(const AgSummaryCard(props: {
        'title': 'Recap',
        'sections': [
          {'label': 'Plain', 'url': 'javascript:alert(1)', 'items': [{'key': 'A', 'value': '1'}]},
        ],
      })));
      expect(find.byType(Image), findsNothing);
      await tester.tap(find.text('PLAIN'));
    });
  });

  group('AgChoiceCard option pictures', () {
    testWidgets('shows a picture next to an option that has one', (tester) async {
      await tester.pumpWidget(_wrap(const AgChoiceCard(props: {
        'title': 'Pick',
        'options': [
          {'id': 'a', 'label': 'Option A', 'imageUrl': _photo},
          {'id': 'b', 'label': 'Option B'},
        ],
      })));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
    });
  });

  group('AgImageGallery', () {
    testWidgets('shows each picture with its caption and keeps a place for one that cannot be shown', (tester) async {
      await tester.pumpWidget(_wrap(const AgImageGallery(props: {
        'title': 'Candidates',
        'images': [
          {'url': _photo, 'alt': 'First', 'caption': 'First caption'},
          {'url': 'ftp://nope', 'alt': 'Second', 'caption': 'Second caption'},
        ],
      })));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('First caption'), findsOneWidget);
      expect(find.text('Second caption'), findsOneWidget);
      expect(find.text('S'), findsOneWidget); // the placeholder of the picture that cannot be shown
    });

    test('is registered under its name', () {
      expect(buildArtifactsRegistry().containsKey('ImageGallery'), isTrue);
    });
  });

  group('AgUiMarkdownBody images', () {
    testWidgets('renders nothing for an address that is not http(s)', (tester) async {
      await tester.pumpWidget(_wrap(const AgUiMarkdownBody(data: 'Before ![x](javascript:alert(1)) after')));
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('constrains a message image to the bubble', (tester) async {
      await tester.pumpWidget(_wrap(const SizedBox(width: 280, child: AgUiMarkdownBody(data: '![Roomba](https://shop.example/roomba.jpg)'))));
      final image = find.byType(Image);
      expect(image, findsOneWidget);
      expect(tester.getSize(find.byType(AgUiMarkdownBody)).width, lessThanOrEqualTo(280));
    });
  });
}
