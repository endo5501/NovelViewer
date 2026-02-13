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

void main() {
  group('VerticalTextViewer pagination', () {
    testWidgets('long line spanning multiple visual columns shows page indicator',
        (tester) async {
      // A single line with 500 characters in a narrow viewport
      // should require multiple pages.
      final longText = 'あ' * 500;
      final segments = [PlainTextSegment(longText)];

      await tester.pumpWidget(
        _buildTestWidget(segments: segments, width: 100, height: 400),
      );

      // Should display page indicator (e.g., "1 / N")
      expect(find.textContaining('/'), findsOneWidget);
    });

    testWidgets('short lines fit in a single page without indicator',
        (tester) async {
      final segments = [const PlainTextSegment('あいう\nかきく')];

      await tester.pumpWidget(
        _buildTestWidget(segments: segments, width: 600, height: 400),
      );

      // Short content should fit in one page, no indicator
      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets('multiple long lines are paginated correctly', (tester) async {
      // Multiple lines each spanning several columns in a small viewport
      final segments = [
        PlainTextSegment('${'あ' * 100}\n${'い' * 100}\n${'う' * 100}'),
      ];

      await tester.pumpWidget(
        _buildTestWidget(segments: segments, width: 100, height: 300),
      );

      // Should paginate and show indicator
      expect(find.textContaining('/'), findsOneWidget);
    });
  });

  group('VerticalTextViewer selection', () {
    testWidgets('onSelectionChanged parameter is accepted', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: const [PlainTextSegment('あいう')],
        onSelectionChanged: (text) {},
      ));

      expect(find.byType(VerticalTextViewer), findsOneWidget);
    });

    testWidgets('page navigation calls onSelectionChanged with null',
        (tester) async {
      // Create multi-page content
      final longText = 'あ' * 500;
      final segments = [PlainTextSegment(longText)];
      final notifications = <String?>[];

      await tester.pumpWidget(_buildTestWidget(
        segments: segments,
        width: 100,
        height: 400,
        onSelectionChanged: (text) => notifications.add(text),
      ));

      // Verify we have multiple pages
      expect(find.textContaining('/'), findsOneWidget);

      // Press left arrow to go to next page
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      // onSelectionChanged should have been called with null
      expect(notifications, contains(null));
    });
  });
}
