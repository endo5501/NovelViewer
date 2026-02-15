import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';

Widget _buildTestWidget({
  required List<TextSegment> segments,
  double width = 300,
  double height = 400,
  ValueChanged<String?>? onSelectionChanged,
}) {
  return MaterialApp(
    home: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: width, height: height),
        child: VerticalTextViewer(
          segments: segments,
          baseStyle: const TextStyle(fontSize: 14.0),
          onSelectionChanged: onSelectionChanged,
        ),
      ),
    ),
  );
}

/// Extract current page number from page indicator text (e.g., "1 / 5" → 1)
int? _extractCurrentPage(WidgetTester tester) {
  final finder = find.textContaining('/');
  if (finder.evaluate().isEmpty) return null;
  final text = tester.widget<Text>(finder).data;
  if (text == null) return null;
  final parts = text.split('/');
  return int.tryParse(parts[0].trim());
}

/// Simulate a horizontal swipe using timed drag.
Future<void> _simulateSwipe(
  WidgetTester tester, {
  required Offset start,
  required Offset end,
  Duration duration = const Duration(milliseconds: 100),
}) async {
  await tester.timedDragFrom(start, end - start, duration);
  await tester.pumpAndSettle();
}

void main() {
  // Create multi-page content for swipe tests.
  // Use wider viewport (200px) so swipe gestures stay within widget bounds.
  List<TextSegment> multiPageSegments() =>
      [PlainTextSegment('あ' * 500)];

  const testWidth = 200.0;
  const testHeight = 400.0;

  group('VerticalTextViewer swipe page navigation', () {
    testWidgets('left swipe advances to next page', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          segments: multiPageSegments(),
          width: testWidth,
          height: testHeight,
        ),
      );

      // Verify we start on page 1
      expect(_extractCurrentPage(tester), 1);

      // Simulate left swipe (start right, end left) within widget bounds
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await _simulateSwipe(
        tester,
        start: center + const Offset(40, 0),
        end: center + const Offset(-40, 0),
      );

      // Should advance to page 2
      expect(_extractCurrentPage(tester), 2);
    });

    testWidgets('right swipe returns to previous page', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          segments: multiPageSegments(),
          width: testWidth,
          height: testHeight,
        ),
      );

      // First navigate to page 2 using arrow key
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(_extractCurrentPage(tester), 2);

      // Simulate right swipe (start left, end right)
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await _simulateSwipe(
        tester,
        start: center + const Offset(-40, 0),
        end: center + const Offset(40, 0),
      );

      // Should return to page 1
      expect(_extractCurrentPage(tester), 1);
    });
  });

  group('VerticalTextViewer swipe boundary conditions', () {
    testWidgets('right swipe on first page has no effect', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          segments: multiPageSegments(),
          width: testWidth,
          height: testHeight,
        ),
      );

      expect(_extractCurrentPage(tester), 1);

      // Simulate right swipe on first page
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await _simulateSwipe(
        tester,
        start: center + const Offset(-40, 0),
        end: center + const Offset(40, 0),
      );

      // Should remain on page 1
      expect(_extractCurrentPage(tester), 1);
    });

    testWidgets('left swipe on last page has no effect', (tester) async {
      // Use content that fits in a few pages with small viewport
      final segments = [PlainTextSegment('あ' * 60)];

      await tester.pumpWidget(
        _buildTestWidget(
          segments: segments,
          width: 80,
          height: testHeight,
        ),
      );

      // Navigate to last page using arrow keys
      final totalPagesText = find.textContaining('/');
      expect(totalPagesText, findsOneWidget);
      final text = tester.widget<Text>(totalPagesText).data!;
      final totalPages = int.parse(text.split('/')[1].trim());

      for (var i = 1; i < totalPages; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
      }
      expect(_extractCurrentPage(tester), totalPages);

      // Simulate left swipe on last page
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await _simulateSwipe(
        tester,
        start: center + const Offset(30, 0),
        end: center + const Offset(-30, 0),
      );

      // Should remain on last page
      expect(_extractCurrentPage(tester), totalPages);
    });
  });

  group('VerticalTextViewer swipe rejection', () {
    testWidgets('slow horizontal drag is not recognized as swipe',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          segments: multiPageSegments(),
          width: testWidth,
          height: testHeight,
        ),
      );

      expect(_extractCurrentPage(tester), 1);

      // Simulate slow drag (long duration)
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await _simulateSwipe(
        tester,
        start: center + const Offset(40, 0),
        end: center + const Offset(-40, 0),
        duration: const Duration(milliseconds: 1000),
      );

      // Should remain on page 1
      expect(_extractCurrentPage(tester), 1);
    });

    testWidgets('short horizontal movement is not recognized as swipe',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          segments: multiPageSegments(),
          width: testWidth,
          height: testHeight,
        ),
      );

      expect(_extractCurrentPage(tester), 1);

      // Simulate short movement (less than 50px total displacement)
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await _simulateSwipe(
        tester,
        start: center + const Offset(10, 0),
        end: center + const Offset(-10, 0),
      );

      // Should remain on page 1
      expect(_extractCurrentPage(tester), 1);
    });

    testWidgets('primarily vertical drag is not recognized as swipe',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          segments: multiPageSegments(),
          width: testWidth,
          height: testHeight,
        ),
      );

      expect(_extractCurrentPage(tester), 1);

      // Simulate vertical drag (dy > dx)
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await _simulateSwipe(
        tester,
        start: center + const Offset(30, 50),
        end: center + const Offset(-30, -50),
      );

      // Should remain on page 1
      expect(_extractCurrentPage(tester), 1);
    });
  });

  group('VerticalTextViewer swipe selection clearing', () {
    testWidgets('swipe clears active text selection', (tester) async {
      final notifications = <String?>[];

      await tester.pumpWidget(
        _buildTestWidget(
          segments: multiPageSegments(),
          width: testWidth,
          height: testHeight,
          onSelectionChanged: (text) => notifications.add(text),
        ),
      );

      // Simulate left swipe
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await _simulateSwipe(
        tester,
        start: center + const Offset(40, 0),
        end: center + const Offset(-40, 0),
      );

      // onSelectionChanged should have been called with null
      expect(notifications, contains(null));
    });
  });

  group('VerticalTextViewer desktop-like swipe', () {
    testWidgets('drag with pause before release still triggers swipe',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          segments: multiPageSegments(),
          width: testWidth,
          height: testHeight,
        ),
      );

      expect(_extractCurrentPage(tester), 1);

      // Simulate desktop-like gesture: drag then pause before releasing
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      final gesture = await tester.startGesture(center + const Offset(45, 0));
      await gesture.moveTo(center + const Offset(-45, 0));
      // Pause before release - velocity drops to near zero
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_extractCurrentPage(tester), 2);
    });
  });

  group('VerticalTextViewer arrow key navigation with swipe', () {
    testWidgets('arrow keys still work after swipe implementation',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          segments: multiPageSegments(),
          width: testWidth,
          height: testHeight,
        ),
      );

      expect(_extractCurrentPage(tester), 1);

      // Left arrow advances to next page
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(_extractCurrentPage(tester), 2);

      // Right arrow returns to previous page
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_extractCurrentPage(tester), 1);
    });
  });
}
