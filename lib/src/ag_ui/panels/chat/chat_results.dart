import '../../../artifacts/registry.dart';
import 'chat_controller.dart';
import 'chat_models.dart';

/// Something a conversation produced and shows rather than asks: a chart, a table of figures, a report card, an image. What it
/// is called is read from its own values, and failing that from what it is.
class ChatResult {
  const ChatResult({required this.type, required this.props, required this.at});

  final String type;
  final Map<String, dynamic> props;
  final DateTime? at;

  String get title {
    for (final key in const ['title', 'label', 'name', 'heading']) {
      final value = props[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return switch (type) {
      'BarChart' || 'LineChart' || 'PieChart' || 'AreaChart' || 'RadarChart' => 'Chart',
      'StatGrid' || 'MetricCard' => 'Figures',
      'KeyValue' => 'Details',
      'ImageGallery' => 'Images',
      'CodeBlock' || 'JsonViewer' => 'Data',
      'SummaryCard' => 'Summary',
      var other => other,
    };
  }
}

/// What the conversation produced to show, oldest first: from its messages, whether the widget came as its own event (kept in
/// the message's metadata) or in the blocks of a message read back from the workspace. Never what it asks: a card that waits for
/// an answer belongs in the conversation, not beside it.
List<ChatResult> chatResultsOf(ChatController chat) {
  final results = <ChatResult>[];
  for (final thread in chat.threads) {
    for (final message in chat.localMessages(thread.threadId)) {
      final type = message.metadata?['widgetType'];
      if (type is String && artifactDisplayComponents.contains(type)) {
        final props = message.metadata?['widgetProps'];
        results.add(ChatResult(type: type, props: props is Map ? Map<String, dynamic>.from(props) : const {}, at: message.createdAt));
      }
      for (final block in message.blocks ?? const <ChatContentBlock>[]) {
        if (artifactDisplayComponents.contains(block.type)) {
          results.add(ChatResult(type: block.type, props: block.widgetProps ?? const {}, at: message.createdAt));
        }
      }
    }
  }
  results.sort((a, b) => (a.at ?? DateTime(0)).compareTo(b.at ?? DateTime(0)));
  return results;
}
