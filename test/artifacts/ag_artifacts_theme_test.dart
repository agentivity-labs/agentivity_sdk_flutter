import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentivity_sdk/agentivity_sdk.dart';

// Regression coverage for a real bug: AgArtifactsThemeData.fontFamily was added to the class and
// wired into AgArtifactsThemes.themeDataFor, but no artifact widget actually read it — it worked
// by accident only when an app happened to build its ThemeData via themeDataFor (which sets the
// ambient TextTheme, and Flutter's own Text/DefaultTextStyle merge did the rest), and silently did
// nothing for the class's own first documented usage pattern (a plain
// `ThemeData(...).copyWith(extensions: [...])`). Fixed by having AgArtifactCard apply
// t.fontFamily directly via DefaultTextStyle.merge, so it holds regardless of how the theme was
// registered — these tests pin both registration paths so a future refactor can't silently drop
// either one again.
void main() {
  group('AgArtifactCard applies AgArtifactsThemeData.fontFamily', () {
    testWidgets('via AgArtifactsThemes.themeDataFor', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AgArtifactsThemes.themeDataFor('Techno'),
        home: const Scaffold(body: AgArtifactCard(title: 'Title', child: Text('Content'))),
      ));

      expect(_renderedFontFamily(tester, 'Title'), 'JetBrains Mono');
      expect(_renderedFontFamily(tester, 'Content'), 'JetBrains Mono');
    });

    testWidgets('via a plain ThemeData(...).copyWith(extensions: [...]) — no themeDataFor', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light(useMaterial3: true).copyWith(extensions: [AgArtifactsThemes.techno]),
        home: const Scaffold(body: AgArtifactCard(title: 'Title', child: Text('Content'))),
      ));

      expect(_renderedFontFamily(tester, 'Title'), 'JetBrains Mono');
      expect(_renderedFontFamily(tester, 'Content'), 'JetBrains Mono');
    });

    testWidgets('a preset with no fontFamily never forces one', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light(useMaterial3: true).copyWith(extensions: [AgArtifactsThemes.neutral]),
        home: const Scaffold(body: AgArtifactCard(title: 'Title', child: Text('Content'))),
      ));

      // Falls through to Material's own default (Roboto) rather than some hardcoded family.
      expect(_renderedFontFamily(tester, 'Title'), 'Roboto');
    });
  });
}

String? _renderedFontFamily(WidgetTester tester, String text) {
  final span = tester.renderObject<RenderParagraph>(find.text(text)).text as TextSpan;
  return span.style?.fontFamily;
}
