import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_widget.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_detail_dialog.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_detail_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

const _part1 = SnapshotReferenceSource(folderName: 'narou_p1', title: '第1部');
const _wiki = SnapshotReferenceSource(
  folderName: 'web_wiki',
  title: 'Wiki 記事集',
);

WordSummary _snap(
  int episode, {
  List<SnapshotReferenceSource> sources = const [],
}) => WordSummary(
  word: 'アリス',
  coveredUpToEpisode: episode,
  summary: '要約$episode',
  sourceFile: '${episode.toString().padLeft(3, '0')}.txt',
  referenceSources: sources,
  createdAt: DateTime.utc(2026, 5, 21),
  updatedAt: DateTime.utc(2026, 5, 21),
);

Widget _popup(
  List<WordSummary> snapshots, {
  Locale locale = const Locale('ja'),
}) => ProviderScope(
  overrides: [
    llmSummarySupportedProvider.overrideWithValue(true),
    hoverPopupCacheProvider((
      folderPath: 'novel_a',
      word: 'アリス',
    )).overrideWith((_) async => snapshots),
    llmSummaryRepositoryProvider.overrideWith(
      (ref, folderPath) async => throw UnsupportedError('unused'),
    ),
  ],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Material(
      child: Align(
        alignment: Alignment.topLeft,
        child: HoverPopupWidget(
          folderPath: 'novel_a',
          word: 'アリス',
          currentEpisode: 3,
          currentFileName: '003.txt',
          maxEpisodeInFolder: 10,
          maxEpisodeFileName: '010.txt',
        ),
      ),
    ),
  ),
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ja'));
  });

  testWidgets('the popup lists the snapshot\'s reference sources', (
    tester,
  ) async {
    await tester.pumpWidget(
      _popup([
        _snap(3, sources: const [_part1, _wiki]),
      ]),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.summaryCard_referenceSources('『第1部』、『Wiki 記事集』')),
      findsOneWidget,
    );
  });

  testWidgets('the list uses the locale\'s quotes and separator', (
    tester,
  ) async {
    await tester.pumpWidget(
      _popup([
        _snap(3, sources: const [_part1, _wiki]),
      ], locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    final line = tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const Key('hover_popup_reference_sources')),
            matching: find.byType(Text),
          ),
        )
        .data!;
    expect(line, isNot(contains('『')));
    expect(line, isNot(contains('、')));
    expect(line, contains('第1部'));
    expect(line, contains('Wiki 記事集'));
  });

  testWidgets('a snapshot without reference sources shows none', (
    tester,
  ) async {
    await tester.pumpWidget(_popup([_snap(3)]));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('hover_popup_reference_sources')),
      findsNothing,
    );
  });

  Widget dialog(List<WordSummary> snapshots) => ProviderScope(
    overrides: [
      historyDetailFactsProvider((
        folderPath: 'novel_a',
        word: 'アリス',
      )).overrideWith((_) async => const []),
      hoverPopupCacheProvider((
        folderPath: 'novel_a',
        word: 'アリス',
      )).overrideWith((_) async => snapshots),
    ],
    child: const MaterialApp(
      locale: Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: LlmSummaryDetailDialog(folderPath: 'novel_a', word: 'アリス'),
      ),
    ),
  );

  testWidgets('the detail dialog shows the same list', (tester) async {
    await tester.pumpWidget(
      dialog([
        _snap(3, sources: const [_part1]),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('解析結果'));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.summaryCard_referenceSources('『第1部』')),
      findsOneWidget,
    );
  });

  testWidgets('stepping to another snapshot follows its list', (tester) async {
    await tester.pumpWidget(
      dialog([
        _snap(3, sources: const [_part1]),
        _snap(9),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('解析結果'));
    await tester.pumpAndSettle();
    final shown = find.byKey(const Key('history_detail_reference_sources'));
    // The dialog opens on the latest snapshot, which has no reference sources.
    expect(find.text('要約9'), findsOneWidget);
    expect(shown, findsNothing);

    await tester.tap(find.byKey(const Key('history_detail_snapshot_prev')));
    await tester.pumpAndSettle();

    expect(find.text('要約3'), findsOneWidget);
    expect(shown, findsOneWidget);
  });
}
