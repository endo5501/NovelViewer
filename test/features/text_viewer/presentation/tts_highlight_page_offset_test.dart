import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';

final _ttsGreen = Colors.green.withValues(alpha: 0.3).toARGB32();

List<Text> _findGreenTexts(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .where((t) =>
          t.style?.backgroundColor != null &&
          t.style!.backgroundColor!.toARGB32() == _ttsGreen)
      .toList();
}

void main() {
  group('VerticalTextPage TTS highlight with pageStartTextOffset', () {
    testWidgets('page 1 (offset 0): highlights correct chars', (tester) async {
      // Page 1 has 'あいうえお', global TTS range 0-3
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: VerticalTextPage(
                segments: [PlainTextSegment('あいうえお')],
                baseStyle: TextStyle(fontSize: 14),
                ttsHighlightStart: 0,
                ttsHighlightEnd: 3,
                pageStartTextOffset: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 'あ', 'い', 'う' should be highlighted
      expect(_findGreenTexts(tester).length, 3);
    });

    testWidgets('page 2 (offset 5): highlights correct chars', (tester) async {
      // Page 2 has 'かきくけこ', page starts at global offset 5
      // Global TTS range 5-8 → page-local 0-3
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: VerticalTextPage(
                segments: [PlainTextSegment('かきくけこ')],
                baseStyle: TextStyle(fontSize: 14),
                ttsHighlightStart: 5,
                ttsHighlightEnd: 8,
                pageStartTextOffset: 5,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 'か', 'き', 'く' should be highlighted
      expect(_findGreenTexts(tester).length, 3);
    });

    testWidgets('out of range: no highlights on this page', (tester) async {
      // Page 2 has 'かきくけこ' starting at offset 5
      // Global TTS range 0-3 is on page 1, not page 2
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: VerticalTextPage(
                segments: [PlainTextSegment('かきくけこ')],
                baseStyle: TextStyle(fontSize: 14),
                ttsHighlightStart: 0,
                ttsHighlightEnd: 3,
                pageStartTextOffset: 5,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No characters should be highlighted (TTS range is on page 1)
      expect(_findGreenTexts(tester), isEmpty);
    });

    testWidgets('with synthetic newlines: skips newlines in offset counting',
        (tester) async {
      // Segments with synthetic newline between columns:
      // 'あいう' + '\n' + 'えおか'
      // The \n is synthetic (from column grouping) and should not count
      // Global TTS range 3-5 should highlight 'え', 'お' (not shifted by \n)
      const segments = [
        PlainTextSegment('あいう'),
        PlainTextSegment('\n'),
        PlainTextSegment('えおか'),
      ];
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: VerticalTextPage(
                segments: segments,
                baseStyle: TextStyle(fontSize: 14),
                ttsHighlightStart: 3,
                ttsHighlightEnd: 5,
                pageStartTextOffset: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 'え', 'お' should be highlighted (2 chars)
      expect(_findGreenTexts(tester).length, 2);
    });
  });
}
