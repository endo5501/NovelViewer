/// End-to-end widget tests for the hover popup in vertical mode.
///
/// Unlike the renderer/host unit tests which exercise wiring by invoking
/// callbacks directly, these tests drive a real mouse pointer through
/// `MouseRegion`/`MouseTracker`, let `TextContentRenderer` produce the
/// `VerticalTextViewer` → `VerticalTextPage` widget chain, and let
/// `HoverPopupHost` insert the actual `OverlayEntry` containing
/// `HoverPopupWidget`. This catches races and timing issues that the
/// callback-level tests cannot see (codex review residual gap).
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_host.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_widget.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/marked_words_provider.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSelectedFile extends SelectedFileNotifier {
  _MockSelectedFile(this._initial);
  final FileEntry? _initial;
  @override
  FileEntry? build() => _initial;
}

const _aliceFolder = 'novel_a';
const _aliceWord = 'アリス';
const _aliceKey = (folder: _aliceFolder, word: _aliceWord);
const _summaryText = 'アリスは旅人です。';

WordSummariesByType _aliceSummary() {
  final now = DateTime.parse('2026-05-24T10:00:00Z');
  return WordSummariesByType(
    noSpoiler: WordSummary(
      folderName: _aliceFolder,
      word: _aliceWord,
      summaryType: SummaryType.noSpoiler,
      summary: _summaryText,
      sourceFile: 'chapter01.txt',
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<void> _pumpE2E(
  WidgetTester tester, {
  required SharedPreferences prefs,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
        markedWordsProvider
            .overrideWithValue({_aliceWord: MarkStyle.solid}),
        currentDirectoryProvider
            .overrideWith(() => CurrentDirectoryNotifier('/library/$_aliceFolder')),
        selectedFileProvider.overrideWith(() => _MockSelectedFile(
              const FileEntry(
                name: 'chapter01.txt',
                path: '/library/novel_a/chapter01.txt',
              ),
            )),
        hoverPopupCacheProvider(_aliceKey).overrideWith(
          (_) async => _aliceSummary(),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: HoverPopupHost(
              child: TextContentRenderer(content: 'アリスは旅に出た。'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Switch into vertical mode.
  final container =
      ProviderScope.containerOf(tester.element(find.byType(TextContentRenderer)));
  await container
      .read(displayModeProvider.notifier)
      .setMode(TextDisplayMode.vertical);
  await tester.pumpAndSettle();
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('hover popup E2E — real mouse through the full widget chain', () {
    testWidgets(
      'real mouse hover over a marked vertical character inserts the popup '
      'overlay (full path: MouseRegion → onMarkEnter → HoverPopupHost → '
      'Overlay → HoverPopupWidget)',
      (tester) async {
        await _pumpE2E(tester, prefs: prefs);
        expect(find.byType(HoverPopupWidget), findsNothing);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);

        // Hover the marked word 'アリス' — pick 'リ' (middle of mark).
        final markedCenter = tester.getCenter(find.text('リ'));
        await mouse.moveTo(markedCenter);
        await tester.pumpAndSettle();

        expect(find.byType(HoverPopupWidget), findsOneWidget,
            reason: 'Real mouse hover over a marked char must insert the '
                'popup overlay end-to-end');
        expect(find.text(_summaryText), findsOneWidget,
            reason: 'Popup body must render the cached summary text');
      },
    );

    testWidgets(
      'mouse leaving the marked char without entering the popup hides the '
      'overlay after the 150 ms grace period (explicit pump duration — does '
      'NOT use pumpAndSettle so the timer is observed precisely)',
      (tester) async {
        await _pumpE2E(tester, prefs: prefs);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);

        await mouse.moveTo(tester.getCenter(find.text('リ')));
        await tester.pumpAndSettle();
        expect(find.byType(HoverPopupWidget), findsOneWidget);

        // Move pointer FAR away — outside the renderer entirely so the
        // VerticalTextPage MouseRegion's onExit fires too.
        await mouse.moveTo(const Offset(2000, 2000));

        // Before the grace period elapses the popup is still visible.
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(HoverPopupWidget), findsOneWidget,
            reason: 'Inside the 150 ms grace window the popup must remain '
                'visible so the pointer can travel into it');

        // After the grace period the popup disappears.
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(HoverPopupWidget), findsNothing,
            reason: 'Once the grace period elapses without a popup-enter, '
                'the popup must be torn down');
      },
    );

    testWidgets(
      'moving the real mouse from a mark to non-marked text removes the '
      'popup after the grace period without leaving overlay leaks',
      (tester) async {
        await _pumpE2E(tester, prefs: prefs);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);

        await mouse.moveTo(tester.getCenter(find.text('リ')));
        await tester.pumpAndSettle();
        expect(find.byType(HoverPopupWidget), findsOneWidget);

        // Move to a non-marked glyph inside the same vertical page so we
        // exercise the onMarkExit path (not the MouseRegion.onExit path).
        await mouse.moveTo(tester.getCenter(find.text('旅')));
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(HoverPopupWidget), findsNothing);
      },
    );
  });
}
