import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/data/vertical_marked_ranges.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(width: 200, height: 300, child: child),
      ),
    );

void main() {
  setUp(() => computeMarkedRangesCallCount = 0);

  group('F117: single mark scan per build', () {
    testWidgets('a single build scans the mark buffer exactly once', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const VerticalTextPage(
        segments: [PlainTextSegment('アリスが歩く')],
        baseStyle: TextStyle(fontSize: 14.0),
        markedWords: {'アリス': MarkStyle.solid},
      )));

      // Before F117 the page ran two buffer scans per build
      // (computeMarkedEntries + computeMarkedRanges). It must now run one.
      expect(computeMarkedRangesCallCount, 1);
    });

    testWidgets('a mark-input change re-scans exactly once, never twice', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const VerticalTextPage(
        segments: [PlainTextSegment('アリスが歩く')],
        baseStyle: TextStyle(fontSize: 14.0),
        markedWords: {'アリス': MarkStyle.solid},
      )));

      computeMarkedRangesCallCount = 0;

      // Changing the marked words legitimately invalidates the F116 memo, so
      // the buffer is rescanned — but F117 guarantees a single scan, not the
      // old two-pass (computeMarkedEntries + computeMarkedRanges).
      await tester.pumpWidget(_wrap(const VerticalTextPage(
        segments: [PlainTextSegment('アリスが歩く')],
        baseStyle: TextStyle(fontSize: 14.0),
        markedWords: {'歩く': MarkStyle.solid},
      )));

      expect(computeMarkedRangesCallCount, 1);
    });
  });
}
