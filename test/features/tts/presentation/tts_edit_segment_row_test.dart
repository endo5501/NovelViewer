import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_edit_segment.dart';
import 'package:novel_viewer/features/tts/presentation/tts_edit_segment_row.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  const originalText = 'セグメントの本文です。';

  TtsEditSegment buildSegment({String? memo}) {
    return TtsEditSegment(
      segmentIndex: 0,
      originalText: originalText,
      text: originalText,
      textOffset: 0,
      textLength: originalText.length,
      memo: memo,
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
    void Function(String? memo)? onMemoEditComplete,
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
                segment: buildSegment(memo: memo),
                isGenerating: false,
                isPlaying: false,
                voiceFiles: const [],
                onTextEditComplete: (_) {},
                onRefWavPathChanged: (_) {},
                onMemoEditComplete: onMemoEditComplete ?? (_) {},
                onPlay: () {},
                onGenerate: () {},
                onReset: () {},
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
}
