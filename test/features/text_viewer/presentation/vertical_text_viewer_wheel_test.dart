import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
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

/// Send a scroll event to the center of the VerticalTextViewer.
Future<void> _sendScrollEvent(
  WidgetTester tester, {
  required double dy,
}) async {
  final center = tester.getCenter(find.byType(VerticalTextViewer));
  await tester.sendEventToBinding(PointerScrollEvent(
    position: center,
    scrollDelta: Offset(0, dy),
  ));
}

void main() {
  group('VerticalTextViewer wheel page navigation', () {
    testWidgets('wheel scroll down advances to next page', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );
      expect(_extractCurrentPage(tester), 1);

      // Scroll down (positive dy) should advance to next page
      await _sendScrollEvent(tester, dy: 100.0);
      await tester.pumpAndSettle();

      expect(_extractCurrentPage(tester), 2);
    });

    testWidgets('wheel scroll up returns to previous page', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );

      // First navigate to page 2 using arrow key
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_extractCurrentPage(tester), 2);

      // Scroll up (negative dy) should return to previous page
      await _sendScrollEvent(tester, dy: -100.0);
      await tester.pumpAndSettle();

      expect(_extractCurrentPage(tester), 1);
    });
  });

  group('VerticalTextViewer wheel boundary conditions', () {
    testWidgets('wheel scroll down on last page has no effect',
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

      // Scroll down on last page should have no effect
      await _sendScrollEvent(tester, dy: 100.0);
      await tester.pumpAndSettle();

      expect(_extractCurrentPage(tester), totalPages);
    });

    testWidgets('wheel scroll up on first page has no effect', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );
      expect(_extractCurrentPage(tester), 1);

      // Scroll up on first page should have no effect
      await _sendScrollEvent(tester, dy: -100.0);
      await tester.pumpAndSettle();

      expect(_extractCurrentPage(tester), 1);
    });
  });

  group('VerticalTextViewer wheel animation guard', () {
    testWidgets('wheel events are ignored during page transition animation',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );
      expect(_extractCurrentPage(tester), 1);

      // Start page transition with arrow key
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 50)); // Mid-animation

      // Send wheel event during animation - should be ignored
      await _sendScrollEvent(tester, dy: 100.0);
      await tester.pumpAndSettle();

      // Should be on page 2 (from arrow key), not page 3
      expect(_extractCurrentPage(tester), 2);
    });
  });

  group('VerticalTextViewer wheel event filtering', () {
    testWidgets('non-scroll pointer signals are ignored', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );
      expect(_extractCurrentPage(tester), 1);

      // Send a PointerScaleEvent (not PointerScrollEvent)
      final center = tester.getCenter(find.byType(VerticalTextViewer));
      await tester.sendEventToBinding(PointerScaleEvent(
        position: center,
        scale: 1.5,
      ));
      await tester.pumpAndSettle();

      // Page should not change
      expect(_extractCurrentPage(tester), 1);
    });
  });

  group('VerticalTextViewer wheel coexistence with other navigation', () {
    testWidgets('wheel navigation coexists with arrow key navigation',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(segments: _multiPageSegments()),
      );
      expect(_extractCurrentPage(tester), 1);

      // Wheel scroll to page 2
      await _sendScrollEvent(tester, dy: 100.0);
      await tester.pumpAndSettle();
      expect(_extractCurrentPage(tester), 2);

      // Arrow key to page 3
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_extractCurrentPage(tester), 3);

      // Wheel scroll back to page 2
      await _sendScrollEvent(tester, dy: -100.0);
      await tester.pumpAndSettle();
      expect(_extractCurrentPage(tester), 2);
    });
  });
}
