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
        'vertical mode does NOT spawn a hover popup even if show() is invoked',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
            // Pretend there's a cached word so VerticalTextViewer would draw
            // a sidebar line for it. Hover must still be suppressed.
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

      // Sanity: vertical viewer is rendered with the marked word in its map.
      final vertical =
          tester.widget<VerticalTextViewer>(find.byType(VerticalTextViewer));
      expect(vertical.markedWords.keys, contains('アリス'),
          reason: 'Marked words must still be passed to the vertical viewer');
      expect(find.byType(SelectableText), findsNothing,
          reason:
              'No SelectableText.rich path means no TextSpan.onEnter wiring '
              'is possible — hover is structurally impossible in vertical mode');

      // Even if some caller were to force the popup notifier visible, no
      // overlay would be inserted by TextContentRenderer (it is not a host).
      container
          .read(hoverPopupProvider.notifier)
          .show(word: 'アリス', position: const Offset(0, 0));
      await tester.pumpAndSettle();
      expect(find.byType(HoverPopupWidget), findsNothing,
          reason: 'TextContentRenderer itself never inserts the hover popup; '
              'that responsibility lives in HoverPopupHost (which suppresses '
              'in vertical mode anyway).');
    });
  });
}
