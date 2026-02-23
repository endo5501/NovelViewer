import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';

void main() {
  group('computeCharOffsetPerPage', () {
    test('returns [0] for single page', () {
      final columns = <List<TextSegment>>[
        [const PlainTextSegment('あいう')],
      ];
      final pageStarts = [0];
      final lineStartColumns = [0]; // single line

      expect(computeCharOffsetPerPage(columns, pageStarts, lineStartColumns), [0]);
    });

    test('computes offset for two pages (same line, column wrap)', () {
      final columns = <List<TextSegment>>[
        [const PlainTextSegment('あいう')],
        [const PlainTextSegment('えおか')],
      ];
      final pageStarts = [0, 1];
      final lineStartColumns = [0]; // both columns from same line

      // No newlines between columns (column wrap)
      expect(computeCharOffsetPerPage(columns, pageStarts, lineStartColumns), [0, 3]);
    });

    test('computes offset with Ruby text', () {
      final columns = <List<TextSegment>>[
        [
          const PlainTextSegment('あ'),
          const RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
        ],
        [const PlainTextSegment('えおか')],
      ];
      final pageStarts = [0, 1];
      final lineStartColumns = [0]; // same line

      // Page 0: 'あ'(1) + '漢字'(2) = 3 chars
      expect(computeCharOffsetPerPage(columns, pageStarts, lineStartColumns), [0, 3]);
    });

    test('computes offset with empty columns (blank lines)', () {
      final columns = <List<TextSegment>>[
        [const PlainTextSegment('あいう')],
        <TextSegment>[], // empty line
        [const PlainTextSegment('えおか')],
      ];
      final pageStarts = [0, 2];
      // 3 lines: line 0 at col 0, line 1 (empty) at col 1, line 2 at col 2
      final lineStartColumns = [0, 1, 2];

      // Page 0: col 0 = 3 chars + 1 newline + col 1 = 0 chars + 1 newline = 5
      expect(computeCharOffsetPerPage(columns, pageStarts, lineStartColumns), [0, 5]);
    });

    test('computes offset for three pages (same line)', () {
      final columns = <List<TextSegment>>[
        [const PlainTextSegment('あい')],
        [const PlainTextSegment('うえ')],
        [const PlainTextSegment('おか')],
      ];
      final pageStarts = [0, 1, 2];
      final lineStartColumns = [0]; // all from same line (column wrap)

      expect(computeCharOffsetPerPage(columns, pageStarts, lineStartColumns), [0, 2, 4]);
    });

    test('computes offset with multiple columns per page', () {
      final columns = <List<TextSegment>>[
        [const PlainTextSegment('あいう')],
        [const PlainTextSegment('えお')],
        [const PlainTextSegment('かきく')],
      ];
      // Page 0 has columns 0,1; Page 1 has column 2
      final pageStarts = [0, 2];
      final lineStartColumns = [0]; // all from same line

      // Page 0: 3 + 2 = 5 chars
      expect(computeCharOffsetPerPage(columns, pageStarts, lineStartColumns), [0, 5]);
    });

    test('includes original newlines between different lines', () {
      // Original text: "あいう\nえおか" (7 chars including newline)
      // 2 lines → 2 columns with a line break between them
      final columns = <List<TextSegment>>[
        [const PlainTextSegment('あいう')],
        [const PlainTextSegment('えおか')],
      ];
      final pageStarts = [0, 1];
      final lineStartColumns = [0, 1]; // line 0 at col 0, line 1 at col 1

      // Page 0 offset: 0
      // Page 1 offset: 3 (text) + 1 (newline between lines) = 4
      expect(computeCharOffsetPerPage(columns, pageStarts, lineStartColumns), [0, 4]);
    });

    test('includes multiple newlines for multiple lines', () {
      // Original text: "あ\nい\nう" (5 chars including 2 newlines)
      final columns = <List<TextSegment>>[
        [const PlainTextSegment('あ')],
        [const PlainTextSegment('い')],
        [const PlainTextSegment('う')],
      ];
      final pageStarts = [0, 1, 2];
      final lineStartColumns = [0, 1, 2]; // each column is a new line

      // Page 0: 0
      // Page 1: 1 (text) + 1 (newline) = 2
      // Page 2: 1 + 1 + 1 + 1 = 4
      expect(computeCharOffsetPerPage(columns, pageStarts, lineStartColumns), [0, 2, 4]);
    });

    test('mixes line breaks and column wraps correctly', () {
      // Original text: "あいうえ\nかきくけ" (9 chars including 1 newline)
      // Line 0: "あいうえ" → 2 columns (wrap at 2 chars)
      // Line 1: "かきくけ" → 2 columns (wrap at 2 chars)
      final columns = <List<TextSegment>>[
        [const PlainTextSegment('あい')], // col 0: line 0
        [const PlainTextSegment('うえ')], // col 1: line 0 (column wrap)
        [const PlainTextSegment('かき')], // col 2: line 1 (line break)
        [const PlainTextSegment('くけ')], // col 3: line 1 (column wrap)
      ];
      final pageStarts = [0, 2]; // page 0: cols 0-1, page 1: cols 2-3
      final lineStartColumns = [0, 2]; // line 0 at col 0, line 1 at col 2

      // Page 0: 0
      // Page 1: 2+2 (text) + 1 (newline between lines) = 5
      expect(computeCharOffsetPerPage(columns, pageStarts, lineStartColumns), [0, 5]);
    });
  });

  group('VerticalTextViewer didUpdateWidget with memoized segments', () {
    testWidgets('does not reset page when same segment reference is provided',
        (tester) async {
      // Create enough text to span multiple pages in narrow width
      final longText = List.generate(200, (i) => 'あ').join();
      final segments = [PlainTextSegment(longText)];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 400,
              child: VerticalTextViewer(
                segments: segments,
                baseStyle: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify we start on page 1
      expect(find.textContaining('1 /'), findsOneWidget);

      // Navigate to page 2 via keyboard (arrow left = next page in vertical)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      // Should now be on page 2
      expect(find.textContaining('2 /'), findsOneWidget);

      // Rebuild with SAME segment reference (simulating memoized cache)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 400,
              child: VerticalTextViewer(
                segments: segments, // same reference
                baseStyle: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should still be on page 2 (not reset to page 1)
      expect(find.textContaining('2 /'), findsOneWidget);
    });
  });
}
