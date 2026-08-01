import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_edit_segment.dart';
import 'package:novel_viewer/features/tts/presentation/tts_edit_segment_list.dart';
import 'package:novel_viewer/features/tts/presentation/tts_edit_segment_row.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  const viewportHeight = 300.0;

  List<TtsEditSegment> buildSegments(int count) => List.generate(count, (i) {
        final text = 'セグメント$i。';
        return TtsEditSegment(
          segmentIndex: i,
          originalText: text,
          text: text,
          textOffset: i * text.length,
          textLength: text.length,
          hasAudio: true,
        );
      });

  /// Pumps the list in a viewport short enough that most rows are off-screen.
  Future<void> pumpList(
    WidgetTester tester, {
    required int count,
    required int cursorIndex,
    bool isPlaying = false,
    void Function(int index)? onCursorChanged,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      LocalizedMaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1000,
              height: viewportHeight,
              child: TtsEditSegmentList(
                segments: buildSegments(count),
                isGenerating: false,
                generatingIndex: null,
                isPlaying: isPlaying,
                cursorIndex: cursorIndex,
                voiceFiles: const [],
                onTextEditComplete: (_, _) {},
                onRefWavPathChanged: (_, _) {},
                onMemoEditComplete: (_, _) {},
                onPlay: (_) {},
                onGenerate: (_) {},
                onReset: (_) {},
                onCursorChanged: onCursorChanged ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Walks the playhead from the first row up to [upTo] one segment at a time,
  /// the way playback advances it. A direct jump would be a different case:
  /// the target row would be too far off-screen for the list to have built it.
  Future<void> playThrough(
    WidgetTester tester, {
    required int count,
    required int upTo,
  }) async {
    for (var i = 0; i <= upTo; i++) {
      await pumpList(tester, count: count, cursorIndex: i);
    }
  }

  Finder findRow(int index) => find.byWidgetPredicate(
      (w) => w is TtsEditSegmentRow && w.segment.segmentIndex == index);

  // Every TextField carries a Scrollable of its own, so the list's has to be
  // picked out: it is the outermost, and finders walk depth-first.
  double scrollOffset(WidgetTester tester) => tester
      .state<ScrollableState>(find
          .descendant(
            of: find.byType(TtsEditSegmentList),
            matching: find.byType(Scrollable),
          )
          .first)
      .position
      .pixels;

  /// Whether row [index] is built and lies entirely inside the viewport.
  bool rowIsVisible(WidgetTester tester, int index) {
    final row = findRow(index);
    if (row.evaluate().isEmpty) return false;
    final rowRect = tester.getRect(row);
    final viewRect = tester.getRect(find.byType(TtsEditSegmentList));
    return rowRect.top >= viewRect.top - 0.5 &&
        rowRect.bottom <= viewRect.bottom + 0.5;
  }

  group('TtsEditSegmentList playhead ownership', () {
    testWidgets('a row press moves the playhead while nothing is playing',
        (tester) async {
      final moves = <int>[];
      await pumpList(
        tester,
        count: 30,
        cursorIndex: 0,
        onCursorChanged: moves.add,
      );

      await tester.tap(findRow(2));
      await tester.pump();

      expect(moves, [2]);
    });

    testWidgets('a row press is ignored while playback is running',
        (tester) async {
      // Playback owns the playhead for its duration. Honouring the press too
      // would let the user's index and the next onSegmentStart fight over the
      // same value, and the highlight would jump between them.
      final moves = <int>[];
      await pumpList(
        tester,
        count: 30,
        cursorIndex: 0,
        isPlaying: true,
        onCursorChanged: moves.add,
      );

      await tester.tap(findRow(2));
      await tester.pump();

      expect(moves, isEmpty);
    });

    testWidgets('row actions are disabled while playback is running',
        (tester) async {
      // A row's play button would otherwise clear the playing flag when its
      // segment finished, releasing the playhead lock while the play-through
      // it interrupted is still running.
      await pumpList(tester, count: 30, cursorIndex: 0, isPlaying: true);

      final buttons = tester.widgetList<IconButton>(
        find.descendant(of: findRow(0), matching: find.byType(IconButton)),
      );
      expect(buttons, isNotEmpty);
      expect(buttons.every((b) => b.onPressed == null), true);
    });

    testWidgets('row actions are available while nothing is playing',
        (tester) async {
      await pumpList(tester, count: 30, cursorIndex: 0);

      final buttons = tester.widgetList<IconButton>(
        find.descendant(of: findRow(0), matching: find.byType(IconButton)),
      );
      expect(buttons, isNotEmpty);
      expect(buttons.every((b) => b.onPressed != null), true);
    });

    testWidgets('editing still works while playback is running',
        (tester) async {
      await pumpList(tester, count: 30, cursorIndex: 0, isPlaying: true);

      await tester.tap(findRow(1));
      await tester.pump();

      final editable = tester.widgetList<EditableText>(find.descendant(
        of: findRow(1),
        matching: find.byType(EditableText),
      ));
      expect(editable.any((e) => e.focusNode.hasFocus), true);
    });
  });

  group('TtsEditSegmentList auto-scroll', () {
    testWidgets('follows the playhead when it moves below the viewport',
        (tester) async {
      await pumpList(tester, count: 30, cursorIndex: 0);
      expect(rowIsVisible(tester, 8), false,
          reason: 'row 8 must start off-screen for this to test anything');

      await pumpList(tester, count: 30, cursorIndex: 8);

      expect(rowIsVisible(tester, 8), true);
    });

    testWidgets('stays put when the playhead moves within the viewport',
        (tester) async {
      await pumpList(tester, count: 30, cursorIndex: 0);
      final before = scrollOffset(tester);
      expect(rowIsVisible(tester, 1), true);

      await pumpList(tester, count: 30, cursorIndex: 1);

      // A user reading elsewhere during playback must not be yanked back for a
      // row that is already on screen.
      expect(scrollOffset(tester), before);
    });

    testWidgets('scrolls back when the playhead moves above the viewport',
        (tester) async {
      await playThrough(tester, count: 30, upTo: 12);
      final scrolledDown = scrollOffset(tester);
      expect(scrolledDown, greaterThan(0));

      await pumpList(tester, count: 30, cursorIndex: 7);

      expect(scrollOffset(tester), lessThan(scrolledDown));
      expect(rowIsVisible(tester, 7), true);
    });

    testWidgets('returns to the top when the playhead resets to the first row',
        (tester) async {
      // The reset happens when playback runs off the end, so the first row is
      // by then far above the viewport and no longer built.
      await playThrough(tester, count: 30, upTo: 12);
      expect(scrollOffset(tester), greaterThan(0));
      expect(findRow(0).evaluate(), isEmpty);

      await pumpList(tester, count: 30, cursorIndex: 0);

      expect(scrollOffset(tester), 0);
    });
  });
}
