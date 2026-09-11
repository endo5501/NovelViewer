import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/marked_words_provider.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tap on a marked word has to reach the popup state, in both display
/// modes. The two viewers resolve the tapped character by completely
/// different routes, so each needs the whole path exercised: nothing below
/// the renderer knows that a popup exists.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const content = '昨日アリスが来た。';
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> pumpRenderer(
    WidgetTester tester, {
    TextDisplayMode mode = TextDisplayMode.horizontal,
    Map<String, MarkStyle> marks = const {'アリス': MarkStyle.solid},
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
          markedWordsProvider.overrideWithValue(marks),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: TextContentRenderer(content: content),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

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

  Future<void> tapCharacter(WidgetTester tester, int index) async {
    await tester.tapAt(characterCentre(tester, index));
    await tester.pump();
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
      // On iOS a repeat tap at the same spot leaves the selection unchanged,
      // so no selection change is reported. Resolving the tap from the last
      // known selection rather than from the change notification is what
      // keeps the second tap working.
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
