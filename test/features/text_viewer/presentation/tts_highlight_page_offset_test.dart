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

    testWidgets('column-wrap newline: skips newlines in offset counting',
        (tester) async {
      // Segments with synthetic column-wrap newline between columns:
      // 'あいう' + '\n' + 'えおか'
      // The \n is a column wrap (not an original line break) — should not count
      // Original text: "あいうえおか" (no newline, 6 chars)
      // Global TTS range 3-5 should highlight 'え', 'お'
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
                // No line breaks — this is a column wrap
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 'え', 'お' should be highlighted (2 chars)
      expect(_findGreenTexts(tester).length, 2);
    });

    testWidgets('line-break newline: counts in offset for TTS alignment',
        (tester) async {
      // Segments with line-break newline between columns:
      // 'あいう' + '\n' + 'えおか'
      // The \n is an original line break — should count in offset
      // Original text: "あいう\nえおか" (7 chars including newline)
      // TextSegmenter produces: "えおか" at offset 4 (after "あいう\n")
      // Global TTS range 4-7 should highlight 'え', 'お', 'か'
      //
      // Char entries: あ(0), い(1), う(2), \n(3=linebreak), え(4), お(5), か(6)
      // Entry index 3 is a line-break newline
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
                ttsHighlightStart: 4,
                ttsHighlightEnd: 7,
                pageStartTextOffset: 0,
                lineBreakEntryIndices: {3}, // newline at entry 3 is a line break
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 'え', 'お', 'か' should be highlighted (3 chars)
      expect(_findGreenTexts(tester).length, 3);
    });

    testWidgets('multiple line-break newlines: cumulative offset correction',
        (tester) async {
      // Original text: "あ\nい\nう" (5 chars including 2 newlines)
      // Segments on page: 'あ' + '\n' + 'い' + '\n' + 'う'
      // TextSegmenter: "う" at offset 4 (after "あ\nい\n")
      // Global TTS range 4-5 should highlight 'う'
      //
      // Char entries: あ(0), \n(1=linebreak), い(2), \n(3=linebreak), う(4)
      const segments = [
        PlainTextSegment('あ'),
        PlainTextSegment('\n'),
        PlainTextSegment('い'),
        PlainTextSegment('\n'),
        PlainTextSegment('う'),
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
                ttsHighlightStart: 4,
                ttsHighlightEnd: 5,
                pageStartTextOffset: 0,
                lineBreakEntryIndices: {1, 3}, // both newlines are line breaks
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only 'う' should be highlighted (1 char)
      expect(_findGreenTexts(tester).length, 1);
    });
  });
}
