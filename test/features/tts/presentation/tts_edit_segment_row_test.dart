import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_edit_segment.dart';
import 'package:novel_viewer/features/tts/presentation/tts_edit_segment_row.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  const originalText = 'セグメントの本文です。';

  TtsEditSegment buildSegment({String? memo, bool hasAudio = false}) {
    return TtsEditSegment(
      segmentIndex: 0,
      originalText: originalText,
      text: originalText,
      textOffset: 0,
      textLength: originalText.length,
      memo: memo,
      hasAudio: hasAudio,
    );
  }

  /// Pumps a single row inside a box of [rowWidth] so the flex layout can be
  /// measured at a known available width.
  ///
  /// The surface is widened along with the row: the default 800x600 test
  /// surface would silently clamp any wider row and make different widths
  /// measure the same.
  Future<void> pumpRow(
    WidgetTester tester, {
    required double rowWidth,
    String? memo,
    bool hasAudio = false,
    bool isCursor = false,
    bool isPlaying = false,
    void Function(String? memo)? onMemoEditComplete,
    VoidCallback? onCursorRequested,
  }) async {
    await tester.binding.setSurfaceSize(Size(rowWidth + 100, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      LocalizedMaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: rowWidth,
              child: TtsEditSegmentRow(
                segment: buildSegment(memo: memo, hasAudio: hasAudio),
                isGenerating: false,
                isPlaying: isPlaying,
                isCursor: isCursor,
                voiceFiles: const [],
                onTextEditComplete: (_) {},
                onRefWavPathChanged: (_) {},
                onMemoEditComplete: onMemoEditComplete ?? (_) {},
                onPlay: () {},
                onGenerate: () {},
                onReset: () {},
                onCursorRequested: onCursorRequested ?? () {},
                enabled: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The two text fields are told apart by their hint text: the body field hints
  // with the segment's original text, the memo field with the localized label.
  Finder findBodyField() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == originalText);

  Finder findMemoField() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'メモ');

  group('TtsEditSegmentRow width distribution', () {
    testWidgets('body and memo share the free space at a 5:2 ratio',
        (tester) async {
      await pumpRow(tester, rowWidth: 1000);

      final bodyWidth = tester.getSize(findBodyField()).width;
      final memoWidth = tester.getSize(findMemoField()).width;

      expect(memoWidth, closeTo(bodyWidth * 2 / 5, 1.0));
      expect(bodyWidth, greaterThan(memoWidth));
      // Guards against the old fixed SizedBox(width: 100).
      expect(memoWidth, greaterThan(100));
    });

    testWidgets('both fields grow when the row gets wider', (tester) async {
      await pumpRow(tester, rowWidth: 900);
      final narrowBody = tester.getSize(findBodyField()).width;
      final narrowMemo = tester.getSize(findMemoField()).width;

      await pumpRow(tester, rowWidth: 1300);
      final wideBody = tester.getSize(findBodyField()).width;
      final wideMemo = tester.getSize(findMemoField()).width;

      expect(wideBody, greaterThan(narrowBody));
      expect(wideMemo, greaterThan(narrowMemo));
    });

    testWidgets('memo keeps shrinking with the body, with no minimum width',
        (tester) async {
      await pumpRow(tester, rowWidth: 700);

      final bodyWidth = tester.getSize(findBodyField()).width;
      final memoWidth = tester.getSize(findMemoField()).width;

      // A minimum-width clamp on the memo would break the 5:2 ratio here.
      expect(memoWidth, closeTo(bodyWidth * 2 / 5, 1.0));
    });
  });

  group('TtsEditSegmentRow memo wrapping', () {
    const longMemo = '落ち着いた女性の声で、ゆっくりと悲しげに読み上げてください';
    final veryLongMemo = longMemo * 5;

    testWidgets('a memo too long for one line wraps to a second line',
        (tester) async {
      await pumpRow(tester, rowWidth: 1000);
      final emptyHeight = tester.getSize(findMemoField()).height;

      await pumpRow(tester, rowWidth: 1000, memo: longMemo);
      final wrappedHeight = tester.getSize(findMemoField()).height;

      expect(wrappedHeight, greaterThan(emptyHeight));
    });

    testWidgets('memo growth stops at two lines', (tester) async {
      await pumpRow(tester, rowWidth: 1000, memo: longMemo);
      final wrappedHeight = tester.getSize(findMemoField()).height;

      await pumpRow(tester, rowWidth: 1000, memo: veryLongMemo);
      final overflowingHeight = tester.getSize(findMemoField()).height;

      expect(overflowingHeight, wrappedHeight);
    });

    testWidgets('Enter still commits the memo instead of inserting a newline',
        (tester) async {
      // Wrapping the memo made the field multiline, which by default turns
      // Enter into a newline. The memo feeds the Irodori caption, so Enter must
      // keep committing the value as it did when the field was single-line.
      String? committed;
      var callCount = 0;
      await pumpRow(
        tester,
        rowWidth: 1000,
        onMemoEditComplete: (memo) {
          committed = memo;
          callCount++;
        },
      );

      // A multiline field defaults to TextInputAction.newline, which makes
      // Enter insert a line break and never fire onSubmitted. Declaring `done`
      // is what keeps Enter committing.
      expect(
        tester.widget<TextField>(findMemoField()).textInputAction,
        TextInputAction.done,
      );

      await tester.enterText(findMemoField(), 'ゆっくり悲しげに');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(callCount, 1);
      expect(committed, 'ゆっくり悲しげに');
      expect(
        tester.widget<TextField>(findMemoField()).controller!.text,
        isNot(contains('\n')),
      );
    });

    testWidgets('an empty memo keeps the single-line height', (tester) async {
      await pumpRow(tester, rowWidth: 1000);
      final emptyHeight = tester.getSize(findMemoField()).height;

      await pumpRow(tester, rowWidth: 1000, memo: '速く');
      final shortHeight = tester.getSize(findMemoField()).height;

      expect(emptyHeight, shortHeight);
    });
  });

  group('TtsEditSegmentRow playhead requests', () {
    // Pressing anywhere in the row claims the playhead, so the segment the user
    // just edited is the one playback starts from — whichever part of the row
    // they happened to touch.
    testWidgets('pressing the body field requests the playhead', (tester) async {
      var requests = 0;
      await pumpRow(tester, rowWidth: 1000, onCursorRequested: () => requests++);

      await tester.tap(findBodyField());
      await tester.pump();

      expect(requests, 1);
    });

    testWidgets('pressing the memo field requests the playhead', (tester) async {
      var requests = 0;
      await pumpRow(tester, rowWidth: 1000, onCursorRequested: () => requests++);

      await tester.tap(findMemoField());
      await tester.pump();

      expect(requests, 1);
    });

    testWidgets('pressing the reference audio selector requests the playhead',
        (tester) async {
      var requests = 0;
      await pumpRow(tester, rowWidth: 1000, onCursorRequested: () => requests++);

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pump();

      expect(requests, 1);

      // Close the menu the tap opened so the test tears down cleanly.
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    });

    testWidgets('pressing an action button requests the playhead',
        (tester) async {
      var requests = 0;
      await pumpRow(
        tester,
        rowWidth: 1000,
        hasAudio: true,
        onCursorRequested: () => requests++,
      );

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.restart_alt));
      await tester.pump();

      expect(requests, 3);
    });

    testWidgets('pressing the body field still focuses it', (tester) async {
      // The playhead is claimed by observing pointers, not by consuming them:
      // editing must work exactly as before.
      await pumpRow(tester, rowWidth: 1000);

      await tester.tap(findBodyField());
      await tester.pump();

      final editable =
          tester.state<EditableTextState>(find.byType(EditableText).first);
      expect(editable.widget.focusNode.hasFocus, true);
    });
  });

  group('TtsEditSegmentRow playhead highlight', () {
    List<Color> highlightColors(WidgetTester tester) => tester
        .widgetList<ColoredBox>(find.descendant(
          of: find.byType(TtsEditSegmentRow),
          matching: find.byType(ColoredBox),
        ))
        .map((box) => box.color)
        .where((color) => color.a > 0)
        .toList();

    testWidgets('the playhead row is given a background', (tester) async {
      await pumpRow(tester, rowWidth: 1000, isCursor: true);

      expect(highlightColors(tester), isNotEmpty);
    });

    testWidgets('other rows are not', (tester) async {
      await pumpRow(tester, rowWidth: 1000, isCursor: false);

      expect(highlightColors(tester), isEmpty);
    });

    testWidgets('the highlight shows without the speaker icon when idle',
        (tester) async {
      // The background means "playback starts here"; the speaker icon means
      // "sound is coming out now". A stopped playhead shows only the former.
      await pumpRow(tester, rowWidth: 1000, isCursor: true, isPlaying: false);

      expect(highlightColors(tester), isNotEmpty);
      expect(find.byIcon(Icons.volume_up), findsNothing);
    });

    testWidgets('both appear while the playhead row is playing', (tester) async {
      await pumpRow(tester, rowWidth: 1000, isCursor: true, isPlaying: true);

      expect(highlightColors(tester), isNotEmpty);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
    });
  });
}
