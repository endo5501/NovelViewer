import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/data/text_segmenter.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// End-to-end check of the playback start position: a selection in the viewer
/// must resolve, through the offset stored in `selectedTextProvider` and the
/// real `TextSegmenter`, to the sentence the user actually selected.
///
/// This is the contract the old `indexOf`-based code broke. `TtsControlsBar`
/// builds its `TtsStreamingController` internally, so instead of adding a
/// test-only seam to observe `start(startOffset:)`, this exercises the two
/// halves the controller sits between: the offset the viewer reports, and the
/// segment `startSegmentIndexForOffset` picks for it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> pumpRenderer(
    WidgetTester tester,
    String content,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: 900,
              width: 900,
              child: TextContentRenderer(content: content),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(TextContentRenderer));
    return ProviderScope.containerOf(element);
  }

  void reportSelection(WidgetTester tester, int start, int end) {
    tester.widget<SelectableText>(find.byType(SelectableText)).
        onSelectionChanged!(
      TextSelection(baseOffset: start, extentOffset: end),
      SelectionChangedCause.drag,
    );
  }

  /// Ruby-dense content: the raw string is far longer than what is displayed,
  /// which is exactly what used to push the start offset past the end.
  const rubyContent =
      '<ruby>魔法<rp>《</rp><rt>まほう</rt><rp>》</rp></ruby>の朝だ。'
      '<ruby>少年<rp>《</rp><rt>しょうねん</rt><rp>》</rp></ruby>は走った。'
      '<ruby>森<rp>《</rp><rt>もり</rt><rp>》</rp></ruby>は静かだ。'
      '最後の文です。';
  // Displayed text: 魔法の朝だ。少年は走った。森は静かだ。最後の文です。
  // Segments:       [0]魔法の朝だ。 [1]少年は走った。 [2]森は静かだ。
  //                 [3]最後の文です。

  testWidgets('selection resolves to the segment the user selected',
      (tester) async {
    final container = await pumpRenderer(tester, rubyContent);
    final segments = const TextSegmenter().splitIntoSentences(rubyContent);
    expect(segments, hasLength(4));

    // Display offsets: [ruby 魔法](0) の(1) 朝(2) だ(3) 。(4)
    //                  [ruby 少年](5) は(6) 走(7) っ(8) た(9) 。(10)
    // Select "は走った。" — inside segment 1.
    reportSelection(tester, 6, 11);
    await tester.pump();

    final offset = container.read(selectedTextProvider)!.plainTextOffset;
    expect(startSegmentIndexForOffset(segments, offset), 1);
  });

  testWidgets('selection near the end does not collapse onto the last segment',
      (tester) async {
    final container = await pumpRenderer(tester, rubyContent);
    final segments = const TextSegmenter().splitIntoSentences(rubyContent);

    // Display offsets: [ruby 森](11) は(12) 静(13) か(14) だ(15) 。(16)
    // Select "は静かだ。" — inside segment 2, the second-to-last sentence.
    reportSelection(tester, 12, 17);
    await tester.pump();

    final offset = container.read(selectedTextProvider)!.plainTextOffset;
    expect(startSegmentIndexForOffset(segments, offset), 2,
        reason: 'ruby markup must not push the start onto the final segment');
    expect(startSegmentIndexForOffset(segments, offset),
        isNot(segments.length - 1));
  });

  testWidgets('a raw-content offset would have resolved to the wrong segment',
      (tester) async {
    // Pins the regression: feeding the raw-content position of the same text
    // into the resolver lands on a later segment than the correct one.
    final container = await pumpRenderer(tester, rubyContent);
    final segments = const TextSegmenter().splitIntoSentences(rubyContent);

    reportSelection(tester, 6, 11);
    await tester.pump();

    final selection = container.read(selectedTextProvider)!;
    final correct = startSegmentIndexForOffset(
      segments,
      selection.plainTextOffset,
    );
    final rawOffset = rubyContent.indexOf(selection.text);
    expect(rawOffset, greaterThanOrEqualTo(0));
    final viaRawContent = startSegmentIndexForOffset(segments, rawOffset);

    expect(correct, 1);
    expect(viaRawContent, greaterThan(correct),
        reason: 'the old indexOf-on-raw-content path overshot the selection');
  });

  testWidgets('a repeated word resolves to the occurrence that was selected',
      (tester) async {
    // Independent of ruby: searching the selected text in the content finds
    // the FIRST occurrence, so selecting a later one used to start playback
    // from the earlier sentence. Nothing is searched any more, and this pins
    // that a reintroduced lookup would be caught.
    const content = 'そうだね。あとでそうしよう。';
    // Offsets:  そ0 う1 だ2 ね3 。4 あ5 と6 で7 そ8 う9 し10 よ11 う12 。13
    // Segments: [0] "そうだね。" @0   [1] "あとでそうしよう。" @5
    final container = await pumpRenderer(tester, content);
    final segments = const TextSegmenter().splitIntoSentences(content);
    expect(segments, hasLength(2));

    // Select the SECOND "そう", at offset 8.
    reportSelection(tester, 8, 10);
    await tester.pump();

    final selection = container.read(selectedTextProvider)!;
    expect(selection.text, 'そう');
    expect(selection.plainTextOffset, 8);
    expect(startSegmentIndexForOffset(segments, selection.plainTextOffset), 1);
    // The first occurrence would have resolved to segment 0.
    expect(content.indexOf(selection.text), 0);
    expect(startSegmentIndexForOffset(segments, content.indexOf(selection.text)),
        0);
  });

  testWidgets('no selection starts from the first segment', (tester) async {
    final container = await pumpRenderer(tester, rubyContent);
    final segments = const TextSegmenter().splitIntoSentences(rubyContent);

    expect(container.read(selectedTextProvider), isNull);
    final offset = container.read(selectedTextProvider)?.plainTextOffset;
    expect(startSegmentIndexForOffset(segments, offset), 0);
  });

  testWidgets('selection containing ruby still resolves to its own segment',
      (tester) async {
    // The old code searched the base-expanded selection in the raw content,
    // so any selection spanning ruby returned -1 and playback restarted from
    // the top.
    final container = await pumpRenderer(tester, rubyContent);
    final segments = const TextSegmenter().splitIntoSentences(rubyContent);

    // Select "森は静かだ。" starting on the ruby WidgetSpan at display 11.
    reportSelection(tester, 11, 17);
    await tester.pump();

    final selection = container.read(selectedTextProvider)!;
    expect(selection.text, startsWith('森'));
    expect(rubyContent.contains(selection.text), isFalse,
        reason: 'the selection spans ruby, so it is absent from raw content');
    expect(startSegmentIndexForOffset(segments, selection.plainTextOffset), 2);
  });
}
