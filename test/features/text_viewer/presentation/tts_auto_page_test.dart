import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';

void main() {
  group('VerticalTextViewer - TTS auto page', () {
    testWidgets('passes TTS highlight to VerticalTextPage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: VerticalTextViewer(
                segments: [PlainTextSegment('あいうえお')],
                baseStyle: TextStyle(fontSize: 14),
                ttsHighlightStart: 0,
                ttsHighlightEnd: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The VerticalTextViewer should render with TTS highlight
      expect(find.byType(VerticalTextViewer), findsOneWidget);
    });

    testWidgets('auto-navigates to page containing TTS highlight',
        (tester) async {
      // Create enough text to span multiple pages
      final longText = List.generate(200, (i) => 'あ').join();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100, // narrow to force multiple pages
              height: 400,
              child: VerticalTextViewer(
                segments: [PlainTextSegment(longText)],
                baseStyle: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify we're on page 1
      expect(find.textContaining('1 /'), findsOneWidget);

      // Update with TTS highlight pointing to later text
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 400,
              child: VerticalTextViewer(
                segments: [PlainTextSegment(longText)],
                baseStyle: const TextStyle(fontSize: 14),
                ttsHighlightStart: 190,
                ttsHighlightEnd: 200,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have navigated away from page 1
      expect(find.textContaining('1 /'), findsNothing);
    });
  });
}
