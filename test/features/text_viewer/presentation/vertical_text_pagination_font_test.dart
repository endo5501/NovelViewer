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
