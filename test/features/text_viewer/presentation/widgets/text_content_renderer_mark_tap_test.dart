import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/marked_words_provider.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tap on a marked word has to reach the popup state, in both display
/// modes. The two viewers resolve the tapped character by completely
/// different routes, so each needs the whole path exercised: nothing below
/// the renderer knows that a popup exists.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const content = '昨日アリスが来た。';
  // Long enough to have somewhere to scroll to, with a landmark near the end.
  final long = '$content\n${'あ\n' * 200}目印';
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpContent(
    WidgetTester tester,
    String text, {
    Map<String, MarkStyle> marks = const {'アリス': MarkStyle.solid},
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
          markedWordsProvider.overrideWithValue(marks),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: TextContentRenderer(content: text),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> pumpRenderer(
    WidgetTester tester, {
    TextDisplayMode mode = TextDisplayMode.horizontal,
    Map<String, MarkStyle> marks = const {'アリス': MarkStyle.solid},
    String text = content,
  }) async {
    await pumpContent(tester, text, marks: marks);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TextContentRenderer)),
    );
    if (mode == TextDisplayMode.vertical) {
      await container.read(displayModeProvider.notifier).setMode(mode);
      await tester.pumpAndSettle();
    }
    return container;
  }

  /// The global centre of the character at [index] of the horizontal text,
  /// taken from the laid-out paragraph rather than guessed at. A character
  /// spans the gap between the caret before it and the caret after it.
  Offset characterCentre(WidgetTester tester, int index) {
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    Offset caret(int offset) =>
        editable.getLocalRectForCaret(TextPosition(offset: offset)).center;
    final local = (caret(index) + caret(index + 1)) / 2;
    return editable.localToGlobal(local);
  }

  /// A point [fraction] of the way across the character at [index], so a
  /// test can aim at the half of a glyph a reader would.
  Offset withinCharacter(WidgetTester tester, int index, double fraction) {
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    Offset caret(int offset) =>
        editable.getLocalRectForCaret(TextPosition(offset: offset)).center;
    final a = caret(index);
    final b = caret(index + 1);
    return editable.localToGlobal(a + (b - a) * fraction);
  }

  Future<void> tapCharacter(WidgetTester tester, int index) async {
    await tester.tapAt(characterCentre(tester, index));
    // Past the double-tap window, so consecutive taps in a test are read as
    // separate taps rather than as a word-selecting double tap.
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
  }

  group('horizontal mode', () {
    testWidgets('a touch tap on a marked word shows the popup', (tester) async {
      final container = await pumpRenderer(tester);

      await tapCharacter(tester, content.indexOf('リ'));
      await tester.pump();

      final state = container.read(hoverPopupProvider);
      expect(state.isVisible, isTrue);
      expect(state.word, 'アリス');
    });

    testWidgets('a touch tap on unmarked text shows nothing', (tester) async {
      final container = await pumpRenderer(tester);

      await tapCharacter(tester, content.indexOf('昨'));
      await tester.pump();

      expect(container.read(hoverPopupProvider).isVisible, isFalse);
    });

    testWidgets('a tap resolved to a word edge still opens the popup', (
      tester,
    ) async {
      // On iOS a touch tap does not place the caret where the finger landed:
      // it snaps to the nearest word edge, which for a word at the end of a
      // run is one position past the last character of its mark.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final container = await pumpRenderer(tester);

        await tapCharacter(tester, content.indexOf('ス'));
        await tester.pump();

        final state = container.read(hoverPopupProvider);
        expect(state.isVisible, isTrue);
        expect(state.word, 'アリス');
      } finally {
        // Reset inside the body: the binding checks for a leaked debug
        // override before tear-downs run.
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('tapping the same word again after a dismissal reopens it', (
      tester,
    ) async {
      // A tap that lands where the caret already is changes no selection, so
      // none is reported. Resolving from the last caret rather than only
      // from the notification is what keeps the second tap working; the
      // check that it came from the same place is what stops an unrelated
      // gesture elsewhere from claiming it.
      final container = await pumpRenderer(tester);

      await tapCharacter(tester, content.indexOf('リ'));
      await tester.pump();
      expect(container.read(hoverPopupProvider).isVisible, isTrue);

      container.read(hoverPopupProvider.notifier).hide();
      await tester.pump();

      await tapCharacter(tester, content.indexOf('リ'));
      await tester.pump();

      expect(container.read(hoverPopupProvider).isVisible, isTrue);
      expect(container.read(hoverPopupProvider).word, 'アリス');
    });

    testWidgets('tapping another marked word switches the popup to it', (
      tester,
    ) async {
      // The touch that takes the first popup down is the same one that opens
      // the second: the barrier only watches, so the press still reaches the
      // word underneath it.
      final container = await pumpRenderer(
        tester,
        text: 'アリスはボブと歩く。',
        marks: const {'アリス': MarkStyle.solid, 'ボブ': MarkStyle.solid},
      );

      await tapCharacter(tester, 1);
      await tester.pump();
      expect(container.read(hoverPopupProvider).word, 'アリス');

      await tapCharacter(tester, 5);
      await tester.pump();

      expect(container.read(hoverPopupProvider).word, 'ボブ');
    });

    testWidgets('a stylus tap on a marked word shows the popup', (
      tester,
    ) async {
      final container = await pumpRenderer(tester);

      final stylus = await tester.createGesture(kind: PointerDeviceKind.stylus);
      await stylus.down(characterCentre(tester, content.indexOf('リ')));
      await stylus.up();
      await tester.pump(kDoubleTapTimeout);

      expect(container.read(hoverPopupProvider).word, 'アリス');

      // A stylus hovers as well as touches, so it is still over the word.
      // Taking it away here keeps the exit that follows inside the test.
      await stylus.removePointer();
      await tester.pump();
    });

    testWidgets('a second tap in quick succession does not reuse the first', (
      tester,
    ) async {
      // A tap that follows another closely enough is a double tap, which
      // reports its selection under a different cause and so leaves the
      // remembered caret untouched. Resolving that caret anyway would put
      // the first tap's word on screen at the second tap's position.
      final container = await pumpRenderer(tester);

      await tester.tapAt(characterCentre(tester, content.indexOf('リ')));
      await tester.pump(const Duration(milliseconds: 40));
      expect(container.read(hoverPopupProvider).isVisible, isTrue);

      await tester.tapAt(characterCentre(tester, content.indexOf('来')));
      await tester.pump(kDoubleTapTimeout);

      expect(container.read(hoverPopupProvider).isVisible, isFalse);
    });

    testWidgets('a touch that lands on a popup-owned menu is not resolved', (
      tester,
    ) async {
      // The re-analysis dropdown floats over the text. A touch on one of its
      // items must not also be read as a tap on whatever is underneath it,
      // which would dismiss the popup the menu belongs to, or open the
      // summary for some unrelated word the item happened to cover.
      final container = await pumpRenderer(tester);

      await tapCharacter(tester, content.indexOf('リ'));
      await tester.pump();
      expect(container.read(hoverPopupProvider).isVisible, isTrue);

      container.read(hoverPopupProvider.notifier).onChildMenuOpen();
      await tester.pump();

      await tapCharacter(tester, content.indexOf('昨'));
      await tester.pump();

      expect(container.read(hoverPopupProvider).isVisible, isTrue);
    });

    testWidgets('a mouse click leaves the popup under hover control', (
      tester,
    ) async {
      // A mouse opens the popup by hovering, and hover owns the dismissal
      // too. If a click also went through the touch path it would replace
      // the state with a token the hover exit does not recognise, and the
      // popup would be stranded when the pointer moved away.
      final container = await pumpRenderer(tester);

      final onWord = characterCentre(tester, content.indexOf('リ'));
      final offWord = characterCentre(tester, content.indexOf('昨'));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: offWord);
      addTearDown(mouse.removePointer);
      await tester.pump();

      await mouse.moveTo(onWord);
      await tester.pump();
      expect(
        container.read(hoverPopupProvider).isVisible,
        isTrue,
        reason: 'hover still opens the popup',
      );

      await mouse.down(onWord);
      await mouse.up();
      await tester.pump();

      await mouse.moveTo(offWord);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        container.read(hoverPopupProvider).isVisible,
        isFalse,
        reason: 'the hover exit still dismisses what hover opened',
      );
    });
  });

  group('horizontal mode, resolving which character was touched', () {
    // A caret position sits between two characters, so the offset a tap
    // reports names a boundary rather than a glyph. Which side of it the
    // finger landed on is what decides the answer, and getting it wrong
    // opens the neighbouring word.
    const adjacent = 'アリスボブが来た。';
    const bothMarked = {'アリス': MarkStyle.solid, 'ボブ': MarkStyle.solid};

    testWidgets('the far half of a word opens that word, not the next one', (
      tester,
    ) async {
      final container = await pumpRenderer(
        tester,
        text: adjacent,
        marks: bothMarked,
      );

      // The right-hand side of the last character of "アリス", which reports
      // the boundary it shares with the start of "ボブ".
      await tester.tapAt(withinCharacter(tester, 2, 0.8));
      await tester.pump(kDoubleTapTimeout);

      expect(container.read(hoverPopupProvider).word, 'アリス');
    });

    testWidgets('the near half of the next word opens the next word', (
      tester,
    ) async {
      final container = await pumpRenderer(
        tester,
        text: adjacent,
        marks: bothMarked,
      );

      await tester.tapAt(withinCharacter(tester, 3, 0.2));
      await tester.pump(kDoubleTapTimeout);

      expect(container.read(hoverPopupProvider).word, 'ボブ');
    });

    testWidgets('the character after a mark opens nothing', (tester) async {
      final container = await pumpRenderer(
        tester,
        text: adjacent,
        marks: const {'アリス': MarkStyle.solid},
      );

      await tester.tapAt(withinCharacter(tester, 3, 0.2));
      await tester.pump(kDoubleTapTimeout);

      expect(container.read(hoverPopupProvider).isVisible, isFalse);
    });
  });

  group('horizontal mode, after a content swap', () {
    testWidgets('a tap cannot open a summary from the previous file', (
      tester,
    ) async {
      // The marks a tap is resolved against belong to the text they were
      // found in. Held across a file switch they would name positions in
      // text that is no longer on screen, and a tap anywhere near one of
      // them would open a summary for a word the reader cannot see.
      final container = await pumpRenderer(tester);

      await tapCharacter(tester, content.indexOf('リ'));
      await tester.pump();
      expect(container.read(hoverPopupProvider).isVisible, isTrue);

      container.read(hoverPopupProvider.notifier).hide();
      await pumpContent(tester, 'まったく別の本文です。');

      await tapCharacter(tester, 2);
      await tester.pump();

      expect(container.read(hoverPopupProvider).isVisible, isFalse);
    });
  });

  group('horizontal scrolling', () {
    // The popup is anchored where it opened, so text scrolling out from under
    // it leaves it pointing at nothing. Vertical mode already drops the popup
    // on a page turn for the same reason.
    testWidgets('a scroll the reader drives dismisses the popup', (
      tester,
    ) async {
      final container = await pumpRenderer(
        tester,
        // Long enough to have somewhere to scroll to.
        text: long,
      );

      await tapCharacter(tester, content.indexOf('リ'));
      await tester.pump();
      expect(container.read(hoverPopupProvider).isVisible, isTrue);

      // From a glyph, so the drag starts on the same subtree a tap does.
      await tester.dragFrom(
        characterCentre(tester, content.indexOf('リ')),
        const Offset(0, -120),
      );
      await tester.pump();

      expect(container.read(hoverPopupProvider).isVisible, isFalse);
    });

    testWidgets('lifting the finger after a scroll does not reopen it', (
      tester,
    ) async {
      // The drag ends with a pointer-up over the text, exactly as a tap does.
      // Read as a tap it would resolve the offset the earlier tap left behind
      // and put the old word back on screen, anchored wherever the finger
      // happened to stop.
      final container = await pumpRenderer(tester, text: long);

      await tapCharacter(tester, content.indexOf('リ'));
      await tester.pump();
      expect(container.read(hoverPopupProvider).isVisible, isTrue);

      await tester.dragFrom(
        characterCentre(tester, content.indexOf('リ')),
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();

      expect(container.read(hoverPopupProvider).isVisible, isFalse);
    });

    testWidgets('the speech-following scroll leaves the popup alone', (
      tester,
    ) async {
      // The reader did not move the text, so the summary they opened stays.
      final container = await pumpRenderer(tester, text: long);

      await tapCharacter(tester, content.indexOf('リ'));
      await tester.pump();
      expect(container.read(hoverPopupProvider).isVisible, isTrue);

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollView.controller!.offset, 0.0);

      // The real path: a new highlight makes the viewer scroll to it.
      final target = long.indexOf('目印');
      container
          .read(ttsHighlightRangeProvider.notifier)
          .set(TextRange(start: target, end: target + 2));
      await tester.pumpAndSettle();

      expect(scrollView.controller!.offset, greaterThan(0.0));
      expect(container.read(hoverPopupProvider).isVisible, isTrue);
    });
  });

  group('vertical mode', () {
    testWidgets('a touch tap on a marked character shows the popup', (
      tester,
    ) async {
      final container = await pumpRenderer(
        tester,
        mode: TextDisplayMode.vertical,
      );

      await tester.tapAt(tester.getCenter(find.text('リ')));
      await tester.pump();

      final state = container.read(hoverPopupProvider);
      expect(state.isVisible, isTrue);
      expect(state.word, 'アリス');
    });

    testWidgets('a touch tap on unmarked text shows nothing', (tester) async {
      final container = await pumpRenderer(
        tester,
        mode: TextDisplayMode.vertical,
      );

      await tester.tapAt(tester.getCenter(find.text('昨')));
      await tester.pump();

      expect(container.read(hoverPopupProvider).isVisible, isFalse);
    });
  });
}
