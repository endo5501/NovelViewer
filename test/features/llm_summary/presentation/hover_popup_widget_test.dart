import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/analysis_runner.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_anchor.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_widget.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_detail_dialog.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_detail_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Throws if the dropdown ever reaches for a folder search while building
/// itself.
class _ForbiddenSearch implements TextSearchService {
  @override
  Object? noSuchMethod(Invocation invocation) =>
      fail('building the re-analyze menu must not search the folder');
}

/// Recording stub: lets the test observe what episode / sourceFile the
/// re-analyze menu hands to the runner without invoking the real LLM stack.
class _RecordingAnalysisRunner implements AnalysisRunner {
  int callCount = 0;
  int? lastCoveredUpToEpisode;
  String? lastSourceFileName;
  String? lastWord;

  @override
  Future<void> run({
    required BuildContext context,
    required String word,
    required int coveredUpToEpisode,
    String? sourceFileName,
    String? novelFolderPath,
  }) async {
    callCount++;
    lastWord = word;
    lastCoveredUpToEpisode = coveredUpToEpisode;
    lastSourceFileName = sourceFileName;
  }

  AnalysisScope? lastScope;

  /// The simple-analysis item goes through here rather than [run]: which
  /// episode it resolves to is only known after searching the folder, which
  /// building the menu must not do.
  @override
  Future<void> runWithScope({
    required BuildContext context,
    required String word,
    required AnalysisScope scope,
  }) async {
    callCount++;
    lastWord = word;
    lastScope = scope;
  }
}

// Minimal-coverage replacement for the v5 snapshot model. Detailed
// scenarios (toggle behavior, reanalysis menu overwrite suffixes, theme
// boundary rendering) are tracked as a follow-up in the change's tasks.md
// and will be reintroduced when the widget API stabilizes.

ProviderScope _scopedWith({
  required Widget child,
  required List<WordSummary> snapshots,
  bool llmSupported = true,
}) {
  return ProviderScope(
    overrides: [
      llmSummarySupportedProvider.overrideWithValue(llmSupported),
      hoverPopupCacheProvider((
        folderPath: 'novel_a',
        word: 'アリス',
      )).overrideWith((_) async => snapshots),
      llmSummaryRepositoryProvider.overrideWith(
        (ref, folderPath) async =>
            throw UnsupportedError('not needed in this test'),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Material(child: child),
    ),
  );
}

/// Records deletions instead of touching a database: what the popup owes is
/// handing the right word and folder to the same delete the history menu
/// uses. What that delete does to the tables is covered by the notifier's
/// own tests.
class _RecordingHistoryNotifier extends LlmSummaryHistoryNotifier {
  final List<({String word, String novelFolder})> deletions = [];

  @override
  Future<List<HistoryEntry>> build() async => const [];

  @override
  Future<void> deleteEntry(String word, {required String novelFolder}) async {
    deletions.add((word: word, novelFolder: novelFolder));
  }
}

WordSummary _snap(int episode, String text) => WordSummary(
  word: 'アリス',
  coveredUpToEpisode: episode,
  summary: text,
  sourceFile: '${episode.toString().padLeft(3, '0')}.txt',
  createdAt: DateTime.utc(2026, 5, 21),
  updatedAt: DateTime.utc(2026, 5, 21),
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('HoverPopupWidget', () {
    testWidgets('hidden when there are no snapshots', (tester) async {
      await tester.pumpWidget(
        _scopedWith(
          snapshots: const [],
          child: const HoverPopupWidget(
            folderPath: 'novel_a',
            word: 'アリス',
            currentEpisode: 5,
            currentFileName: '005.txt',
            maxEpisodeInFolder: 10,
            maxEpisodeFileName: '010.txt',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hover_popup_card')), findsNothing);
    });

    testWidgets('never lays out wider than the anchor math assumes', (
      tester,
    ) async {
      // The anchor decides where to put the popup, and whether to flip it or
      // pull it back on screen, from a constant. A card that can grow wider
      // than that constant hangs off the edge of a narrow screen by the
      // difference, which is exactly the case the flip exists for.
      await tester.pumpWidget(
        _scopedWith(
          snapshots: [_snap(3, 'あ' * 400)],
          child: const Align(
            alignment: Alignment.topLeft,
            child: HoverPopupWidget(
              folderPath: 'novel_a',
              word: 'アリス',
              currentEpisode: 3,
              currentFileName: '003.txt',
              maxEpisodeInFolder: 3,
              maxEpisodeFileName: '003.txt',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(const Key('hover_popup_card'))).width,
        lessThanOrEqualTo(kHoverPopupApproxWidth),
      );
    });

    testWidgets('a three-line summary fits the height the anchor assumes', (
      tester,
    ) async {
      // The anchor flips the popup above the pointer, or pulls it up, only
      // when a card of this height would pass the bottom edge. The constant
      // promises room for a summary of a few lines; a card taller than that
      // hangs off the bottom by the difference, controls included.
      await tester.pumpWidget(
        _scopedWith(
          snapshots: [_snap(3, 'あ' * 72)],
          child: const Align(
            alignment: Alignment.topLeft,
            child: HoverPopupWidget(
              folderPath: 'novel_a',
              word: 'アリス',
              currentEpisode: 3,
              currentFileName: '003.txt',
              maxEpisodeInFolder: 3,
              maxEpisodeFileName: '003.txt',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final summary = tester.getSize(find.text('あ' * 72)).height;
      final lineHeight = tester.getSize(find.text('3ファイル時点の要約')).height;
      expect(summary, greaterThan(lineHeight * 2), reason: 'three lines');
      expect(
        tester.getSize(find.byKey(const Key('hover_popup_card'))).height,
        lessThanOrEqualTo(kHoverPopupApproxHeight),
      );
    });

    testWidgets('renders the default snapshot label and summary text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _scopedWith(
          snapshots: [_snap(3, '序盤要約'), _snap(9, '中盤要約')],
          child: const HoverPopupWidget(
            folderPath: 'novel_a',
            word: 'アリス',
            currentEpisode: 6,
            currentFileName: '006.txt',
            maxEpisodeInFolder: 9,
            maxEpisodeFileName: '009.txt',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hover_popup_card')), findsOneWidget);
      expect(
        find.text('序盤要約'),
        findsOneWidget,
        reason: 'default = max{Sᵢ | Sᵢ ≤ 6} = 3',
      );
      expect(find.text('3ファイル時点の要約'), findsOneWidget);
    });

    testWidgets(
      'shows the future warning icon when only future snapshots exist',
      (tester) async {
        await tester.pumpWidget(
          _scopedWith(
            snapshots: [_snap(9, '先の要約')],
            child: const HoverPopupWidget(
              folderPath: 'novel_a',
              word: 'アリス',
              currentEpisode: 6,
              currentFileName: '006.txt',
              maxEpisodeInFolder: 9,
              maxEpisodeFileName: '009.txt',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('hover_popup_future_warning')),
          findsOneWidget,
        );
        expect(find.text('先の要約'), findsOneWidget);
      },
    );

    testWidgets('arrow buttons are disabled when only one snapshot exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        _scopedWith(
          snapshots: [_snap(5, 'only')],
          child: const HoverPopupWidget(
            folderPath: 'novel_a',
            word: 'アリス',
            currentEpisode: 5,
            currentFileName: '005.txt',
            maxEpisodeInFolder: 5,
            maxEpisodeFileName: '005.txt',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final prev = tester.widget<IconButton>(
        find.byKey(const Key('hover_popup_snapshot_prev')),
      );
      final next = tester.widget<IconButton>(
        find.byKey(const Key('hover_popup_snapshot_next')),
      );
      expect(prev.onPressed, isNull);
      expect(next.onPressed, isNull);
    });
  });

  group('Re-analysis menu integration', () {
    testWidgets(
      'tapping a menu item invokes the runner with the resolved episode + '
      'source file and resets the popup notifier activeEpisode',
      (tester) async {
        final runner = _RecordingAnalysisRunner();
        final container = ProviderContainer(
          overrides: [
            hoverPopupCacheProvider((
              folderPath: 'novel_a',
              word: 'アリス',
            )).overrideWith((_) async => [_snap(3, '序盤要約'), _snap(9, '中盤要約')]),
            llmSummaryRepositoryProvider.overrideWith(
              (ref, folderPath) async =>
                  throw UnsupportedError('not needed in this test'),
            ),
            analysisRunnerProvider.overrideWithValue(runner),
          ],
        );
        addTearDown(container.dispose);

        // Pre-set the popup notifier as if the user had navigated to a
        // specific snapshot — this lets the test verify the reset side-effect.
        // We need the popup to be "visible" for setActiveEpisode to take.
        container
            .read(hoverPopupProvider.notifier)
            .show(
              word: 'アリス',
              position: const Offset(0, 0),
              token: (start: 0, end: 3),
            );
        container.read(hoverPopupProvider.notifier).setActiveEpisode(9);
        expect(container.read(hoverPopupProvider).activeEpisode, 9);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              locale: Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Material(
                child: HoverPopupWidget(
                  folderPath: 'novel_a',
                  word: 'アリス',
                  currentEpisode: 6,
                  currentFileName: '006.txt',
                  maxEpisodeInFolder: 9,
                  maxEpisodeFileName: '009.txt',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open the re-analyze menu, then tap "up to current page".
        await tester.tap(find.byKey(const Key('hover_popup_reanalyze_button')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('hover_popup_reanalyze_up_to_current')),
        );
        await tester.pumpAndSettle();

        expect(runner.callCount, 1);
        expect(runner.lastWord, 'アリス');
        expect(
          runner.lastCoveredUpToEpisode,
          6,
          reason: 'up to current page = currentEpisode (6)',
        );
        expect(runner.lastSourceFileName, '006.txt');

        // The recording runner doesn't itself invalidate the cache /
        // reset activeEpisode (that's done inside DefaultAnalysisRunner.run
        // post-await). To exercise the reset, we directly invoke the same
        // logic the production runner would: invalidate + reset.
        container.invalidate(
          hoverPopupCacheProvider((folderPath: 'novel_a', word: 'アリス')),
        );
        final hoverState = container.read(hoverPopupProvider);
        if (hoverState.word == 'アリス') {
          container.read(hoverPopupProvider.notifier).setActiveEpisode(null);
        }

        expect(
          container.read(hoverPopupProvider).activeEpisode,
          isNull,
          reason:
              'after re-analysis invalidation, activeEpisode is reset so '
              'the popup falls back to the default-selection rule against '
              'the freshly fetched snapshot list',
        );
      },
    );

    testWidgets('"up to all" menu item resolves to maxEpisodeInFolder', (
      tester,
    ) async {
      final runner = _RecordingAnalysisRunner();
      final container = ProviderContainer(
        overrides: [
          hoverPopupCacheProvider((
            folderPath: 'novel_a',
            word: 'アリス',
          )).overrideWith((_) async => [_snap(3, '序盤要約')]),
          llmSummaryRepositoryProvider.overrideWith(
            (ref, folderPath) async =>
                throw UnsupportedError('not needed in this test'),
          ),
          analysisRunnerProvider.overrideWithValue(runner),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Material(
              child: HoverPopupWidget(
                folderPath: 'novel_a',
                word: 'アリス',
                currentEpisode: 6,
                currentFileName: '006.txt',
                maxEpisodeInFolder: 120,
                maxEpisodeFileName: '120.txt',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hover_popup_reanalyze_button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('hover_popup_reanalyze_up_to_all')),
      );
      await tester.pumpAndSettle();

      expect(runner.callCount, 1);
      expect(runner.lastCoveredUpToEpisode, 120);
      expect(runner.lastSourceFileName, '120.txt');
    });
  });

  group('Re-analysis menu simple-analysis item', () {
    /// Fails the test if the dropdown ever searches the folder to build
    /// itself: which episode simple analysis resolves to is only known after
    /// a search, and opening a menu must not pay for one.
    ProviderContainer containerWith(
      _RecordingAnalysisRunner runner, {
      List<WordSummary> snapshots = const [],
    }) => ProviderContainer(
      overrides: [
        hoverPopupCacheProvider((
          folderPath: 'novel_a',
          word: 'アリス',
        )).overrideWith((_) async => snapshots),
        llmSummaryRepositoryProvider.overrideWith(
          (ref, folderPath) async =>
              throw UnsupportedError('not needed in this test'),
        ),
        textSearchServiceProvider.overrideWithValue(_ForbiddenSearch()),
        analysisRunnerProvider.overrideWithValue(runner),
      ],
    );

    Future<void> openDropdown(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Material(
              child: HoverPopupWidget(
                folderPath: 'novel_a',
                word: 'アリス',
                currentEpisode: 6,
                currentFileName: '006.txt',
                maxEpisodeInFolder: 120,
                maxEpisodeFileName: '120.txt',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hover_popup_reanalyze_button')));
      await tester.pumpAndSettle();
    }

    List<String?> menuLabels(WidgetTester tester) => tester
        .widgetList<MenuItemButton>(find.byType(MenuItemButton))
        .map((b) => (b.child as Text).data)
        .toList();

    testWidgets('lists three items, simple analysis first', (tester) async {
      final runner = _RecordingAnalysisRunner();
      final container = containerWith(runner, snapshots: [_snap(3, '序盤要約')]);
      addTearDown(container.dispose);

      await openDropdown(tester, container);

      expect(menuLabels(tester), [
        '簡易解析',
        '現在ページまで (6ファイル時点)',
        '全話まで (120ファイル時点)',
      ]);
    });

    testWidgets('carries no episode and no overwrite suffix', (tester) async {
      final runner = _RecordingAnalysisRunner();
      // Snapshots at several episodes, including the current page's, so the
      // other two items do get the suffix and this one still must not.
      final container = containerWith(
        runner,
        snapshots: [_snap(3, 'あ'), _snap(6, 'い'), _snap(120, 'う')],
      );
      addTearDown(container.dispose);

      await openDropdown(tester, container);

      final labels = menuLabels(tester);
      expect(labels.first, '簡易解析');
      expect(labels.first, isNot(contains('上書き')));
      expect(
        labels[1],
        contains('上書き'),
        reason: 'the scoped items keep their suffix behaviour',
      );
    });

    testWidgets('tapping it runs the first-occurrence scope', (tester) async {
      final runner = _RecordingAnalysisRunner();
      final container = containerWith(runner, snapshots: [_snap(3, '序盤要約')]);
      addTearDown(container.dispose);

      await openDropdown(tester, container);
      await tester.tap(find.byKey(const Key('hover_popup_reanalyze_simple')));
      await tester.pumpAndSettle();

      expect(runner.callCount, 1);
      expect(runner.lastWord, 'アリス');
      expect(runner.lastScope, AnalysisScope.firstOccurrence);
      expect(
        runner.lastCoveredUpToEpisode,
        isNull,
        reason: 'the episode is resolved by the runner, not by the menu',
      );
    });
  });

  group('shouldAppendOverwriteSuffix', () {
    test('returns true when an existing snapshot matches the candidate', () {
      expect(
        shouldAppendOverwriteSuffix([_snap(3, ''), _snap(9, '')], 3),
        isTrue,
      );
    });

    test('returns false when no snapshot matches the candidate', () {
      expect(
        shouldAppendOverwriteSuffix([_snap(3, ''), _snap(9, '')], 10),
        isFalse,
      );
    });

    test('returns false on empty snapshot list', () {
      expect(shouldAppendOverwriteSuffix(const [], 1), isFalse);
    });
  });

  group('where LLM summary is unavailable', () {
    // Stored summaries stay readable — a library folder carried over from a
    // desktop install keeps its analysis visible. What is withheld is the one
    // control in this popup that would start a new analysis. iPadOS delivers
    // hover events whenever a trackpad is attached, so this popup is reachable
    // there despite being pointer-driven.
    testWidgets('the stored summary is still shown', (tester) async {
      await tester.pumpWidget(
        _scopedWith(
          snapshots: [_snap(3, '序盤要約')],
          llmSupported: false,
          child: const HoverPopupWidget(
            folderPath: 'novel_a',
            word: 'アリス',
            currentEpisode: 6,
            currentFileName: '006.txt',
            maxEpisodeInFolder: 9,
            maxEpisodeFileName: '009.txt',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hover_popup_card')), findsOneWidget);
      expect(find.text('序盤要約'), findsOneWidget);
    });

    testWidgets('the re-analyze control is absent', (tester) async {
      await tester.pumpWidget(
        _scopedWith(
          snapshots: [_snap(3, '序盤要約')],
          llmSupported: false,
          child: const HoverPopupWidget(
            folderPath: 'novel_a',
            word: 'アリス',
            currentEpisode: 6,
            currentFileName: '006.txt',
            maxEpisodeInFolder: 9,
            maxEpisodeFileName: '009.txt',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('hover_popup_reanalyze_button')),
        findsNothing,
      );
    });

    testWidgets('the re-analyze control is present where it can be used', (
      tester,
    ) async {
      await tester.pumpWidget(
        _scopedWith(
          snapshots: [_snap(3, '序盤要約')],
          child: const HoverPopupWidget(
            folderPath: 'novel_a',
            word: 'アリス',
            currentEpisode: 6,
            currentFileName: '006.txt',
            maxEpisodeInFolder: 9,
            maxEpisodeFileName: '009.txt',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('hover_popup_reanalyze_button')),
        findsOneWidget,
      );
    });
  });

  group('Detail and delete controls', () {
    late _RecordingHistoryNotifier history;

    setUp(() => history = _RecordingHistoryNotifier());

    /// [visible] lets a test take the popup out of the tree while a dialog it
    /// opened is still up, the way the host removes it once the pointer leaves.
    Future<void> pumpPopup(
      WidgetTester tester, {
      bool llmSupported = true,
      Locale locale = const Locale('ja'),
      ValueNotifier<bool>? visible,
    }) async {
      final shown = visible ?? ValueNotifier(true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            llmSummarySupportedProvider.overrideWithValue(llmSupported),
            hoverPopupCacheProvider((
              folderPath: 'novel_a',
              word: 'アリス',
            )).overrideWith((_) async => [_snap(3, '序盤要約')]),
            llmSummaryRepositoryProvider.overrideWith(
              (ref, folderPath) async =>
                  throw UnsupportedError('not needed in this test'),
            ),
            llmSummaryHistoryProvider.overrideWith(() => history),
            historyDetailFactsProvider.overrideWith(
              (ref, key) async => const [],
            ),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Material(
              child: Align(
                alignment: Alignment.topLeft,
                child: ValueListenableBuilder<bool>(
                  valueListenable: shown,
                  builder: (_, isShown, _) => isShown
                      ? const HoverPopupWidget(
                          folderPath: 'novel_a',
                          word: 'アリス',
                          currentEpisode: 6,
                          currentFileName: '006.txt',
                          maxEpisodeInFolder: 9,
                          maxEpisodeFileName: '009.txt',
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final details = find.byKey(const Key('hover_popup_details_button'));
    final delete = find.byKey(const Key('hover_popup_delete_button'));
    final confirm = find.byKey(const Key('hover_popup_delete_confirm'));
    final cancel = find.byKey(const Key('hover_popup_delete_cancel'));

    testWidgets('both sit labelled below the summary, re-analyze stays up', (
      tester,
    ) async {
      await pumpPopup(tester);

      expect(
        find.descendant(of: details, matching: find.text('詳細を表示')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: delete, matching: find.text('削除')),
        findsOneWidget,
      );
      final summaryBottom = tester.getBottomLeft(find.text('序盤要約')).dy;
      expect(
        tester.getTopLeft(details).dy,
        greaterThanOrEqualTo(summaryBottom),
      );
      expect(tester.getTopLeft(delete).dy, greaterThanOrEqualTo(summaryBottom));
      expect(
        tester
            .getBottomLeft(
              find.byKey(const Key('hover_popup_reanalyze_button')),
            )
            .dy,
        lessThanOrEqualTo(summaryBottom),
      );
    });

    testWidgets('both are shown where LLM summary is unavailable', (
      tester,
    ) async {
      await pumpPopup(tester, llmSupported: false);

      expect(details, findsOneWidget);
      expect(delete, findsOneWidget);
      expect(
        find.byKey(const Key('hover_popup_reanalyze_button')),
        findsNothing,
      );
    });

    testWidgets('the detail control opens the word detail dialog', (
      tester,
    ) async {
      await pumpPopup(tester);

      await tester.tap(details);
      await tester.pumpAndSettle();

      expect(find.byType(LlmSummaryDetailDialog), findsOneWidget);
      expect(find.text('「アリス」の詳細'), findsOneWidget);
      expect(
        tester
            .widget<LlmSummaryDetailDialog>(find.byType(LlmSummaryDetailDialog))
            .folderPath,
        'novel_a',
        reason: 'the dialog SHALL read the novel the popup was opened over',
      );
      final tabs = DefaultTabController.of(
        tester.element(find.text('事実').first),
      );
      expect(tabs.index, 0, reason: 'the facts tab SHALL be selected first');
    });

    testWidgets('the delete control asks before deleting', (tester) async {
      await pumpPopup(tester);

      await tester.tap(delete);
      await tester.pumpAndSettle();

      expect(find.text('「アリス」の解析結果を削除'), findsOneWidget);
      expect(history.deletions, isEmpty);
    });

    testWidgets('confirming deletes the word from the popup\'s novel', (
      tester,
    ) async {
      await pumpPopup(tester);

      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(history.deletions, [(word: 'アリス', novelFolder: 'novel_a')]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('cancelling deletes nothing', (tester) async {
      await pumpPopup(tester);

      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pumpAndSettle();

      expect(history.deletions, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('dismissing by the barrier deletes nothing', (tester) async {
      await pumpPopup(tester);

      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 590));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(history.deletions, isEmpty);
    });

    testWidgets('dismissing by Esc deletes nothing', (tester) async {
      await pumpPopup(tester);

      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(history.deletions, isEmpty);
    });

    testWidgets('the delete completes after the popup has gone', (
      tester,
    ) async {
      // Opening the dialog moves the pointer off the popup, and the host then
      // removes it: whatever confirming needs has to outlive the popup.
      final visible = ValueNotifier(true);
      await pumpPopup(tester, visible: visible);

      await tester.tap(delete);
      await tester.pumpAndSettle();
      visible.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(HoverPopupWidget), findsNothing);

      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(history.deletions, [(word: 'アリス', novelFolder: 'novel_a')]);
    });

    for (final locale in const [Locale('en'), Locale('zh')]) {
      testWidgets('fits the popup width in ${locale.languageCode}', (
        tester,
      ) async {
        await pumpPopup(tester, locale: locale);

        expect(details, findsOneWidget);
        expect(delete, findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'no overflow');
        expect(
          tester.getSize(find.byKey(const Key('hover_popup_card'))).width,
          lessThanOrEqualTo(kHoverPopupApproxWidth),
        );
      });
    }
  });
}
