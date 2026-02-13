import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';

Widget _buildTestWidget({
  required List<TextSegment> segments,
  String? query,
  int? selectionStart,
  int? selectionEnd,
}) {
  return MaterialApp(
    home: Scaffold(
      body: VerticalTextPage(
        segments: segments,
        baseStyle: const TextStyle(fontSize: 14.0),
        query: query,
        selectionStart: selectionStart,
        selectionEnd: selectionEnd,
      ),
    ),
  );
}

void main() {
  group('VerticalTextPage selection highlight', () {
    testWidgets('selected characters have blue background', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいう')],
        selectionStart: 0,
        selectionEnd: 2,
      ));

      final aText = tester.widget<Text>(find.text('あ'));
      final iText = tester.widget<Text>(find.text('い'));
      final uText = tester.widget<Text>(find.text('う'));

      final expectedColor = Colors.blue.withOpacity(0.3);
      expect(aText.style?.backgroundColor, expectedColor);
      expect(iText.style?.backgroundColor, expectedColor);
      expect(uText.style?.backgroundColor, isNull);
    });

    testWidgets('no selection highlight when selection params are null',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいう')],
      ));

      final aText = tester.widget<Text>(find.text('あ'));
      expect(aText.style?.backgroundColor, isNull);
    });

    testWidgets('search highlight takes precedence over selection',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいう')],
        query: 'い',
        selectionStart: 0,
        selectionEnd: 3,
      ));

      final aText = tester.widget<Text>(find.text('あ'));
      final iText = tester.widget<Text>(find.text('い'));
      final uText = tester.widget<Text>(find.text('う'));

      final selectionColor = Colors.blue.withOpacity(0.3);
      // 'あ': selected only → blue
      expect(aText.style?.backgroundColor, selectionColor);
      // 'い': search highlighted + selected → yellow wins
      expect(iText.style?.backgroundColor, Colors.yellow);
      // 'う': selected only → blue
      expect(uText.style?.backgroundColor, selectionColor);
    });
  });
}
