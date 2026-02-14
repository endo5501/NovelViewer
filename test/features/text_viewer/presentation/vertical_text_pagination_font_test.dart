import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';

Widget _buildTestWidget({
  required List<TextSegment> segments,
  double width = 300,
  double height = 400,
  TextStyle? baseStyle,
}) {
  return MaterialApp(
    home: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: width, height: height),
        child: VerticalTextViewer(
          segments: segments,
          baseStyle: baseStyle,
        ),
      ),
    ),
  );
}

/// Extract page indicator text like "1 / 5" and return total page count.
int? _extractTotalPages(WidgetTester tester) {
  final textFinder = find.textContaining('/');
  if (textFinder.evaluate().isEmpty) return 1; // no indicator = single page
  final textWidget = tester.widget<Text>(textFinder);
  final pageText = textWidget.data ?? '';
  final parts = pageText.split('/');
  if (parts.length == 2) {
    return int.tryParse(parts[1].trim());
  }
  return null;
}

/// Verify that the Wrap widget does not overflow the container.
void _expectWrapNotOverflowing(WidgetTester tester, double containerWidth) {
  final wrapFinder = find.byType(Wrap);
  expect(wrapFinder, findsOneWidget);

  final wrapRenderBox = tester.renderObject<RenderBox>(wrapFinder);
  expect(wrapRenderBox.size.width, lessThanOrEqualTo(containerWidth),
      reason: 'Wrap should not overflow container width');
}

/// Verify that no child of the Wrap extends beyond the container width.
/// This checks actual rendered positions, not just the Wrap's constrained size.
void _expectNoChildOverflow(WidgetTester tester, double containerWidth,
    {String? reason}) {
  final wrapFinder = find.byType(Wrap);
  expect(wrapFinder, findsOneWidget);

  final wrapRenderBox = tester.renderObject<RenderBox>(wrapFinder);
  final wrapTopLeft = wrapRenderBox.localToGlobal(Offset.zero);

  // Visit all child render objects of the Wrap
  void visitChildren(RenderObject parent) {
    parent.visitChildren((child) {
      if (child is RenderBox && child.hasSize) {
        final childTopLeft = child.localToGlobal(Offset.zero);
        final childRight = childTopLeft.dx + child.size.width;
        final childLeft = childTopLeft.dx;
        final wrapLeft = wrapTopLeft.dx;
        final wrapRight = wrapTopLeft.dx + wrapRenderBox.size.width;

        // Check that the child is within the Wrap bounds horizontally
        expect(childLeft, greaterThanOrEqualTo(wrapLeft - 1.0),
            reason:
                '${reason ?? ''} Child extends beyond left edge: '
                'childLeft=$childLeft, wrapLeft=$wrapLeft');
        expect(childRight, lessThanOrEqualTo(wrapRight + 1.0),
            reason:
                '${reason ?? ''} Child extends beyond right edge: '
                'childRight=$childRight, wrapRight=$wrapRight');
      }
      visitChildren(child);
    });
  }

  visitChildren(wrapRenderBox);
}

void main() {
  group('Vertical text pagination with font size changes', () {
    testWidgets(
        'large font size produces more pages than small font size',
        (tester) async {
      final longText = 'あ' * 200;
      final segments = [PlainTextSegment(longText)];

      // Render with small font
      await tester.pumpWidget(_buildTestWidget(
        segments: segments,
        width: 200,
        height: 400,
        baseStyle: const TextStyle(fontSize: 14.0),
      ));
      final smallFontPages = _extractTotalPages(tester);

      // Render with large font
      await tester.pumpWidget(_buildTestWidget(
        segments: segments,
        width: 200,
        height: 400,
        baseStyle: const TextStyle(fontSize: 32.0),
      ));
      final largeFontPages = _extractTotalPages(tester);

      expect(smallFontPages, isNotNull);
      expect(largeFontPages, isNotNull);
      expect(largeFontPages!, greaterThan(smallFontPages!),
          reason: 'Larger font should produce more pages');
    });

    testWidgets(
        'text does not overflow container with large font size',
        (tester) async {
      final longText = 'あ' * 100;
      final segments = [PlainTextSegment(longText)];
      const containerWidth = 200.0;

      await tester.pumpWidget(_buildTestWidget(
        segments: segments,
        width: containerWidth,
        height: 400,
        baseStyle: const TextStyle(fontSize: 32.0),
      ));

      _expectWrapNotOverflowing(tester, containerWidth);
    });
  });

  group('Vertical text pagination sentinel runSpacing', () {
    testWidgets(
        'no child widget extends beyond container with font size 17.0',
        (tester) async {
      final longText = 'あ' * 300;
      final segments = [PlainTextSegment(longText)];
      const containerWidth = 300.0;

      await tester.pumpWidget(_buildTestWidget(
        segments: segments,
        width: containerWidth,
        height: 400,
        baseStyle: const TextStyle(fontSize: 17.0),
      ));

      _expectNoChildOverflow(tester, containerWidth);
    });

    testWidgets(
        'no child widget extends beyond container across font size range 10-32',
        (tester) async {
      final longText = 'あ' * 300;
      final segments = [PlainTextSegment(longText)];
      const containerWidth = 300.0;

      for (final fontSize in [10.0, 14.0, 17.0, 20.0, 24.0, 28.0, 32.0]) {
        await tester.pumpWidget(_buildTestWidget(
          segments: segments,
          width: containerWidth,
          height: 400,
          baseStyle: TextStyle(fontSize: fontSize),
        ));

        _expectNoChildOverflow(tester, containerWidth,
            reason: 'fontSize=$fontSize');
      }
    });
  });

  group('Vertical text pagination empty columns', () {
    testWidgets(
        'text with blank lines uses available width efficiently',
        (tester) async {
      // Create text with alternating content and blank lines.
      // This produces ~50% empty columns from paragraph separators.
      final lines = <String>[];
      for (var i = 0; i < 100; i++) {
        lines.add('あ' * 10);
        lines.add(''); // blank line → empty column
      }
      final text = lines.join('\n');
      final segments = [PlainTextSegment(text)];
      const containerWidth = 600.0;

      await tester.pumpWidget(_buildTestWidget(
        segments: segments,
        width: containerWidth,
        height: 400,
        baseStyle: const TextStyle(fontSize: 14.0),
      ));

      // The Wrap should use most of the available width.
      // With fixed-count pagination, empty columns waste ~charWidth each,
      // resulting in ~55% utilization. With width-based packing, it should
      // be above 90%.
      final wrapFinder = find.byType(Wrap);
      expect(wrapFinder, findsOneWidget);
      final wrapBox = tester.renderObject<RenderBox>(wrapFinder);
      const availableWidth = containerWidth - 32.0; // _kHorizontalPadding

      expect(wrapBox.size.width, greaterThan(availableWidth * 0.9),
          reason:
              'Wrap width (${wrapBox.size.width}) should be at least 90% '
              'of available width ($availableWidth) even with blank lines');
    });

    testWidgets(
        'text with blank lines still does not overflow',
        (tester) async {
      final lines = <String>[];
      for (var i = 0; i < 100; i++) {
        lines.add('あ' * 10);
        lines.add('');
      }
      final text = lines.join('\n');
      final segments = [PlainTextSegment(text)];
      const containerWidth = 600.0;

      await tester.pumpWidget(_buildTestWidget(
        segments: segments,
        width: containerWidth,
        height: 400,
        baseStyle: const TextStyle(fontSize: 14.0),
      ));

      _expectNoChildOverflow(tester, containerWidth);
    });
  });

  group('Vertical text pagination empty columns edge cases', () {
    testWidgets(
        'all empty columns does not crash and stays bounded',
        (tester) async {
      // Text of only blank lines → all columns are empty
      final text = List.filled(120, '').join('\n');
      await tester.pumpWidget(_buildTestWidget(
        segments: [PlainTextSegment(text)],
        width: 320,
        height: 400,
        baseStyle: const TextStyle(fontSize: 14.0),
      ));

      _expectNoChildOverflow(tester, 320);
      expect(_extractTotalPages(tester), isNotNull);
    });

    testWidgets(
        'single empty line remains single page',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('')],
        width: 320,
        height: 400,
        baseStyle: const TextStyle(fontSize: 14.0),
      ));

      expect(_extractTotalPages(tester), 1);
    });
  });

  group('Vertical text pagination empty columns regression', () {
    testWidgets(
        'text without blank lines still does not overflow',
        (tester) async {
      // Pure continuous text without blank lines
      final segments = [PlainTextSegment('あ' * 300)];
      const containerWidth = 300.0;

      for (final fontSize in [14.0, 17.0, 24.0]) {
        await tester.pumpWidget(_buildTestWidget(
          segments: segments,
          width: containerWidth,
          height: 400,
          baseStyle: TextStyle(fontSize: fontSize),
        ));

        _expectNoChildOverflow(tester, containerWidth,
            reason: 'fontSize=$fontSize');
      }
    });

    testWidgets(
        'text with blank lines packs more columns than fixed-count would',
        (tester) async {
      // Create text with 50% blank lines
      final lines = <String>[];
      for (var i = 0; i < 80; i++) {
        lines.add('あ' * 10);
        lines.add('');
      }
      final textWithBlanks = lines.join('\n');
      final segmentsWithBlanks = [PlainTextSegment(textWithBlanks)];

      // Create equivalent text without blank lines (same character count)
      final textNoBlanks = List.generate(80, (_) => 'あ' * 10).join('\n');
      final segmentsNoBlanks = [PlainTextSegment(textNoBlanks)];

      const containerWidth = 600.0;

      // Render with blank lines
      await tester.pumpWidget(_buildTestWidget(
        segments: segmentsWithBlanks,
        width: containerWidth,
        height: 400,
        baseStyle: const TextStyle(fontSize: 14.0),
      ));
      final pagesWithBlanks = _extractTotalPages(tester)!;

      // Render without blank lines
      await tester.pumpWidget(_buildTestWidget(
        segments: segmentsNoBlanks,
        width: containerWidth,
        height: 400,
        baseStyle: const TextStyle(fontSize: 14.0),
      ));
      final pagesNoBlanks = _extractTotalPages(tester)!;

      // With blank lines there are more total columns (empty ones too),
      // but efficient packing means the page count shouldn't be dramatically
      // higher. It should be less than double the no-blanks count.
      expect(pagesWithBlanks, lessThanOrEqualTo(pagesNoBlanks * 2),
          reason:
              'Blank-line pages ($pagesWithBlanks) should not be dramatically '
              'more than no-blank pages ($pagesNoBlanks)');
    });

    testWidgets(
        'targetLineNumber navigates correctly with blank lines',
        (tester) async {
      // Create text: 50 lines with blank separators
      final lines = <String>[];
      for (var i = 0; i < 50; i++) {
        lines.add('${'あ' * 5}行$i');
        lines.add('');
      }
      final text = lines.join('\n');
      final segments = [PlainTextSegment(text)];

      // Render targeting a line near the end (line 80 = 40th content line)
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints.tightFor(width: 400, height: 400),
            child: VerticalTextViewer(
              segments: segments,
              baseStyle: const TextStyle(fontSize: 14.0),
              targetLineNumber: 80,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Should navigate to a page beyond page 1
      final pageText = find.textContaining('/');
      expect(pageText, findsOneWidget);
      final text2 = tester.widget<Text>(pageText).data ?? '';
      final currentPage = int.tryParse(text2.split('/')[0].trim()) ?? 0;
      expect(currentPage, greaterThan(1),
          reason: 'Should navigate beyond page 1 for targetLine=80');
    });
  });

  group('Vertical text pagination with font family changes', () {
    testWidgets(
        'pagination recalculates when font family changes',
        (tester) async {
      final longText = 'あ' * 200;
      final segments = [PlainTextSegment(longText)];

      // Render with default font
      await tester.pumpWidget(_buildTestWidget(
        segments: segments,
        width: 200,
        height: 400,
        baseStyle: const TextStyle(fontSize: 20.0),
      ));
      expect(find.byType(VerticalTextViewer), findsOneWidget);
      final defaultPages = _extractTotalPages(tester);

      // Render with a specific font family
      await tester.pumpWidget(_buildTestWidget(
        segments: segments,
        width: 200,
        height: 400,
        baseStyle: const TextStyle(
          fontSize: 20.0,
          fontFamily: 'Hiragino Mincho ProN',
        ),
      ));
      expect(find.byType(VerticalTextViewer), findsOneWidget);
      final hiraPages = _extractTotalPages(tester);

      // Both should produce valid pagination
      expect(defaultPages, isNotNull);
      expect(hiraPages, isNotNull);
      // Pagination should have recalculated (pages may differ or be same
      // depending on font metrics, but should be a positive number)
      expect(hiraPages!, greaterThan(0));
    });

    testWidgets(
        'text does not overflow container when font family is changed',
        (tester) async {
      final longText = 'あ' * 100;
      final segments = [PlainTextSegment(longText)];
      const containerWidth = 200.0;

      await tester.pumpWidget(_buildTestWidget(
        segments: segments,
        width: containerWidth,
        height: 400,
        baseStyle: const TextStyle(
          fontSize: 24.0,
          fontFamily: 'Hiragino Mincho ProN',
        ),
      ));

      _expectWrapNotOverflowing(tester, containerWidth);
    });
  });
}
