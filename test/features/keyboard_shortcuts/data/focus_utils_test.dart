import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/focus_utils.dart';

void main() {
  testWidgets('true when an editable TextField holds focus',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TextField(autofocus: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(isTextInputFocused(), isTrue);
  });

  testWidgets('false when a read-only SelectableText holds focus',
      (WidgetTester tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectableText('小説本文', focusNode: focusNode),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue);
    expect(isTextInputFocused(), isFalse,
        reason: 'SelectableText is read-only; not a text input field');
  });

  testWidgets('false when nothing is focused', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pumpAndSettle();
    expect(isTextInputFocused(), isFalse);
  });
}
