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

      expect(computeCharOffsetPerPage(columns, pageStarts), [0]);
    });

    test('computes offset for two pages', () {
      final columns = <List<TextSegment>>[
        [const PlainTextSegment('あいう')],
        [const PlainTextSegment('えおか')],
      ];
      final pageStarts = [0, 1];

      expect(computeCharOffsetPerPage(columns, pageStarts), [0, 3]);
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

      // Page 0: 'あ'(1) + '漢字'(2) = 3 chars
      expect(computeCharOffsetPerPage(columns, pageStarts), [0, 3]);
    });

    test('computes offset with empty columns (blank lines)', () {
      final columns = <List<TextSegment>>[
        [const PlainTextSegment('あいう')],
        <TextSegment>[], // empty line
        [const PlainTextSegment('えおか')],
      ];
      final pageStarts = [0, 2];

      // Page 0: col 0 = 3 chars, col 1 = 0 chars → 3 total
      expect(computeCharOffsetPerPage(columns, pageStarts), [0, 3]);
    });

    test('computes offset for three pages', () {
      final columns = <List<TextSegment>>[
        [const PlainTextSegment('あい')],
        [const PlainTextSegment('うえ')],
        [const PlainTextSegment('おか')],
      ];
      final pageStarts = [0, 1, 2];

      expect(computeCharOffsetPerPage(columns, pageStarts), [0, 2, 4]);
    });

    test('computes offset with multiple columns per page', () {
      final columns = <List<TextSegment>>[
        [const PlainTextSegment('あいう')],
        [const PlainTextSegment('えお')],
        [const PlainTextSegment('かきく')],
      ];
      // Page 0 has columns 0,1; Page 1 has column 2
      final pageStarts = [0, 2];

      // Page 0: 3 + 2 = 5 chars
      expect(computeCharOffsetPerPage(columns, pageStarts), [0, 5]);
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
