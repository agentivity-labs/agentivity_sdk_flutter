import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentivity_sdk/agentivity_sdk.dart';

// Regression coverage for a second real bug in the same family as ag_artifacts_theme_test.dart:
// AgArtifactCard's DefaultTextStyle.merge(fontFamily: ...) covers every plain Text in a card, but
// a Flutter button (ElevatedButton/FilledButton/OutlinedButton) resolves its label's TextStyle
// from its own ButtonStyle, not from an ancestor DefaultTextStyle — confirmed empirically: every
// FilledButton/OutlinedButton submit/confirm/cancel label across the interaction widgets rendered
// in the Material default (Roboto) regardless of the active theme's fontFamily. Fixed by having
// each of these widgets read AgArtifactsThemeData.of(context).fontFamily itself and apply it
// explicitly to its button labels. Pinned here, per widget, so a future edit that reintroduces a
// bare `TextStyle(fontSize: ...)` on one of these buttons is caught immediately.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(MaterialApp(
        // The raw `ThemeData(...).copyWith(extensions: [...])` pattern — the one that silently
        // dropped fontFamily before ag_artifacts_theme_test.dart's fix, so it's also the
        // strictest check here: nothing but this widget's own explicit style can be responsible.
        theme: ThemeData.light(useMaterial3: true).copyWith(extensions: [AgArtifactsThemes.techno]),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ));

  String? renderedFontFamily(WidgetTester tester, String text) {
    final span = tester.renderObject<RenderParagraph>(find.text(text)).text as TextSpan;
    return span.style?.fontFamily;
  }

  testWidgets('AgChoiceCard submit button', (tester) async {
    await pump(tester, AgChoiceCard(props: {
      'options': [
        {'id': 'a', 'label': 'A'},
      ],
      'submitLabel': 'Go',
    }));
    expect(renderedFontFamily(tester, 'Go'), 'JetBrains Mono');
  });

  testWidgets('AgConfirmCard confirm and cancel buttons', (tester) async {
    await pump(tester, AgConfirmCard(props: {'message': 'm', 'confirmLabel': 'Yes', 'cancelLabel': 'No'}));
    expect(renderedFontFamily(tester, 'Yes'), 'JetBrains Mono');
    expect(renderedFontFamily(tester, 'No'), 'JetBrains Mono');
  });

  testWidgets('AgDatePickerCard submit button', (tester) async {
    await pump(tester, AgDatePickerCard(props: {'submitLabel': 'Pick'}));
    expect(renderedFontFamily(tester, 'Pick'), 'JetBrains Mono');
  });

  testWidgets('AgRatingCard submit button', (tester) async {
    await pump(tester, AgRatingCard(props: {'submitLabel': 'Rate'}));
    expect(renderedFontFamily(tester, 'Rate'), 'JetBrains Mono');
  });

  testWidgets('AgQuestionForm submit button and boolean Yes/No options', (tester) async {
    await pump(
      tester,
      AgQuestionForm(props: {
        'questions': [
          {'id': 'b', 'label': 'B', 'type': 'boolean'},
        ],
        'submitLabel': 'Send',
      }),
    );
    expect(renderedFontFamily(tester, 'Send'), 'JetBrains Mono');
    expect(renderedFontFamily(tester, 'Yes'), 'JetBrains Mono');
  });

  testWidgets('AgQuestionForm text/date/number TextFields (do not inherit DefaultTextStyle either)', (tester) async {
    await pump(
      tester,
      AgQuestionForm(props: {
        'questions': [
          {'id': 't', 'label': 'T'},
        ],
      }),
    );
    final field = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(field.style.fontFamily, 'JetBrains Mono');
  });
}
