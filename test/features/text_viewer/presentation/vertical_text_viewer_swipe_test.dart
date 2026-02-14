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

/// Simulate a fast horizontal swipe using pointer events
Future<void> _simulateSwipe(
  WidgetTester tester, {
  required Offset start,
  required Offset end,
  Duration duration = const Duration(milliseconds: 100),
}) async {
  final gesture = await tester.startGesture(start);
  await tester.pump(duration);
  await gesture.moveTo(end);
  await gesture.up();
  await tester.pump();
}

void main() {
  // Create multi-page content for swipe tests
  List<TextSegment> multiPageSegments() =>
      [PlainTextSegment('あ' * 500)];

  group('VerticalTextViewer swipe page navigation', () {
    testWidgets('left swipe advances to next page', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          segments: multiPageSegments(),
          width: 100,
          height: 400,
        ),
      );

      // Verify we start on page 1
      expect(_extractCurrentPage(tester), 1);

      // Simulate left swipe (start right, end left)
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await _simulateSwipe(
        tester,
        start: center + const Offset(50, 0),
        end: center + const Offset(-50, 0),
      );

      // Should advance to page 2
      expect(_extractCurrentPage(tester), 2);
    });

    testWidgets('right swipe returns to previous page', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          segments: multiPageSegments(),
          width: 100,
          height: 400,
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
        start: center + const Offset(-50, 0),
        end: center + const Offset(50, 0),
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
          width: 100,
          height: 400,
        ),
      );

      expect(_extractCurrentPage(tester), 1);

      // Simulate right swipe on first page
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await _simulateSwipe(
        tester,
        start: center + const Offset(-50, 0),
        end: center + const Offset(50, 0),
      );

      // Should remain on page 1
      expect(_extractCurrentPage(tester), 1);
    });

    testWidgets('left swipe on last page has no effect', (tester) async {
      // Use content that fits in exactly 2 pages with small viewport
      final segments = [PlainTextSegment('あ' * 60)];

      await tester.pumpWidget(
        _buildTestWidget(
          segments: segments,
          width: 50,
          height: 400,
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
        start: center + const Offset(50, 0),
        end: center + const Offset(-50, 0),
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
          width: 100,
          height: 400,
        ),
      );

      expect(_extractCurrentPage(tester), 1);

      // Simulate slow drag (long duration)
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await _simulateSwipe(
        tester,
        start: center + const Offset(50, 0),
        end: center + const Offset(-50, 0),
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
          width: 100,
          height: 400,
        ),
      );

      expect(_extractCurrentPage(tester), 1);

      // Simulate short movement (less than 50px)
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
          width: 100,
          height: 400,
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
          width: 100,
          height: 400,
          onSelectionChanged: (text) => notifications.add(text),
        ),
      );

      // Simulate left swipe
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await _simulateSwipe(
        tester,
        start: center + const Offset(50, 0),
        end: center + const Offset(-50, 0),
      );

      // onSelectionChanged should have been called with null
      expect(notifications, contains(null));
    });
  });

  group('VerticalTextViewer arrow key navigation with swipe', () {
    testWidgets('arrow keys still work after swipe implementation',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          segments: multiPageSegments(),
          width: 100,
          height: 400,
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
