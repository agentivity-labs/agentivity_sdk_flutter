import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatController _controller() {
  final controller = ChatController.fromStream(events: const Stream<AgUiEvent>.empty());
  controller.addThread(ChatThread.fromJson({'id': 't1', 'contextId': 'c', 'runId': 'r', 'title': 'Thread', 'isDefault': true, 'status': 'active'}));
  return controller;
}

ChatMessage _widgetMessage(String id, String type) => ChatMessage(
      id: id,
      role: ChatMessageRole.assistant,
      contextId: 'c',
      threadId: 't1',
      runId: 'r',
      text: '',
      metadata: {'widgetType': type, 'widgetProps': <String, dynamic>{}},
    );

/// A registry with one component that asks (a hotel choice) and one that only shows (a trip cover).
AgUiWidgetRegistry _registry() => AgUiWidgetRegistry(
      {
        'HotelChoice': (context, props) => TextButton(
              onPressed: () => (props['__onSubmit'] as void Function(String)?)?.call('Alfama'),
              child: const Text('choose'),
            ),
        'TripCover': (context, props) => const Text('cover'),
      },
      displayComponents: {'TripCover'},
    );

Future<void> _pump(WidgetTester tester, ChatController controller, {Future<void> Function(ChatHilGate, String, String)? onHilResponse}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AgUiChatDiscussion(controller: controller, threadId: 't1', widgetRegistry: _registry(), onHilResponse: onHilResponse),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// The wrapper the chat puts around a rendered component: its opacity and whether it ignores taps.
({double opacity, bool ignoring}) _wrapperOf(WidgetTester tester, String text) {
  final opacity = tester.widget<Opacity>(find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first);
  final pointer = tester.widget<IgnorePointer>(find.ancestor(of: find.text(text), matching: find.byType(IgnorePointer)).first);
  return (opacity: opacity.opacity, ignoring: pointer.ignoring);
}

void main() {
  group('the widget registry', () {
    test('ships the built-in charts, data, media and recap components as display components', () {
      final registry = AgArtifactsBundle.registry();
      for (final name in ['BarChart', 'RadarChart', 'MetricCard', 'KeyValue', 'CodeBlock', 'StatusCard', 'Timeline', 'ImageGallery', 'SummaryCard']) {
        expect(registry.isDisplay(name), isTrue, reason: name);
      }
      for (final name in ['QuestionForm', 'ChoiceCard', 'ConfirmCard', 'RatingCard', 'DatePickerCard', 'SourceInput']) {
        expect(registry.isDisplay(name), isFalse, reason: name);
      }
    });

    test('takes a custom component for one that asks unless it is declared display', () {
      SizedBox build(BuildContext context, Map<String, dynamic> props) => const SizedBox();
      final registry = AgArtifactsBundle.registry(extra: {'TripCover': build, 'HotelChoice': build}, displayComponents: {'TripCover'});
      expect(registry.isDisplay('TripCover'), isTrue);
      expect(registry.isDisplay('HotelChoice'), isFalse);
      expect(registry.isDisplay('BarChart'), isTrue);
    });
  });

  group('a component in the conversation', () {
    testWidgets('that asked something is dimmed and inert once no question is open; a display one never is', (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      controller.addMessage(threadId: 't1', message: _widgetMessage('m1', 'HotelChoice'));
      controller.addMessage(threadId: 't1', message: _widgetMessage('m2', 'TripCover'));

      await _pump(tester, controller);

      expect(_wrapperOf(tester, 'choose'), (opacity: 0.55, ignoring: true));
      expect(_wrapperOf(tester, 'cover'), (opacity: 1.0, ignoring: false));
    });

    testWidgets('keeps the open question answerable when a display component arrives after it', (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      controller.addMessage(threadId: 't1', message: _widgetMessage('m1', 'HotelChoice'));
      controller.setHilGate(const ChatHilGate(requestId: 'req1', threadId: 't1', question: 'Which hotel?', title: 'Hotels'));
      controller.addMessage(threadId: 't1', message: _widgetMessage('m2', 'TripCover'));

      final answers = <String>[];
      await _pump(tester, controller, onHilResponse: (gate, text, source) async => answers.add('${gate.requestId}:$text:$source'));

      expect(_wrapperOf(tester, 'choose'), (opacity: 1.0, ignoring: false));
      expect(_wrapperOf(tester, 'cover'), (opacity: 1.0, ignoring: false));

      await tester.tap(find.text('choose'));
      await tester.pump();
      expect(answers, ['req1:Alfama:widget']);
    });
  });
}
