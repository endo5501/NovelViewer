import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_widget.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/marked_words_provider.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  group('computeLineStartOffsets', () {
    test('empty content returns single zero offset', () {
      expect(computeLineStartOffsets(''), [0]);
    });

    test('content without newline returns single zero offset', () {
      expect(computeLineStartOffsets('abc'), [0]);
    });

    test('content with one newline returns two offsets', () {
      // 'abc\ndef' — '\n' is at index 3, next line starts at 4
      expect(computeLineStartOffsets('abc\ndef'), [0, 4]);
    });

    test('trailing newline yields an additional line start past the end', () {
      // 'abc\n' — '\n' at index 3, next line start = 4 (== length)
      expect(computeLineStartOffsets('abc\n'), [0, 4]);
    });

    test('consecutive newlines produce consecutive line starts', () {
      // 'a\n\nb' — newlines at 1 and 2
      expect(computeLineStartOffsets('a\n\nb'), [0, 2, 3]);
    });

    test('multiline content has correct offsets for every line', () {
      const content = 'line1\nline2\nline3';
      // line2 starts at 6, line3 starts at 12
      expect(computeLineStartOffsets(content), [0, 6, 12]);
    });
  });

  group('measureCharOffsetY', () {
    const fontSize = 14.0;
    const baseStyle = TextStyle(fontSize: fontSize, height: 1.5);
    const lineHeight = fontSize * 1.5;

    testWidgets('plain second line Y matches single line height',
        (tester) async {
      const content = 'line1\nline2\nline3';
      final lineStarts = computeLineStartOffsets(content);

      final y = measureCharOffsetY(
        textSpan: const TextSpan(text: content, style: baseStyle),
        globalCharOffset: lineStarts[1],
        maxWidth: 1000,
        fontSize: fontSize,
      );

      // Tight tolerance — should match the single line height within 2px.
      // A looser bound (e.g. half a line) would mask off-by-one regressions
      // that flip lineNumber-1 vs lineNumber.
      expect(y, closeTo(lineHeight, 2.0));
    });

    testWidgets(
        'ruby segment on line 1 pushes line 2 Y down compared to plain text',
        (tester) async {
      const content = 'ruby_line\nplain';
      const lineStarts = [0, 'ruby_line\n'.length];

      const plainSpan = TextSpan(text: content, style: baseStyle);
      final rubyBaseStyle = baseStyle.copyWith(height: 1.0);
      final rubySpan = TextSpan(style: baseStyle, children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: RubyTextWidget(
            base: 'ruby',
            rubyText: 'るび',
            baseStyle: rubyBaseStyle,
          ),
        ),
        const TextSpan(text: '_line\nplain', style: baseStyle),
      ]);

      final plainY = measureCharOffsetY(
        textSpan: plainSpan,
        globalCharOffset: lineStarts[1],
        maxWidth: 1000,
        fontSize: fontSize,
      );
      final rubyY = measureCharOffsetY(
        textSpan: rubySpan,
        globalCharOffset: lineStarts[1],
        maxWidth: 1000,
        fontSize: fontSize,
      );

      // Ruby segment makes line 1 taller (ruby gloss above base), so line 2
      // starts further down than in the plain-text variant.
      expect(rubyY, greaterThan(plainY + 1.0),
          reason:
              'ruby annotation on line 1 should push line 2 strictly below the '
              'plain-text line 2 Y (rubyY=$rubyY, plainY=$plainY)');
    });

    testWidgets('wrapping long line pushes next line down further',
        (tester) async {
      final longLine = 'x' * 200;
      final content = '$longLine\nshort';
      final lineStarts = computeLineStartOffsets(content);

      final yNoWrap = measureCharOffsetY(
        textSpan: TextSpan(text: content, style: baseStyle),
        globalCharOffset: lineStarts[1],
        maxWidth: 100000,
        fontSize: fontSize,
      );
      final yNarrow = measureCharOffsetY(
        textSpan: TextSpan(text: content, style: baseStyle),
        globalCharOffset: lineStarts[1],
        maxWidth: 100,
        fontSize: fontSize,
      );

      expect(yNoWrap, closeTo(lineHeight, 2.0));
      expect(yNarrow, greaterThan(yNoWrap + lineHeight),
          reason:
              'narrow maxWidth should wrap line 1 into multiple rows, pushing '
              'line 2 well below the no-wrap baseline');
    });

    testWidgets('larger font size scales Y of subsequent lines',
        (tester) async {
      const content = 'line1\nline2';
      final lineStarts = computeLineStartOffsets(content);

      final ySmall = measureCharOffsetY(
        textSpan: const TextSpan(
          text: content,
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        globalCharOffset: lineStarts[1],
        maxWidth: 1000,
        fontSize: 14,
      );
      final yLarge = measureCharOffsetY(
        textSpan: const TextSpan(
          text: content,
          style: TextStyle(fontSize: 28, height: 1.5),
        ),
        globalCharOffset: lineStarts[1],
        maxWidth: 1000,
        fontSize: 28,
      );

      expect(yLarge, greaterThan(ySmall * 1.5),
          reason: 'doubling the font size should at least 1.5x line 2 Y');
    });
  });

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpRenderer(
    WidgetTester tester, {
    required String content,
    TextDisplayMode mode = TextDisplayMode.horizontal,
    double? height,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: height ?? 400,
              child: TextContentRenderer(content: content),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (mode == TextDisplayMode.vertical) {
      final element = tester.element(find.byType(TextContentRenderer));
      final container = ProviderScope.containerOf(element);
      await container
          .read(displayModeProvider.notifier)
          .setMode(TextDisplayMode.vertical);
      await tester.pumpAndSettle();
    }
  }

  group('TextContentRenderer', () {
    testWidgets('horizontal mode renders SelectableText.rich',
        (tester) async {
      await pumpRenderer(tester, content: 'テスト小説の内容です。');
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.byType(VerticalTextViewer), findsNothing);
    });

    testWidgets('vertical mode renders VerticalTextViewer', (tester) async {
      await pumpRenderer(
        tester,
        content: 'テスト小説の内容です。',
        mode: TextDisplayMode.vertical,
      );
      expect(find.byType(VerticalTextViewer), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('horizontal mode wraps text in SingleChildScrollView',
        (tester) async {
      await pumpRenderer(tester, content: 'テスト');
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets(
        'TextContentRenderer never hosts the HoverPopupWidget itself — the '
        'overlay insertion is HoverPopupHost\'s responsibility',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            // Pretend there's a cached word so the renderer treats the
            // text as having marks.
            markedWordsProvider
                .overrideWithValue({'アリス': MarkStyle.solid}),
          ],
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                height: 400,
                child: TextContentRenderer(content: 'アリスは旅に出た。'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(TextContentRenderer));
      final container = ProviderScope.containerOf(element);
      await container
          .read(displayModeProvider.notifier)
          .setMode(TextDisplayMode.vertical);
      await tester.pumpAndSettle();

      // Vertical viewer still receives the marked words map.
      final vertical =
          tester.widget<VerticalTextViewer>(find.byType(VerticalTextViewer));
      expect(vertical.markedWords.keys, contains('アリス'));
      expect(find.byType(SelectableText), findsNothing);

      // Forcing the notifier visible does NOT cause TextContentRenderer to
      // render a popup — there is no Overlay in this widget subtree because
      // TextContentRenderer is not a HoverPopupHost.
      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(0, 0),
            token: const (start: 0, end: 3),
          );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TextContentRenderer),
          matching: find.byType(HoverPopupWidget),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'vertical mode wires onMarkEnter / onMarkExit / onHoverHideRequest into '
      'VerticalTextViewer, and invoking them drives hoverPopupProvider',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
              markedWordsProvider
                  .overrideWithValue({'アリス': MarkStyle.solid}),
            ],
            child: const MaterialApp(
              locale: Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  height: 400,
                  child: TextContentRenderer(content: 'アリスは旅に出た。'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(TextContentRenderer));
        final container = ProviderScope.containerOf(element);
        await container
            .read(displayModeProvider.notifier)
            .setMode(TextDisplayMode.vertical);
        await tester.pumpAndSettle();

        final vertical =
            tester.widget<VerticalTextViewer>(find.byType(VerticalTextViewer));
        expect(vertical.onMarkEnter, isNotNull,
            reason: 'vertical wiring must include onMarkEnter');
        expect(vertical.onMarkExit, isNotNull,
            reason: 'vertical wiring must include onMarkExit');
        expect(vertical.onHoverHideRequest, isNotNull,
            reason: 'vertical wiring must include onHoverHideRequest');

        // Drive the wired callbacks and verify they affect the provider.
        const token = (start: 0, end: 3);
        vertical.onMarkEnter!('アリス', const Offset(10, 10), token);
        await tester.pump();
        expect(container.read(hoverPopupProvider).isVisible, isTrue);
        expect(container.read(hoverPopupProvider).word, 'アリス');

        vertical.onHoverHideRequest!();
        await tester.pump();
        expect(container.read(hoverPopupProvider).isVisible, isFalse);

        // onMarkExit should drop the popup through the grace-period path.
        // Bring it back, then exit and confirm it is gone after the timer.
        vertical.onMarkEnter!('アリス', const Offset(10, 10), token);
        await tester.pump();
        vertical.onMarkExit!(token);
        // Wait past the 150ms grace period.
        await tester.pump(const Duration(milliseconds: 200));
        expect(container.read(hoverPopupProvider).isVisible, isFalse);
      },
    );

    testWidgets(
      'bookmark icons drop when a bookmark is removed from the list — the '
      'cache must not leak ghost icons from a prior wider set',
      (tester) async {
        const content = 'l1\nl2\nl3\nl4\nl5';
        final controlNotifier = _BookmarkListNotifier([1, 3, 5]);
        final controlProvider =
            NotifierProvider<_BookmarkListNotifier, List<int>>(
                () => controlNotifier);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              libraryPathProvider
                  .overrideWithValue('/tmp/test/NovelViewer'),
              bookmarkLineNumbersForFileProvider.overrideWith(
                (ref) async => ref.watch(controlProvider),
              ),
            ],
            child: const MaterialApp(
              locale: Locale('ja'),
              localizationsDelegates:
                  AppLocalizations.localizationsDelegates,
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
        expect(find.byIcon(Icons.bookmark), findsNWidgets(3));

        // Shrink the list in place — same widget instance, same cache.
        final element = tester.element(find.byType(TextContentRenderer));
        final container = ProviderScope.containerOf(element);
        container.read(controlProvider.notifier).set(const [1, 3]);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.bookmark), findsNWidgets(2),
            reason:
                'after shrinking bookmark list from [1,3,5] to [1,3], only '
                'two icons should remain — no ghost icon from line 5');
      },
    );

    testWidgets(
      'bookmark icon Y for a line after a wrapped long line uses measured Y, '
      'not the fixed (line-1) × lineHeight formula',
      (tester) async {
        // Line 1 is long enough to wrap into multiple visual rows at the
        // viewer width below. The bookmark on line 2 should therefore be
        // positioned strictly below `1 × singleLineHeight`.
        final longFirstLine = 'あ' * 200;
        final content = '$longFirstLine\nライン2\nライン3';

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              libraryPathProvider
                  .overrideWithValue('/tmp/test/NovelViewer'),
              bookmarkLineNumbersForFileProvider
                  .overrideWith((ref) async => const [2]),
            ],
            child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates:
                  AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  width: 200,
                  height: 400,
                  child: TextContentRenderer(content: content),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bookmarkFinder = find.byIcon(Icons.bookmark);
        expect(bookmarkFinder, findsOneWidget,
            reason: 'a single bookmark icon should render for line 2');

        // The Y of the bookmark icon, relative to the renderer's top.
        final iconTop = tester.getTopLeft(bookmarkFinder).dy;
        final rendererTop =
            tester.getTopLeft(find.byType(TextContentRenderer)).dy;
        final relY = iconTop - rendererTop;

        // The old broken formula would place the line-2 bookmark at
        // 16 (top padding) + 1 × (14 × 1.5) ≈ 37 px from the renderer top.
        // With wrapping, the actual line-2 Y must be much greater.
        const oldBrokenY = 16.0 + 14.0 * 1.5;
        expect(relY, greaterThan(oldBrokenY + 14.0),
            reason:
                'bookmark must reflect the wrapped layout of line 1, not the '
                'naive line-height formula (relY=$relY, oldBrokenY=$oldBrokenY)');
      },
    );
  });
}

class _BookmarkListNotifier extends Notifier<List<int>> {
  _BookmarkListNotifier(this._initial);

  final List<int> _initial;

  @override
  List<int> build() => _initial;

  void set(List<int> next) => state = next;
}
