import 'package:flutter_test/flutter_test.dart';

import 'package:agentivity_artifacts_showcase/main.dart';

void main() {
  testWidgets('ShowcaseApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ShowcaseApp());
    await tester.pumpAndSettle();

    expect(find.text('Artifact Demos'), findsOneWidget);
  });
}
