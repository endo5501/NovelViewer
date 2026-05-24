import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_widget.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/marked_words_provider.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
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
  });
}
