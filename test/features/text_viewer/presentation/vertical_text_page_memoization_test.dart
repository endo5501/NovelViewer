import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_marked_ranges.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

const _segments = [PlainTextSegment('アリスが歩く。ボブが走る。')];
const _marked = {'アリス': MarkStyle.solid, 'ボブ': MarkStyle.solid};

Widget _wrap({
  int? selectionStart,
  int? selectionEnd,
  int? ttsHighlightStart,
  int? ttsHighlightEnd,
  TextStyle baseStyle = const TextStyle(fontSize: 14.0),
  double columnSpacing = 8.0,
}) {
  return MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 200,
        height: 300,
        child: VerticalTextPage(
          segments: _segments,
          baseStyle: baseStyle,
          markedWords: _marked,
          selectionStart: selectionStart,
          selectionEnd: selectionEnd,
          ttsHighlightStart: ttsHighlightStart,
          ttsHighlightEnd: ttsHighlightEnd,
          columnSpacing: columnSpacing,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    computeMarkedRangesCallCount = 0;
    verticalTtsHighlightComputeCount = 0;
    verticalHitRegionScheduleCount = 0;
  });

  group('F116: page-level memoization', () {
    testWidgets('selection change does not recompute marks or TTS highlights', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      computeMarkedRangesCallCount = 0;
      verticalTtsHighlightComputeCount = 0;

      // A selection change rebuilds the page but touches neither the entries,
      // the marked words, nor the TTS range.
      await tester.pumpWidget(_wrap(selectionStart: 0, selectionEnd: 2));
      await tester.pump();

      expect(computeMarkedRangesCallCount, 0,
          reason: 'marks must be reused on a selection-only rebuild');
      expect(verticalTtsHighlightComputeCount, 0,
          reason: 'TTS highlights must be reused on a selection-only rebuild');
    });

    testWidgets('TTS tick does not reschedule the hit-region rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(ttsHighlightStart: 0, ttsHighlightEnd: 2));
      await tester.pumpAndSettle();
      verticalHitRegionScheduleCount = 0;

      // Advance the TTS highlight. Character rectangles do not move, so no
      // hit-region rebuild should be scheduled.
      await tester.pumpWidget(_wrap(ttsHighlightStart: 3, ttsHighlightEnd: 5));
      await tester.pump();

      expect(verticalHitRegionScheduleCount, 0);
    });

    testWidgets('style change reschedules the hit-region rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      verticalHitRegionScheduleCount = 0;

      await tester.pumpWidget(_wrap(baseStyle: const TextStyle(fontSize: 22.0)));
      await tester.pump();

      expect(verticalHitRegionScheduleCount, greaterThan(0),
          reason: 'a font-size change moves character rects');
    });

    testWidgets('column spacing change reschedules the hit-region rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(columnSpacing: 8.0));
      await tester.pumpAndSettle();
      verticalHitRegionScheduleCount = 0;

      await tester.pumpWidget(_wrap(columnSpacing: 20.0));
      await tester.pump();

      expect(verticalHitRegionScheduleCount, greaterThan(0),
          reason: 'a column-spacing change moves character rects');
    });
  });

  group('F116: rendering output is unchanged by memoization', () {
    Color? bg(WidgetTester tester, String ch) =>
        tester.widget<Text>(find.text(ch)).style?.backgroundColor;

    testWidgets('mark decoration survives selection/TTS rebuilds', (
      tester,
    ) async {
      // Marked chars are wrapped in a CustomPaint (the mark sidebar). Only
      // marked chars get one, so its presence is a reliable mark indicator.
      int markPaintCount(String ch) => find
          .ancestor(of: find.text(ch), matching: find.byType(CustomPaint))
          .evaluate()
          .length;

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // A marked char carries one extra CustomPaint (the mark sidebar) versus
      // an unmarked char that only shares the common page-level CustomPaint.
      expect(markPaintCount('ア'), markPaintCount('歩') + 1,
          reason: 'marked char "ア" should have a mark sidebar, "歩" should not');

      await tester.pumpWidget(_wrap(
        selectionStart: 7,
        selectionEnd: 9,
        ttsHighlightStart: 0,
        ttsHighlightEnd: 1,
      ));
      await tester.pump();

      // The memoized mark map must keep exactly the same chars marked.
      expect(markPaintCount('ア'), markPaintCount('歩') + 1);
    });

    testWidgets('selection and TTS highlight backgrounds render correctly '
        'after a memoized rebuild', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.pumpWidget(_wrap(
        selectionStart: 0,
        selectionEnd: 2,
        ttsHighlightStart: 3,
        ttsHighlightEnd: 4,
      ));
      await tester.pump();

      // Selected chars get a blue background; the rest do not.
      expect(bg(tester, 'ア'), Colors.blue.withValues(alpha: 0.3));
      // A non-selected, non-TTS char has no background.
      expect(bg(tester, '走'), isNull);
    });
  });
}
