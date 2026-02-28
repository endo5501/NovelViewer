import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';

void main() {
  group('VerticalTextPage - TTS highlight', () {
    testWidgets('applies green highlight to characters in TTS range',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: VerticalTextPage(
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

      // Characters 'あ', 'い', 'う' should have green background
      // Characters 'え', 'お' should have no background
      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      final greenTexts = texts
          .where((t) =>
              t.style?.backgroundColor != null &&
              t.style!.backgroundColor!.toARGB32() ==
                  Colors.green.withValues(alpha: 0.3).toARGB32())
          .toList();
      expect(greenTexts.length, 3);
    });

    testWidgets('no TTS highlight when range is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: VerticalTextPage(
                segments: [PlainTextSegment('あいうえお')],
                baseStyle: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      final greenTexts = texts
          .where((t) =>
              t.style?.backgroundColor != null &&
              t.style!.backgroundColor!.toARGB32() ==
                  Colors.green.withValues(alpha: 0.3).toARGB32())
          .toList();
      expect(greenTexts, isEmpty);
    });

    testWidgets('search highlight takes priority over TTS highlight',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: VerticalTextPage(
                segments: [PlainTextSegment('あいうえお')],
                baseStyle: TextStyle(fontSize: 14),
                query: 'あ',
                ttsHighlightStart: 0,
                ttsHighlightEnd: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      // 'あ' should have yellow (search highlight), not green
      final yellowTexts = texts
          .where((t) =>
              t.style?.backgroundColor != null &&
              t.style!.backgroundColor == Colors.yellow)
          .toList();
      expect(yellowTexts.length, 1);

      // 'い', 'う' should have green (TTS highlight)
      final greenTexts = texts
          .where((t) =>
              t.style?.backgroundColor != null &&
              t.style!.backgroundColor!.toARGB32() ==
                  Colors.green.withValues(alpha: 0.3).toARGB32())
          .toList();
      expect(greenTexts.length, 2);
    });

    testWidgets('search highlight uses amber in dark mode',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: VerticalTextPage(
                segments: [PlainTextSegment('あいうえお')],
                baseStyle: TextStyle(fontSize: 14),
                query: 'あ',
                ttsHighlightStart: 0,
                ttsHighlightEnd: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      // 'あ' should have amber (dark mode search highlight)
      final amberTexts = texts
          .where((t) =>
              t.style?.backgroundColor != null &&
              t.style!.backgroundColor == Colors.amber.shade700)
          .toList();
      expect(amberTexts.length, 1);
    });
  });
}
