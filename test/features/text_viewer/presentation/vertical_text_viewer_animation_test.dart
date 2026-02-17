import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';

Widget _buildTestWidget({
  required List<TextSegment> segments,
  double width = 200,
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

/// Find SlideTransition widgets that are descendants of VerticalTextViewer
/// (excludes MaterialApp route transitions).
Finder _findViewerSlideTransitions() {
  return find.descendant(
    of: find.byType(VerticalTextViewer),
    matching: find.byType(SlideTransition),
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

/// Create multi-page content.
List<TextSegment> _multiPageSegments() => [PlainTextSegment('あ' * 500)];

void main() {
  group('Page transition animation - basic operation', () {
    testWidgets('SlideTransition appears during page transition',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );

      // No SlideTransition in viewer before navigation
      expect(_findViewerSlideTransitions(), findsNothing);

      // Navigate to next page
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 50)); // Mid-animation

      // SlideTransition should be visible during animation
      expect(_findViewerSlideTransitions(), findsWidgets);
    });

    testWidgets('animation completes and SlideTransition is removed',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      // After animation completes, SlideTransition should be gone
      expect(_findViewerSlideTransitions(), findsNothing);
      // Page should have advanced
      expect(_extractCurrentPage(tester), 2);
    });

    testWidgets('two VerticalTextPage widgets visible during animation',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // During animation, both old and new pages should be visible
      expect(find.byType(VerticalTextPage), findsNWidgets(2));
    });

    testWidgets('only one VerticalTextPage after animation completes',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      // After animation, only one page should be shown
      expect(find.byType(VerticalTextPage), findsOneWidget);
    });

    testWidgets('animation completes in 250ms', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(); // Start animation

      // At 200ms, animation should still be in progress
      await tester.pump(const Duration(milliseconds: 200));
      expect(_findViewerSlideTransitions(), findsWidgets);

      // Just past 250ms, animation should be complete
      // (AnimationController's isDone uses > not >=, so needs slightly beyond duration)
      await tester.pump(const Duration(milliseconds: 51));
      await tester.pump(); // Process completion callback and rebuild
      expect(_findViewerSlideTransitions(), findsNothing);
    });
  });

  group('Page transition animation - slide direction', () {
    testWidgets('next page: outgoing slides right (positive offset)',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125)); // Mid-animation

      // Find SlideTransitions within VerticalTextViewer
      final slideTransitions = tester
          .widgetList<SlideTransition>(_findViewerSlideTransitions())
          .toList();
      expect(slideTransitions.length, 2);

      // Outgoing page should have positive X offset (sliding right)
      final outgoing = slideTransitions[0];
      final outgoingOffset = outgoing.position.value;
      expect(outgoingOffset.dx, greaterThan(0),
          reason: 'Outgoing page should slide to the right (positive dx)');

      // Incoming page should have negative X offset (sliding in from left)
      final incoming = slideTransitions[1];
      final incomingOffset = incoming.position.value;
      expect(incomingOffset.dx, lessThan(0),
          reason: 'Incoming page should slide in from the left (negative dx)');
    });

    testWidgets('previous page: outgoing slides left (negative offset)',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );

      // First go to page 2
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_extractCurrentPage(tester), 2);

      // Now go back to page 1
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));

      final slideTransitions = tester
          .widgetList<SlideTransition>(_findViewerSlideTransitions())
          .toList();
      expect(slideTransitions.length, 2);

      // Outgoing page should have negative X offset (sliding left)
      final outgoing = slideTransitions[0];
      final outgoingOffset = outgoing.position.value;
      expect(outgoingOffset.dx, lessThan(0),
          reason: 'Outgoing page should slide to the left (negative dx)');

      // Incoming page should have positive X offset (sliding in from right)
      final incoming = slideTransitions[1];
      final incomingOffset = incoming.position.value;
      expect(incomingOffset.dx, greaterThan(0),
          reason:
              'Incoming page should slide in from the right (positive dx)');
    });
  });

  group('Page transition animation - boundary conditions', () {
    testWidgets('no animation when pressing next on last page',
        (tester) async {
      final segments = [PlainTextSegment('あ' * 60)];

      await tester.pumpWidget(
        _buildTestWidget(segments: segments, width: 80, height: 400),
      );

      // Navigate to last page
      final totalPagesText = find.textContaining('/');
      expect(totalPagesText, findsOneWidget);
      final text = tester.widget<Text>(totalPagesText).data!;
      final totalPages = int.parse(text.split('/')[1].trim());

      for (var i = 1; i < totalPages; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
      }
      expect(_extractCurrentPage(tester), totalPages);

      // Try to go to next page (should have no effect)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // No SlideTransition should appear within viewer
      expect(_findViewerSlideTransitions(), findsNothing);
      expect(_extractCurrentPage(tester), totalPages);
    });

    testWidgets('no animation when pressing previous on first page',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );
      expect(_extractCurrentPage(tester), 1);

      // Try to go to previous page (should have no effect)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // No SlideTransition should appear within viewer
      expect(_findViewerSlideTransitions(), findsNothing);
      expect(_extractCurrentPage(tester), 1);
    });
  });

  group('Page transition animation - rapid navigation', () {
    testWidgets(
        'rapid arrow keys: previous animation snaps, new one starts',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );

      // Start first page transition
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Animation should be in progress
      expect(_findViewerSlideTransitions(), findsWidgets);

      // Trigger second page transition while first is still animating
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Animation should still be active (new animation)
      expect(_findViewerSlideTransitions(), findsWidgets);

      // Let animation complete
      await tester.pumpAndSettle();

      // Should be on page 3 (two forwards)
      expect(_extractCurrentPage(tester), 3);
      expect(_findViewerSlideTransitions(), findsNothing);
    });
  });

  group('Page transition animation - layout change', () {
    testWidgets('animation cancelled on widget size change', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          segments: _multiPageSegments(),
          width: 200,
          height: 400,
        ),
      );

      // Start animation
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_findViewerSlideTransitions(), findsWidgets);

      // Change widget size (simulating window resize)
      await tester.pumpWidget(
        _buildTestWidget(
          segments: _multiPageSegments(),
          width: 300,
          height: 400,
        ),
      );
      await tester.pump();

      // Animation should be cancelled - no SlideTransition
      expect(_findViewerSlideTransitions(), findsNothing);
    });
  });

  group('Page transition animation - existing functionality preserved', () {
    testWidgets('arrow key navigation still works with animation',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );

      expect(_extractCurrentPage(tester), 1);

      // Left arrow advances to next page
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_extractCurrentPage(tester), 2);

      // Right arrow returns to previous page
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_extractCurrentPage(tester), 1);
    });

    testWidgets('swipe navigation still works with animation',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );

      expect(_extractCurrentPage(tester), 1);

      // Right swipe advances to next page
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await tester.timedDragFrom(
        center + const Offset(-40, 0),
        const Offset(80, 0),
        const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();
      expect(_extractCurrentPage(tester), 2);
    });
  });
}
